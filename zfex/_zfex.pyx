"""ZFEX - Forward Error Correction
"""

from libc.stdint cimport uint16_t

from .__zfex import Encoder, Decoder, Error, test_from_agl


cdef extern from "zfex.h":
    ctypedef struct fec_t:
        pass
    fec_t* fec_new(unsigned short k, unsigned short m)
    void fec_free(fec_t *)


cdef class zEncoder:
    """\
Hold static encoder state (an in-memory table for matrix multiplication), and k and m parameters, and provide {encode()} method.

@param k: the number of packets required for reconstruction
@param m: the number of packets generated
"""
    cdef uint16_t kk
    cdef uint16_t mm
    cdef fec_t *fec_matrix

    def __cinit__(self):
        self.kk = 0
        self.mm = 0
        self.fec_matrix = NULL

    def __init__(self, unsigned short k, unsigned short m):
        assert k >= 1, f"Precondition violation: first argument is required to be greater than or equal to 1, but it was {k}"
        assert m >= 1, f"Precondition violation: second argument is required to be greater than or equal to 1, but it was {m}"
        assert m <= 256, f"Precondition violation: second argument is required to be less than or equal to 256, but it was {m}"
        assert k <= m, f"Precondition violation: first argument is required to be less than or equal to the second argument, but they were {k} and {m}, respectively"

        self.kk = k;
        self.mm = m;
        self.fec_matrix = fec_new(self.kk, self.mm)

    def __dealloc__(self):
        if self.fec_matrix:
            fec_free(self.fec_matrix);

    @property
    def k(self):
        return self.kk

    @property
    def m(self):
        return self.mm

    def encode(self, inblocks, desired_block_nums):
        """\
Encode data into m packets.

@param inblocks: a sequence of k buffers of data to encode -- these are the k primary blocks, i.e. the input data split into k pieces (for best performance, make it a tuple instead of a list);  All blocks are required to be the same length.
@param desired_blocks_nums optional sequence of blocknums indicating which blocks to produce and return;  If None, all m blocks will be returned (in order).  (For best performance, make it a tuple instead of a list.)
@returns: a list of buffers containing the requested blocks; Note that if any of the input blocks were 'primary blocks', i.e. their blocknum was < k, then the result sequence will contain a Python reference to the same Python object as was passed in.  As long as the Python object in question is immutable (i.e. a string) then you don't have to think about this detail, but if it is mutable (i.e. an array), then you have to be aware that if you subsequently mutate the contents of that object then that will also change the contents of the sequence that was returned from this call to encode().
"""
        pass

cdef class zDecoder:
    """\
Hold static decoder state (an in-memory table for matrix multiplication), and k and m parameters, and provide {decode()} method.

@param k: the number of packets required for reconstruction
@param m: the number of packets generated
"""
    cdef uint16_t kk
    cdef uint16_t mm
    cdef fec_t *fec_matrix

    def __cinit__(self):
        self.kk = 0
        self.mm = 0
        self.fec_matrix = NULL

    def __init__(self, unsigned short k, unsigned short m):
        assert k >= 1, f"Precondition violation: first argument is required to be greater than or equal to 1, but it was {k}"
        assert m >= 1, f"Precondition violation: second argument is required to be greater than or equal to 1, but it was {m}"
        assert m <= 256, f"Precondition violation: second argument is required to be less than or equal to 256, but it was {m}"
        assert k <= m, f"Precondition violation: first argument is required to be less than or equal to the second argument, but they were {k} and {m}, respectively"

        self.kk = k;
        self.mm = m;
        self.fec_matrix = fec_new(self.kk, self.mm)

    def __dealloc__(self):
        if self.fec_matrix:
            fec_free(self.fec_matrix);

    @property
    def k(self):
        return self.kk

    @property
    def m(self):
        return self.mm

    def decode(self, blocks, blocknums):
        """\
Decode a list blocks into a list of segments.

@param blocks a sequence of buffers containing block data (for best performance, make it a tuple instead of a list)
@param blocknums a sequence of integers of the blocknum for each block in blocks (for best performance, make it a tuple instead of a list)

@return a list of strings containing the segment data (i.e. ''.join(retval) yields a string containing the decoded data)
"""
