{-# LANGUAGE ForeignFunctionInterface, EmptyDataDecls #-}
-- |
-- Module:    Codec.ZFEX
-- Copyright: Adam Langley
-- License:   GPLv2+|TGPPLv1+ (see README.rst for details)
--
-- Stability: experimental
--
-- The module provides k of n encoding - a way to generate (n - k) secondary
-- blocks of data from k primary blocks such that any k blocks (primary or
-- secondary) are sufficient to regenerate all blocks.
--
-- All blocks must be the same length and you need to keep track of which
-- blocks you have in order to tell decode. By convention, the blocks are
-- numbered 0..(n - 1) and blocks numbered < k are the primary blocks.

module Codec.ZFEX (
    FECParams
  , fec
  , encode
  , decode

  -- * Utility functions
  , secureDivide
  , secureCombine
  , enFEC
  , deFEC
  ) where

import qualified Data.ByteString as B
import qualified Data.ByteString.Unsafe as BU
import Data.Word (Word8)
import Data.Bits (xor)
import Data.List (sortBy, (\\), nub)
import Foreign.Ptr
import Foreign.Storable (sizeOf, poke, peek)
import Foreign.ForeignPtr
import Foreign.C.Types
import Foreign.Marshal.Alloc
import Foreign.Marshal.Array (withArray, advancePtr)
import System.IO (withFile, IOMode(..))
import System.IO.Unsafe (unsafePerformIO)
import System.Entropy

import Codec.ZFEXStatus

data CZFEX -- anonymous opaque fec_t
data FECParams = FECParams (ForeignPtr CZFEX) Int Int -- ForeignPtr CZFEX is used as a destructor for fec_t object

instance Show FECParams where
  show (FECParams _ k n) = "ZFEX (" ++ show k ++ ", " ++ show n ++ ")"

foreign import ccall unsafe "fec_new" _c_fec_new :: CUInt  -- ^ k
                                                 -> CUInt  -- ^ n
                                                 -> Ptr (Ptr CZFEX)
                                                 -> IO CInt
foreign import ccall unsafe "&fec_free" _c_fec_free :: FunPtr (Ptr CZFEX -> IO ())
foreign import ccall unsafe "fec_encode" _c_fec_encode :: Ptr CZFEX
                                                       -> Ptr (Ptr Word8)  -- ^ primary blocks
                                                       -> Ptr (Ptr Word8)  -- ^ (output) secondary blocks
                                                       -> Ptr CUInt  -- ^ array of secondary block ids
                                                       -> CSize  -- ^ length of previous
                                                       -> CSize  -- ^ block length
                                                       -> IO CInt
foreign import ccall unsafe "fec_decode" _c_fec_decode :: Ptr CZFEX
                                                       -> Ptr (Ptr Word8)  -- ^ input blocks
                                                       -> Ptr (Ptr Word8)  -- ^ output blocks
                                                       -> Ptr CUInt  -- ^ array of input indexes
                                                       -> CSize  -- ^ block length
                                                       -> IO CInt

_fec_new :: CUInt  -- ^ k
         -> CUInt  -- ^ n
         -> Ptr (Ptr CZFEX)
         -> IO StatusCode
_fec_new k n fec_pp = do
  rv <- _c_fec_new k n fec_pp
  return $ (toEnum $ (fromIntegral rv) :: StatusCode)

_fec_encode :: Ptr CZFEX
            -> Ptr (Ptr Word8)  -- ^ primary blocks
            -> Ptr (Ptr Word8)  -- ^ (output) secondary blocks
            -> Ptr CUInt  -- ^ array of secondary block ids
            -> CSize  -- ^ length of previous
            -> CSize  -- ^ block length
            -> IO StatusCode
_fec_encode fec_p inblocks fecblocks blocknums numblocknums sz = do
  rv <- _c_fec_encode fec_p inblocks fecblocks blocknums numblocknums sz
  return $ (toEnum $ (fromIntegral rv) :: StatusCode)

_fec_decode :: Ptr CZFEX
            -> Ptr (Ptr Word8)  -- ^ input blocks
            -> Ptr (Ptr Word8)  -- ^ output blocks
            -> Ptr CUInt  -- ^ array of input indexes
            -> CSize  -- ^ block length
            -> IO StatusCode
_fec_decode fec_p inblocks outblocks blocknums sz = do
  rv <- _c_fec_decode fec_p inblocks outblocks blocknums sz
  return $ (toEnum $ (fromIntegral rv) :: StatusCode)

-- | Return true if the given @k@ and @n@ values are valid
isValidConfig :: Int -> Int -> Bool
isValidConfig k n
  | k >= n = False
  | k < 1 = False
  | n < 1 = False
  | n > 255 = False
  | otherwise = True

-- | Return a FEC with the given parameters.
fec :: Int  -- ^ the number of primary blocks
    -> Int  -- ^ the total number blocks, must be < 256
    -> FECParams
fec k n =
  if not (isValidConfig k n)
    then error $ "Invalid FEC parameters: " ++ show k ++ " " ++ show n
    else unsafePerformIO (do
      alloca $ \fec_pp -> (do
        sc <- _fec_new (fromIntegral k) (fromIntegral n) fec_pp
        if sc == ZfexScOk
          then (do
            fec_p <- peek fec_pp
            params <- newForeignPtr _c_fec_free fec_p
            return $ FECParams params k n)
          else error $ "fec_new failed with unexpected status code " ++ show sc))

-- | Create a C array of unsigned from an input array
uintCArray :: [Int] -> ((Ptr CUInt) -> IO a) -> IO a
uintCArray xs f = withArray (map fromIntegral xs) f

-- | Convert a list of ByteStrings to an array of pointers to their data
byteStringsToArray :: [B.ByteString] -> ((Ptr (Ptr Word8)) -> IO a) -> IO a
byteStringsToArray inputs f = do
  let l = length inputs
  allocaBytes (l * sizeOf (undefined :: Ptr Word8)) (\array -> do
    let inner _ [] = f array
        inner array' (bs : bss) = BU.unsafeUseAsCString bs (\ptr -> do
          poke array' $ castPtr ptr
          inner (advancePtr array' 1) bss)
    inner array inputs)

-- | Return True iff all the given ByteStrings are the same length
allByteStringsSameLength :: [B.ByteString] -> Bool
allByteStringsSameLength [] = True
allByteStringsSameLength (bs : bss) = all ((==) (B.length bs)) $ map B.length bss

-- | Run the given function with a pointer to an array of @n@ pointers to
--   buffers of size @size@. Return these buffers as a list of ByteStrings
createByteStringArray :: Int  -- ^ the number of buffers requested
                      -> Int  -- ^ the size of each buffer
                      -> ((Ptr (Ptr Word8)) -> IO ())
                      -> IO [B.ByteString]
createByteStringArray n size f = do
  allocaBytes (n * sizeOf (undefined :: Ptr Word8)) (\array -> do
    allocaBytes (n * size) (\ptr -> do
      mapM_ (\i -> poke (advancePtr array i) (advancePtr ptr (size * i))) [0..(n - 1)]
      f array
      mapM (\i -> B.packCStringLen (castPtr $ advancePtr ptr (i * size), size)) [0..(n - 1)]))

-- | Generate the secondary blocks from a list of the primary blocks. The
--   primary blocks must be in order and all of the same size. There must be
--   @k@ primary blocks.
encode :: FECParams
       -> [B.ByteString]  -- ^ a list of @k@ input blocks
       -> [B.ByteString]  -- ^ (n - k) output blocks
encode (FECParams params k n) inblocks
  | length inblocks /= k = error "Wrong number of blocks to ZFEX encode"
  | not (allByteStringsSameLength inblocks) = error "Not all inputs to ZFEX encode are the same length"
  | otherwise = unsafePerformIO (do
      let sz = B.length $ head inblocks
      withForeignPtr params (\cfec -> do
        byteStringsToArray inblocks (\src -> do
          createByteStringArray (n - k) sz (\fecs -> do
            uintCArray [k..(n - 1)] (\block_nums -> do
              sc <- _fec_encode cfec src fecs block_nums (fromIntegral (n - k)) $ fromIntegral sz
              case sc of
                ZfexScOk -> return ()
                _ -> error $ "fec_decode failed with unexpected status code " ++ show sc)))))

-- | A sort function for tagged assoc lists
sortTagged :: [(Int, a)] -> [(Int, a)]
sortTagged = sortBy (\a b -> compare (fst a) (fst b))

-- | Recover the primary blocks from a list of @k@ blocks. Each block must be
--   tagged with its number (see the module comments about block numbering)
decode :: FECParams
       -> [(Int, B.ByteString)]  -- ^ a list of @k@ blocks and their index
       -> [B.ByteString]  -- ^ a list the @k@ primary blocks
decode (FECParams params k n) inblocks
  | length (nub $ map fst inblocks) /= length (inblocks) = error "Duplicate input blocks in ZFEX decode"
  | any (\f -> f < 0 || f >= n) $ map fst inblocks = error "Invalid block numbers in ZFEX decode"
  | length inblocks /= k = error "Wrong number of blocks to FEC decode"
  | not (allByteStringsSameLength $ map snd inblocks) = error "Not all inputs to ZFEX decode are same length"
  | otherwise = unsafePerformIO (do
      let sz = B.length $ snd $ head inblocks
          presentBlocks = map fst inblocks
      withForeignPtr params (\cfec -> do
        byteStringsToArray (map snd inblocks) (\src -> do
          b <- createByteStringArray (n - k) sz (\out -> do
                 uintCArray presentBlocks (\block_nums -> do
                   sc <- _fec_decode cfec src out block_nums $ fromIntegral sz
                   case sc of
                     ZfexScOk -> return ()
                     _ -> error $ "fec_decode failed with unexpected status code " ++ show sc))
          let blocks = [0..(n - 1)] \\ presentBlocks
              tagged = zip blocks b
              allBlocks = sortTagged $ tagged ++ inblocks
          return $ take k $ map snd allBlocks)))

-- | Break a ByteString into @n@ parts, equal in length to the original, such
--   that all @n@ are required to reconstruct the original, but having less
--   than @n@ parts reveals no information about the orginal.
--
--   This code works in IO monad because it needs a source of random bytes,
--   which it gets from /dev/urandom. If this file doesn't exist an
--   exception results
--
--   Not terribly fast - probably best to do it with short inputs (e.g. an
--   encryption key)
secureDivide :: Int  -- ^ the number of parts requested
             -> B.ByteString  -- ^ the data to be split
             -> IO [B.ByteString]
secureDivide n input
  | n < 0 = error "secureDivide called with negative number of parts"
  | otherwise = do
      let inner 1 bs = return [bs]
          inner n' bs = do
            mask <- getEntropy (B.length bs)
            let masked = B.pack $ B.zipWith xor bs mask
            rest <- inner (n' - 1) masked
            return (mask : rest)
      inner n input

-- | Reverse the operation of secureDivide. The order of the inputs doesn't
--   matter, but they must all be the same length
secureCombine :: [B.ByteString] -> B.ByteString
secureCombine [] = error "Passed empty list of inputs to secureCombine"
secureCombine [a] = a
secureCombine [a, b] = B.pack $ B.zipWith xor a b
secureCombine (a : rest) = B.pack $ B.zipWith xor a $ secureCombine rest

-- | A utility function which takes an arbitary input and ZFEX encodes it into a
--   number of blocks. The order the resulting blocks doesn't matter so long
--   as you have enough to present to @deFEC@.
enFEC :: Int  -- ^ the number of blocks required to reconstruct
      -> Int  -- ^ the total number of blocks
      -> B.ByteString  -- ^ the data to divide
      -> [B.ByteString]  -- ^ the resulting blocks
enFEC k n input = taggedPrimaryBlocks ++ taggedSecondaryBlocks where
  taggedPrimaryBlocks = map (uncurry B.cons) $ zip [0..] primaryBlocks
  taggedSecondaryBlocks = map (uncurry B.cons) $ zip [(fromIntegral k)..] secondaryBlocks
  remainder = B.length input `mod` k
  paddingLength = if remainder >= 1 then (k - remainder) else k
  paddingBytes = (B.replicate (paddingLength - 1) 0) `B.append` (B.singleton $ fromIntegral paddingLength)
  divide a bs
    | B.null bs = []
    | otherwise = (B.take a bs) : (divide a $ B.drop a bs)
  input' = input `B.append` paddingBytes
  blockSize = B.length input' `div` k
  primaryBlocks = divide blockSize input'
  secondaryBlocks = encode params primaryBlocks
  params = fec k n

-- | Reverses the operation of @enFEC@.
deFEC :: Int  -- ^ the number of blocks required (matches call to @enFEC@)
      -> Int  -- ^ the total number of blocks (matches call to @enFEC@)
      -> [B.ByteString]  -- ^ a list of k, or more, blocks from @enFEC@
      -> B.ByteString
deFEC k n inputs
  | length inputs < k = error "Too few inputs to deFEC"
  | otherwise = B.take (B.length fecOutput - paddingLength) fecOutput where
      paddingLength = fromIntegral $ B.last fecOutput
      inputs' = take k inputs
      taggedInputs = map (\bs -> (fromIntegral $ B.head bs, B.tail bs)) inputs'
      fecOutput = B.concat $ decode params taggedInputs
      params = fec k n
