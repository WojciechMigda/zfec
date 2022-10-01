module Main where

import qualified Data.ByteString as B
import qualified Codec.ZFEX as ZFEX
import System.IO (withFile, IOMode(..))
import System.Random
import System.Entropy
import Data.List (sortBy)

import Test.QuickCheck

-- | Return true if the given @k@ and @n@ values are valid
isValidConfig :: Int -> Int -> Bool
isValidConfig k n
  | k >= n = False
  | k < 1 = False
  | n < 1 = False
  | otherwise = True

randomTake :: Int -> Int -> [a] -> [a]
randomTake seed n values = map snd $ take n sortedValues where
  sortedValues = sortBy (\a b -> compare (fst a) (fst b)) taggedValues
  taggedValues = zip rnds values
  rnds :: [Float]
  rnds = randoms gen
  gen = mkStdGen seed

testZFEX k n len seed = ZFEX.decode fec someTaggedBlocks == origBlocks where
  origBlocks = map (\i -> B.replicate len $ fromIntegral i) [0..(k - 1)]
  fec = ZFEX.fec k n
  secondaryBlocks = ZFEX.encode fec origBlocks
  taggedBlocks = zip [0..] (origBlocks ++ secondaryBlocks)
  someTaggedBlocks = randomTake seed k taggedBlocks

prop_ZFEX :: Int -> Int -> Int -> Int -> Property
prop_ZFEX k n len seed =
  isValidConfig k n && n < 256 && 0 <= len && len < 1024 ==> testZFEX k n len seed

checkDivide :: Int -> IO ()
checkDivide n = do
  let input = B.replicate 1024 65
  parts <- ZFEX.secureDivide n input
  if ZFEX.secureCombine parts == input
     then return ()
     else fail "checkDivide failed"

checkEnFEC :: Int -> IO ()
checkEnFEC len = do
  testdata <- getEntropy len
  let [a, b, c, d, e] = ZFEX.enFEC 3 5 testdata
  if ZFEX.deFEC 3 5 [b, e, d] == testdata
     then return ()
     else fail "deFEC failure"

main = do
  quickCheck (withMaxSuccess 10000 prop_ZFEX)
  mapM_ checkDivide [1, 2, 3, 4, 10]
  mapM_ checkEnFEC [1, 2, 3, 4, 5, 1024 * 1024]
