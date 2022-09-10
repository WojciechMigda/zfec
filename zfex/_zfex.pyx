# -*- coding: utf-8 -*-
# distutils: language = c
#
# cython: wraparound  =     False
# cython: boundscheck =     False
# cython: language_level =  3

"""ZFEX - Forward Error Correction
"""

from cpython cimport sequence
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from cpython.int cimport PyInt_Check, PyInt_AsLong
from cpython.buffer cimport PyObject_CheckBuffer
from cpython.bytes cimport PyBytes_FromStringAndSize
from libc.stdint cimport intptr_t


include '_zfex_status.pxi'

cdef extern from "zfex.h":
    ctypedef struct fec_t:
        pass
    zfex_status_code_t fec_new(unsigned short k, unsigned short m, fec_t **out_fec_pp)
    zfex_status_code_t fec_free(fec_t *)
    zfex_status_code_t fec_encode(
        const fec_t *,
        const unsigned char **inpkts_pp,
        unsigned char **outpkts_pp,
        const unsigned int *indices_p,
        size_t num_block_nums,
        size_t sz)
    zfex_status_code_t fec_decode(
        const fec_t *,
        const unsigned char **inpkts_pp,
        unsigned char **outpkts_pp,
        unsigned int *indices_p,
        size_t sz)

cdef extern from *:
    """
#if defined _MSC_VER
#include <malloc.h>
#else
#include <alloca.h>
#endif
"""
    void *alloca(size_t size)


# This deserves little explanation:
#
# PyObject_CheckReadBuffer and PyObject_AsReadBuffer were used in the OG zfec
# python wrapper, but they come from Python2 C API and are deprecated.
# Python3 still exposes them, but as wrappers over existing buffers API,
# PyObject_CheckBuffer and PyObject_GetBuffer, respectively.
#
# PyObject_CheckReadBuffer wrapper does what PyObject_CheckBuffer does, with
# extra call to PyObject_GetBuffer. Since we are calling PyObject_CheckReadBuffer
# anyway, PyObject_CheckReadBuffer can be replaced with PyObject_CheckBuffer.
#
# For PyObject_AsReadBuffer we will simply copy relevant code from cpython. This will
# give us API we need without risk of Python3 scrapping it at some point, and we'll
# get rid of deprecation warnings at compile time, spewed when
# PyObject_CheckReadBuffer and PyObject_AsReadBuffer are used directly.

# https://cython.readthedocs.io/en/latest/src/userguide/external_C_code.html#including-verbatim-c-code
cdef extern from *:
    """
// based on https://github.com/python/cpython/blob/3.11/Objects/abstract.c#L25
// _PyErr_Occurred: https://github.com/python/cpython/blob/3.11/Include/internal/pycore_pyerrors.h#L20
// PyErr_Occurred: https://github.com/python/cpython/blob/3.11/Python/errors.c#L240
static PyObject *
null_error(void)
{
    if (!PyErr_Occurred()) {
        PyErr_SetString(PyExc_SystemError,
                         "null argument to internal routine");
    }
    return NULL;
}
// https://github.com/python/cpython/blob/3.11/Objects/abstract.c#L318
static int
as_read_buffer(PyObject *obj, const void **buffer, Py_ssize_t *buffer_len)
{
    Py_buffer view;

    if (obj == NULL || buffer == NULL || buffer_len == NULL) {
        null_error();
        return -1;
    }
    if (PyObject_GetBuffer(obj, &view, PyBUF_SIMPLE) != 0)
        return -1;

    *buffer = view.buf;
    *buffer_len = view.len;
    PyBuffer_Release(&view);
    return 0;
}
"""
    int as_read_buffer(PyObject *obj, const void **buffer, Py_ssize_t *buffer_len) except -1


cdef class Error(Exception):
    pass


cdef class Encoder:
    """\
Hold static encoder state (an in-memory table for matrix multiplication), and k and m parameters, and provide {encode()} method.

@param k: the number of packets required for reconstruction
@param m: the number of packets generated
"""
    cdef unsigned short kk
    cdef unsigned short mm
    cdef fec_t *fec_matrix

    def __cinit__(self):
        self.kk = 0
        self.mm = 0
        self.fec_matrix = NULL

    def __init__(self, int k, int m):
        if k < 1:
            raise Error(f"Precondition violation: "
                "first argument is required to be greater than or equal to 1, but it was {k}")
        if m < 1:
            raise Error(f"Precondition violation: "
                "second argument is required to be greater than or equal to 1, but it was {m}")
        if m > 256:
            raise Error(f"Precondition violation: "
                "second argument is required to be less than or equal to 256, but it was {m}")
        if k > m:
            raise Error(f"Precondition violation: "
            "first argument is required to be less than or equal to the second argument, "
            "but they were {k} and {m}, respectively")

        self.kk = k
        self.mm = m

        cdef zfex_status_code_t sc = fec_new(self.kk, self.mm, &self.fec_matrix)
        if sc != ZFEX_SC_OK:
            raise Error(f"Call to fec_new failed with unexpected status code {sc}")

    def __dealloc__(self):
        cdef zfex_status_code_t sc

        if self.fec_matrix:
            sc = fec_free(self.fec_matrix)
            if sc != ZFEX_SC_OK:
                raise Error(f"Call to fec_free failed with unexpected status code {sc}")

    @property
    def k(self):
        return self.kk

    @property
    def m(self):
        return self.mm

    def encode(self, inblocks, desired_block_nums=None):
        """\
Encode data into m packets.

@param inblocks: a sequence of k buffers of data to encode -- these are the k primary blocks, i.e. the input data split into k pieces (for best performance, make it a tuple instead of a list);  All blocks are required to be the same length.
@param desired_blocks_nums optional sequence of blocknums indicating which blocks to produce and return;  If None, all m blocks will be returned (in order).  (For best performance, make it a tuple instead of a list.)
@returns: a list of buffers containing the requested blocks; Note that if any of the input blocks were 'primary blocks', i.e. their blocknum was < k, then the result sequence will contain a Python reference to the same Python object as was passed in.  As long as the Python object in question is immutable (i.e. a string) then you don't have to think about this detail, but if it is mutable (i.e. an array), then you have to be aware that if you subsequently mutate the contents of that object then that will also change the contents of the sequence that was returned from this call to encode().
"""
        cdef unsigned int num_check_blocks_produced = 0
        cdef unsigned int num_desired_blocks = 0
        cdef unsigned int *c_desired_blocks_nums = NULL
        cdef object fast_desired_blocks_nums
        cdef PyObject **fastblocknumsitems = NULL
        cdef unsigned int i = 0

        if desired_block_nums is None:
            num_desired_blocks = self.mm
            c_desired_blocks_nums = <unsigned int *>alloca(num_desired_blocks * sizeof (unsigned int))
            for i in range(num_desired_blocks):
                c_desired_blocks_nums[i] = i
            num_check_blocks_produced = self.mm - self.kk
        else:
            fast_desired_blocks_nums = sequence.PySequence_Fast(desired_block_nums, "Second argument (optional) was not a sequence.")
            num_desired_blocks = sequence.PySequence_Fast_GET_SIZE(fast_desired_blocks_nums)
            fast_desired_blocks_nums_items = sequence.PySequence_Fast_ITEMS(fast_desired_blocks_nums)
            c_desired_blocks_nums = <unsigned int *>alloca(num_desired_blocks * sizeof (unsigned int))
            for i in range(num_desired_blocks):
                if PyInt_Check(<object>fast_desired_blocks_nums_items[i]) == 0:
                    raise Error("Precondition violation: second argument is required to contain int.")
                c_desired_blocks_nums[i] = PyInt_AsLong(<object>fast_desired_blocks_nums_items[i])
                if c_desired_blocks_nums[i] >= self.kk:
                    num_check_blocks_produced += 1

        cdef object fastinblocks = sequence.PySequence_Fast(inblocks, "First argument was not a sequence.")

        cdef Py_ssize_t fastinblocks_sz = sequence.PySequence_Fast_GET_SIZE(fastinblocks)
        if fastinblocks_sz != self.kk:
            raise Error(f"Precondition violation: Wrong length -- "
                "first argument (the sequence of input blocks) "
                "is required to contain exactly k blocks.  "
                "len(first): {fastinblocks_sz}, k: {self.kk}")

        cdef PyObject **fastinblocksitems = sequence.PySequence_Fast_ITEMS(fastinblocks)
        cdef Py_ssize_t sz = 0
        cdef Py_ssize_t prev_sz = 0
        cdef unsigned char **incblocks = <unsigned char **>alloca(self.kk * sizeof (unsigned char *))

        for i in range(self.kk):
            if PyObject_CheckBuffer(<object>fastinblocksitems[i]) != 1:
                raise Error(f"Precondition violation: "
                    "{i}'th item is required to offer the single-segment "
                    "read character buffer protocol, but it does not.")
            as_read_buffer(fastinblocksitems[i], <const void**>&(incblocks[i]), &sz)
            if prev_sz != 0 and prev_sz != sz:
                raise Error(f"Precondition violation: "
                    "Input blocks are required to be all the same length.  "
                    "length of one block was: {prev_sz}, length of another block was: {sz}")
            prev_sz = sz

        cdef PyObject **pystrs_produced = <PyObject **>alloca(num_check_blocks_produced * sizeof (PyObject *))
        cdef unsigned char **check_blocks_produced = <unsigned char **>alloca(num_check_blocks_produced * sizeof (unsigned char *))
        cdef unsigned int *c_desired_checkblocks_ids = <unsigned int *>alloca(num_check_blocks_produced * sizeof (unsigned int))
        cdef unsigned int check_block_index = 0

        for i in range(num_desired_blocks):
            if c_desired_blocks_nums[i] >= self.kk:
                c_desired_checkblocks_ids[check_block_index] = c_desired_blocks_nums[i]

                b = PyBytes_FromStringAndSize(NULL, sz)
                Py_INCREF(b) # Ref dance for PyPy [1]
                pystrs_produced[check_block_index] = <PyObject *>b

                check_blocks_produced[check_block_index] = <bytes>pystrs_produced[check_block_index]

                check_block_index += 1

        if check_block_index != num_check_blocks_produced:
            raise Error(f"Internal error: "
                "check_block_index {check_block_index} != "
                "num_check_blocks_produced {num_check_blocks_produced}")

        cdef zfex_status_code_t sc = fec_encode(
            self.fec_matrix, <const unsigned char **>incblocks,
            check_blocks_produced, c_desired_checkblocks_ids,
            num_check_blocks_produced, sz)
        if  sc != ZFEX_SC_OK:
            raise Error(f"Call to fec_encode failed with unexpected status code {sc}")

        # blend input blocks with redundancy blocks
        rv = []
        check_block_index = 0
        for i in range(num_desired_blocks):
            if c_desired_blocks_nums[i] < self.kk:
                rv.append(<object>fastinblocksitems[c_desired_blocks_nums[i]])
            else:
                rv.append(<object>pystrs_produced[check_block_index])
                Py_DECREF(<object>pystrs_produced[check_block_index]) # Ref dance for PyPy [2]
                check_block_index += 1

        return rv


cdef class Decoder:
    """\
Hold static decoder state (an in-memory table for matrix multiplication), and k and m parameters, and provide {decode()} method.

@param k: the number of packets required for reconstruction
@param m: the number of packets generated
"""
    cdef unsigned short kk
    cdef unsigned short mm
    cdef fec_t *fec_matrix

    def __cinit__(self):
        self.kk = 0
        self.mm = 0
        self.fec_matrix = NULL

    def __init__(self, int k, int m):
        if k < 1:
            raise Error(f"Precondition violation: "
                "first argument is required to be greater than or equal to 1, but it was {k}")
        if m < 1:
            raise Error(f"Precondition violation: "
                "second argument is required to be greater than or equal to 1, but it was {m}")
        if m > 256:
            raise Error(f"Precondition violation: "
                "second argument is required to be less than or equal to 256, but it was {m}")
        if k > m:
            raise Error(f"Precondition violation: "
            "first argument is required to be less than or equal to the second argument, "
            "but they were {k} and {m}, respectively")

        self.kk = k
        self.mm = m

        cdef zfex_status_code_t sc = fec_new(self.kk, self.mm, &self.fec_matrix)
        if  sc != ZFEX_SC_OK:
            raise Error(f"Call to fec_new failed with status code {sc}")

    def __dealloc__(self):
        cdef zfex_status_code_t sc

        if self.fec_matrix:
            sc = fec_free(self.fec_matrix)
            # TODO: handle errors
            if sc != ZFEX_SC_OK:
                raise Error(f"fec_free failed with unexpected status code {sc}")

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
        cdef object fastblocks = sequence.PySequence_Fast(blocks, "First argument was not a sequence.")
        cdef object fastblocknums = sequence.PySequence_Fast(blocknums, "Second argument was not a sequence.")

        cdef Py_ssize_t blocks_sz = sequence.PySequence_Fast_GET_SIZE(fastblocks)
        if blocks_sz > self.kk:
            raise Error(f"Precondition violation: "
                "Wrong length -- first argument is required to contain exactly k blocks.  "
                "len(blocks): {blocks_sz}, k: {self.kk}")

        cdef Py_ssize_t blocknums_sz = sequence.PySequence_Fast_GET_SIZE(fastblocknums)
        if blocknums_sz > self.kk:
            raise Error(f"Precondition violation: "
                "Wrong length -- blocknums is required to contain exactly k integers.  "
                "len(blocknums): {blocknums_sz}, k: {self.kk}")

        # these are non-owning pointers
        cdef PyObject **fastblocksitems = sequence.PySequence_Fast_ITEMS(fastblocks)
        cdef PyObject **fastblocknumsitems = sequence.PySequence_Fast_ITEMS(fastblocknums)

        cdef unsigned char** cblocks = <unsigned char **>alloca(self.kk * sizeof (void *))
        cdef unsigned int* cblocknums = <unsigned int *>alloca(self.kk * sizeof (unsigned int))
        cdef unsigned int i = 0
        cdef long blocknumitem = 0
        cdef unsigned int needtorecover = 0
        cdef Py_ssize_t sz = 0
        cdef Py_ssize_t prev_sz = 0


        # go through blocks and blocknums, as interfaced through
        # fastblocksitems and fastblocknumsitems
        cdef dict cblock_to_idx = {}
        for i in range(self.kk):
            # (1) blocknums
            if PyInt_Check(<object>fastblocknumsitems[i]) == 0:
                raise Error("Precondition violation: "
                    "second argument is required to contain int.")
            blocknumitem = PyInt_AsLong(<object>fastblocknumsitems[i])
            if blocknumitem < 0 or 255 < blocknumitem:
                raise Error(f"Precondition violation: "
                    "block nums can't be less than zero or greater than 255.  {blocknumitem}")

            # copy input blocknums into C-array
            cblocknums[i] = blocknumitem
            if blocknumitem >= self.kk:
                # keep track of number of blocks to be recovered
                needtorecover += 1

            # (2) blocks
            if PyObject_CheckBuffer(<object>fastblocksitems[i]) != 1:
                raise Error(f"Precondition violation: "
                    "{i}'th item is required to offer the single-segment read "
                    "character buffer protocol, but it does not.")
            as_read_buffer(fastblocksitems[i], <const void**>&(cblocks[i]), &sz)
            if prev_sz != 0 and prev_sz != sz:
                raise Error(f"Precondition violation: "
                    "Input blocks are required to be all the same length.  "
                    "length of one block was: {sz}, length of another block was: {prev_sz}")
            cblock_to_idx[<intptr_t>cblocks[i]] = i
            prev_sz = sz

        cdef PyObject ** recoveredpystrs = <PyObject **>alloca(needtorecover * sizeof (PyObject *))
        for i in range(needtorecover):
            b = PyBytes_FromStringAndSize(NULL, sz)
            Py_INCREF(b) # Ref dance for PyPy [1]
            recoveredpystrs[i] = <PyObject *>b

        # this array of raw non-owning pointers which will be passed to fec_decode
        cdef unsigned char** recoveredcstrs = <unsigned char **>alloca(needtorecover * sizeof (void *))

        for i in range(needtorecover):
            recoveredcstrs[i] = <bytes>recoveredpystrs[i]

        cdef zfex_status_code_t sc = fec_decode(
            self.fec_matrix, <const unsigned char **>cblocks, recoveredcstrs, cblocknums, sz)
        if sc == ZFEX_SC_DECODE_INVALID_BLOCK_INDEX:
            raise Error("fec_decode: Corrupted blocknums received.")
        elif sc != ZFEX_SC_OK:
            raise Error(f"fec_decode failed with unexpected status code {sc}")

        # blend input blocks with recovered blocks
        # redundancy blocks are replaced with recovered ones
        rv = []
        cdef Py_ssize_t ix = 0
        cdef unsigned int rix = 0
        cdef unsigned int fast_ix = 0
        for ix in range(blocks_sz):
            if cblocknums[ix] >= self.kk:
                rv.append(<object>recoveredpystrs[rix])
                Py_DECREF(<object>recoveredpystrs[rix]) # Ref dance for PyPy [2]
                rix += 1
            else:
                # As a side effect cblocks were rearranged by fec_decode.
                # To append associated python buffer we need to retrieve
                # its index from map we created earlier.
                fast_ix = cblock_to_idx[<intptr_t>cblocks[ix]]
                rv.append(<object>fastblocksitems[fast_ix])

        return rv
