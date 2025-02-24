from __future__ import print_function
import array, os, struct
from base64 import b32encode

import zfex
from zfex import easyfec

CHUNKSIZE = 4096

def pad_size(n, k):
    """
    The smallest number that has to be added to n to equal a multiple of k.
    """
    if n%k:
        return k - n%k
    else:
        return 0

def log_ceil(n, b):
    """
    The smallest integer k such that b^k >= n.

    log_ceil(n, 2) is the number of bits needed to store any of n values, e.g.
    the number of bits needed to store any of 128 possible values is 7.
    """
    p = 1
    k = 0
    while p < n:
        p *= b
        k += 1
    return k

def ab(x): # debuggery
    if len(x) >= 3:
        return "%s:%s" % (len(x), b32encode(x[-3:]),)
    elif len(x) == 2:
        return "%s:%s" % (len(x), b32encode(x[-2:]),)
    elif len(x) == 1:
        return "%s:%s" % (len(x), b32encode(x[-1:]),)
    elif len(x) == 0:
        return "%s:%s" % (len(x), "--empty--",)

class InsufficientShareFilesError(zfex.Error):
    def __init__(self, k, kb, *args, **kwargs):
        zfex.Error.__init__(self, *args, **kwargs)
        self.k = k
        self.kb = kb

    def __repr__(self):
        return "Insufficient share files -- %d share files are required to recover this file, but only %d were given" % (self.k, self.kb,)

    def __str__(self):
        return self.__repr__()

class CorruptedShareFilesError(zfex.Error):
    pass

def _build_header(m, k, pad, sh):
    """
    @param m: the total number of shares; 1 <= m <= 256
    @param k: the number of shares required to reconstruct; 1 <= k <= m
    @param pad: the number of bytes of padding added to the file before encoding; 0 <= pad < k
    @param sh: the shnum of this share; 0 <= k < m

    @return: a compressed string encoding m, k, pad, and sh
    """
    assert m >= 1
    assert m <= 2**8
    assert k >= 1
    assert k <= m
    assert pad >= 0
    assert pad < k

    assert sh >= 0
    assert sh < m

    bitsused = 0
    val = 0

    val |= (m - 1)
    bitsused += 8 # the first 8 bits always encode m

    kbits = log_ceil(m, 2) # num bits needed to store all possible values of k
    val <<= kbits
    bitsused += kbits

    val |= (k - 1)

    padbits = log_ceil(k, 2) # num bits needed to store all possible values of pad
    val <<= padbits
    bitsused += padbits

    val |= pad

    shnumbits = log_ceil(m, 2) # num bits needed to store all possible values of shnum
    val <<= shnumbits
    bitsused += shnumbits

    val |= sh

    assert bitsused >= 8, bitsused
    assert bitsused <= 32, bitsused

    if bitsused <= 16:
        val <<= (16-bitsused)
        cs = struct.pack('>H', val)
        assert cs[:-2] == b'\x00' * (len(cs)-2)
        return cs[-2:]
    if bitsused <= 24:
        val <<= (24-bitsused)
        cs = struct.pack('>I', val)
        assert cs[:-3] == b'\x00' * (len(cs)-3)
        return cs[-3:]
    else:
        val <<= (32-bitsused)
        cs = struct.pack('>I', val)
        assert cs[:-4] == b'\x00' * (len(cs)-4)
        return cs[-4:]

def MASK(bits):
    return (1<<bits)-1

def _parse_header(inf):
    """
    @param inf: an object which I can call read(1) on to get another byte

    @return: tuple of (m, k, pad, sh,); side-effect: the first one to four
        bytes of inf will be read
    """
    # The first 8 bits always encode m.
    ch = inf.read(1)
    if not ch:
        raise CorruptedShareFilesError("Share files were corrupted -- share file %r didn't have a complete metadata header at the front.  Perhaps the file was truncated." % (inf.name,))
    byte = ord(ch)
    m = byte + 1

    # The next few bits encode k.
    kbits = log_ceil(m, 2) # num bits needed to store all possible values of k
    b2_bits_left = 8-kbits
    kbitmask = MASK(kbits) << b2_bits_left
    ch = inf.read(1)
    if not ch:
        raise CorruptedShareFilesError("Share files were corrupted -- share file %r didn't have a complete metadata header at the front.  Perhaps the file was truncated." % (inf.name,))
    byte = ord(ch)
    k = ((byte & kbitmask) >> b2_bits_left) + 1

    shbits = log_ceil(m, 2) # num bits needed to store all possible values of shnum
    padbits = log_ceil(k, 2) # num bits needed to store all possible values of pad

    val = byte & (~kbitmask)

    needed_padbits = padbits - b2_bits_left
    if needed_padbits > 0:
        ch = inf.read(1)
        if not ch:
            raise CorruptedShareFilesError("Share files were corrupted -- share file %r didn't have a complete metadata header at the front.  Perhaps the file was truncated." % (inf.name,))
        byte = struct.unpack(">B", ch)[0]
        val <<= 8
        val |= byte
        needed_padbits -= 8
    assert needed_padbits <= 0
    extrabits = -needed_padbits
    pad = val >> extrabits
    val &= MASK(extrabits)

    needed_shbits = shbits - extrabits
    if needed_shbits > 0:
        ch = inf.read(1)
        if not ch:
            raise CorruptedShareFilesError("Share files were corrupted -- share file %r didn't have a complete metadata header at the front.  Perhaps the file was truncated." % (inf.name,))
        byte = struct.unpack(">B", ch)[0]
        val <<= 8
        val |= byte
        needed_shbits -= 8
    assert needed_shbits <= 0

    gotshbits = -needed_shbits

    sh = val >> gotshbits

    return (m, k, pad, sh,)

FORMAT_FORMAT = "%%s.%%0%dd_%%0%dd%%s"
RE_FORMAT = "%s.[0-9]+_[0-9]+%s"
def encode_to_files(inf, fsize, dirname, prefix, k, m, suffix=".fec", overwrite=False, verbose=False):
    """
    Encode inf, writing the shares to specially named, newly created files.

    @param fsize: calling read() on inf must yield fsize bytes of data and
        then raise an EOFError
    @param dirname: the name of the directory into which the sharefiles will
        be written
    """
    mlen = len(str(m))
    format = FORMAT_FORMAT % (mlen, mlen,)

    padbytes = pad_size(fsize, k)

    fns = []
    fs = []
    got_error = False
    try:
        for shnum in range(m):
            hdr = _build_header(m, k, padbytes, shnum)

            fn = os.path.join(dirname, format % (prefix, shnum, m, suffix,))
            if verbose:
                print("Creating share file %r..." % (fn,))
            if overwrite:
                f = open(fn, "wb")
            else:
                flags = os.O_WRONLY|os.O_CREAT|os.O_EXCL | (hasattr(os, 'O_BINARY') and os.O_BINARY)
                fd = os.open(fn, flags)
                f = os.fdopen(fd, "wb")
            fs.append(f)
            fns.append(fn)
            f.write(hdr)
        sumlen = [0]
        def cb(blocks, length):
            assert len(blocks) == len(fs)
            oldsumlen = sumlen[0]
            sumlen[0] += length
            if verbose:
                if int((float(oldsumlen) / fsize) * 10) != int((float(sumlen[0]) / fsize) * 10):
                    print(str(int((float(sumlen[0]) / fsize) * 10) * 10) + "% ...", end=" ")

            if sumlen[0] > fsize:
                raise IOError("Wrong file size -- possibly the size of the file changed during encoding.  Original size: %d, observed size at least: %s" % (fsize, sumlen[0],))
            for i in range(len(blocks)):
                data = blocks[i]
                fs[i].write(data)
                length -= len(data)

        encode_file_stringy_easyfec(inf, cb, k, m, chunksize=4096)
    except EnvironmentError as le:
        print("Cannot complete because of exception: ")
        print(le)
        got_error = True
    finally:
        for f in fs:
            f.close()
        if got_error:
            print("Cleaning up...")
            # clean up
            for fn in fns:
                if verbose:
                    print("Cleaning up: trying to remove %r..." % (fn,))
                try:
                    os.remove(fn)
                except EnvironmentError:
                    pass
            return 1
    if verbose:
        print()
        print("Done!")
    return 0

# Note: if you really prefer base-2 and you change this code, then please
# denote 2^20 as "MiB" instead of "MB" in order to avoid ambiguity.  See:
# http://en.wikipedia.org/wiki/Megabyte
# Thanks.
MILLION_BYTES=10**6

def decode_from_files(outf, infiles, verbose=False):
    """
    Decode from the first k files in infiles, writing the results to outf.
    """
    assert len(infiles) >= 2
    infs = []
    shnums = []
    m = None
    k = None
    padlen = None

    byteswritten = 0
    for f in infiles:
        (nm, nk, npadlen, shnum,) = _parse_header(f)
        if not (m is None or m == nm):
            raise CorruptedShareFilesError("Share files were corrupted -- share file %r said that m was %s but another share file previously said that m was %s" % (f.name, nm, m,))
        m = nm
        if not (k is None or k == nk):
            raise CorruptedShareFilesError("Share files were corrupted -- share file %r said that k was %s but another share file previously said that k was %s" % (f.name, nk, k,))
        if not (k is None or k <= len(infiles)):
            raise InsufficientShareFilesError(k, len(infiles))
        k = nk
        if not (padlen is None or padlen == npadlen):
            raise CorruptedShareFilesError("Share files were corrupted -- share file %r said that pad length was %s but another share file previously said that pad length was %s" % (f.name, npadlen, padlen,))
        padlen = npadlen

        infs.append(f)
        shnums.append(shnum)

        if len(infs) == k:
            break

    dec = easyfec.Decoder(k, m)

    while True:
        chunks = [ inf.read(CHUNKSIZE) for inf in infs ]
        if [ch for ch in chunks if len(ch) != len(chunks[-1])]:
            raise CorruptedShareFilesError("Share files were corrupted -- all share files are required to be the same length, but they weren't.")

        if len(chunks[-1]) > 0:
            resultdata = dec.decode(chunks, shnums, padlen=0)
            outf.write(resultdata)
            byteswritten += len(resultdata)
            if verbose:
                if ((byteswritten - len(resultdata)) / (10*MILLION_BYTES)) != (byteswritten / (10*MILLION_BYTES)):
                    print(str(byteswritten / MILLION_BYTES) + " MB ...", end=" ")
        else:
            if padlen > 0:
                outf.truncate(byteswritten - padlen)
            return # Done.
    if verbose:
        print()
        print("Done!")

def encode_file(inf, cb, k, m, chunksize=4096):
    """
    Read in the contents of inf, encode, and call cb with the results.

    First, k "input blocks" will be read from inf, each input block being of
    size chunksize.  Then these k blocks will be encoded into m "result
    blocks".  Then cb will be invoked, passing a list of the m result blocks
    as its first argument, and the length of the encoded data as its second
    argument.  (The length of the encoded data is always equal to k*chunksize,
    until the last iteration, when the end of the file has been reached and
    less than k*chunksize bytes could be read from the file.)  This procedure
    is iterated until the end of the file is reached, in which case the space
    of the input blocks that is unused is filled with zeroes before encoding.

    Note that the sequence passed in calls to cb() contains mutable array
    objects in its first k elements whose contents will be overwritten when
    the next segment is read from the input file.  Therefore the
    implementation of cb() has to either be finished with those first k arrays
    before returning, or if it wants to keep the contents of those arrays for
    subsequent use after it has returned then it must make a copy of them to
    keep.

    @param inf the file object from which to read the data
    @param cb the callback to be invoked with the results
    @param k the number of shares required to reconstruct the file
    @param m the total number of shares created
    @param chunksize how much data to read from inf for each of the k input
        blocks
    """
    enc = zfex.Encoder(k, m)
    l = tuple([ array.array('c') for i in range(k) ])
    indatasize = k*chunksize # will be reset to shorter upon EOF
    eof = False
    ZEROES=array.array('c', ['\x00'])*chunksize
    while not eof:
        # This loop body executes once per segment.
        i = 0
        while (i<len(l)):
            # This loop body executes once per chunk.
            a = l[i]
            del a[:]
            try:
                a.fromfile(inf, chunksize)
                i += 1
            except EOFError:
                eof = True
                indatasize = i*chunksize + len(a)

                # padding
                a.fromstring("\x00" * (chunksize-len(a)))
                i += 1
                while (i<len(l)):
                    a = l[i]
                    a[:] = ZEROES
                    i += 1

        res = enc.encode(l)
        cb(res, indatasize)

try:
    from hashlib import sha1
    sha1 = sha1 # hush pyflakes
except ImportError:
    # hashlib was added in Python 2.5.0.
    import sha
    sha1 = sha

def encode_file_not_really(inf, cb, k, m, chunksize=4096):
    enc = zfex.Encoder(k, m)
    l = tuple([ array.array('c') for i in range(k) ])
    indatasize = k*chunksize # will be reset to shorter upon EOF
    eof = False
    ZEROES=array.array('c', ['\x00'])*chunksize
    while not eof:
        # This loop body executes once per segment.
        i = 0
        while (i<len(l)):
            # This loop body executes once per chunk.
            a = l[i]
            del a[:]
            try:
                a.fromfile(inf, chunksize)
                i += 1
            except EOFError:
                eof = True
                indatasize = i*chunksize + len(a)

                # padding
                a.fromstring("\x00" * (chunksize-len(a)))
                i += 1
                while (i<len(l)):
                    a = l[i]
                    a[:] = ZEROES
                    i += 1

        # res = enc.encode(l)
        cb(None, None)

def encode_file_not_really_and_hash(inf, cb, k, m, chunksize=4096):
    hasher = sha1.new()
    enc = zfex.Encoder(k, m)
    l = tuple([ array.array('c') for i in range(k) ])
    indatasize = k*chunksize # will be reset to shorter upon EOF
    eof = False
    ZEROES=array.array('c', ['\x00'])*chunksize
    while not eof:
        # This loop body executes once per segment.
        i = 0
        while (i<len(l)):
            # This loop body executes once per chunk.
            a = l[i]
            del a[:]
            try:
                a.fromfile(inf, chunksize)
                i += 1
            except EOFError:
                eof = True
                indatasize = i*chunksize + len(a)

                # padding
                a.fromstring("\x00" * (chunksize-len(a)))
                i += 1
                while (i<len(l)):
                    a = l[i]
                    a[:] = ZEROES
                    i += 1

        # res = enc.encode(l)
        for thing in l:
            hasher.update(thing)
        cb(None, None)

def encode_file_stringy(inf, cb, k, m, chunksize=4096):
    """
    Read in the contents of inf, encode, and call cb with the results.

    First, k "input blocks" will be read from inf, each input block being of
    size chunksize.  Then these k blocks will be encoded into m "result
    blocks".  Then cb will be invoked, passing a list of the m result blocks
    as its first argument, and the length of the encoded data as its second
    argument.  (The length of the encoded data is always equal to k*chunksize,
    until the last iteration, when the end of the file has been reached and
    less than k*chunksize bytes could be read from the file.)  This procedure
    is iterated until the end of the file is reached, in which case the part
    of the input shares that is unused is filled with zeroes before encoding.

    @param inf the file object from which to read the data
    @param cb the callback to be invoked with the results
    @param k the number of shares required to reconstruct the file
    @param m the total number of shares created
    @param chunksize how much data to read from inf for each of the k input
        blocks
    """
    enc = zfex.Encoder(k, m)
    indatasize = k*chunksize # will be reset to shorter upon EOF
    while indatasize == k*chunksize:
        # This loop body executes once per segment.
        i = 0
        l = []
        ZEROES = b'\x00'*chunksize
        while i<k:
            # This loop body executes once per chunk.
            i += 1
            l.append(inf.read(chunksize))
            if len(l[-1]) < chunksize:
                indatasize = i*chunksize + len(l[-1])

                # padding
                l[-1] = l[-1] + b"\x00" * (chunksize-len(l[-1]))
                while i<k:
                    l.append(ZEROES)
                    i += 1

        res = enc.encode(l)
        cb(res, indatasize)

def encode_file_stringy_easyfec(inf, cb, k, m, chunksize=4096):
    """
    Read in the contents of inf, encode, and call cb with the results.

    First, chunksize*k bytes will be read from inf, then encoded into m
    "result blocks".  Then cb will be invoked, passing a list of the m result
    blocks as its first argument, and the length of the encoded data as its
    second argument.  (The length of the encoded data is always equal to
    k*chunksize, until the last iteration, when the end of the file has been
    reached and less than k*chunksize bytes could be read from the file.)
    This procedure is iterated until the end of the file is reached, in which
    case the space of the input that is unused is filled with zeroes before
    encoding.

    @param inf the file object from which to read the data
    @param cb the callback to be invoked with the results
    @param k the number of shares required to reconstruct the file
    @param m the total number of shares created
    @param chunksize how much data to read from inf for each of the k input
        blocks
    """
    enc = easyfec.Encoder(k, m)

    readsize = k*chunksize
    indata = inf.read(readsize)
    while indata:
        res = enc.encode(indata)
        cb(res, len(indata))
        indata = inf.read(readsize)

# zfex -- fast forward error correction library with Python interface
#
# Copyright (C) 2007-2010 Allmydata, Inc.
# Author: Zooko Wilcox-O'Hearn
#
# This file is part of zfex.
#
# See README.rst for licensing information.
