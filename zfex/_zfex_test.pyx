# -*- coding: utf-8 -*-
# distutils: language = c
#
# cython: wraparound  =     False
# cython: boundscheck =     False
# cython: language_level =  3

cdef extern from *:
    """
#include "zfex.h"

#include <Python.h>

#include <stddef.h>
#include <stdio.h>
#include <string.h>

void
_hexwrite(unsigned char*s, size_t l) {
  size_t i;
  for (i = 0; i < l; i++)
    printf("%.2x", s[i]);
}


PyObject*
_test_from_agl() {
  unsigned char b0c[8], b1c[8];
  unsigned char b0[8], b1[8], b2[8], b3[8], b4[8];

  const unsigned char *blocks[3] = {b0, b1, b2};
  unsigned char *outblocks[2] = {b3, b4};
  unsigned block_nums[] = {3, 4};

  fec_t *fec = NULL;
  zfex_status_code_t const sc = fec_new(3, 5, &fec);
  if (sc != ZFEX_SC_OK)
  {
    printf("Error: call to fec_new failed with status code %d\\n", sc);
    Py_RETURN_FALSE;
  }

  const unsigned char *inpkts[] = {b3, b4, b2};
  unsigned char *outpkts[] = {b0, b1};
  unsigned indexes[] = {3, 4, 2};

  memset(b0, 1, 8);
  memset(b1, 2, 8);
  memset(b2, 3, 8);

  /*printf("_from_c before encoding:\n");
  printf("b0: "); _hexwrite(b0, 8); printf(", ");
  printf("b1: "); _hexwrite(b1, 8); printf(", ");
  printf("b2: "); _hexwrite(b2, 8); printf(", ");
  printf("\n");*/

  fec_encode(fec, blocks, outblocks, block_nums, 2, 8);

  /*printf("after encoding:\n");
  printf("b3: "); _hexwrite(b3, 8); printf(", ");
  printf("b4: "); _hexwrite(b4, 8); printf(", ");
  printf("\n");*/

  memcpy(b0c, b0, 8); memcpy(b1c, b1, 8);

  fec_decode(fec, inpkts, outpkts, indexes, 8);

  /*printf("after decoding:\n");
  printf("b0: "); _hexwrite(b0, 8); printf(", ");
  printf("b1: "); _hexwrite(b1, 8);
  printf("\n");*/

  if ((memcmp(b0, b0c,8) == 0) && (memcmp(b1, b1c,8) == 0))
    Py_RETURN_TRUE;
  else
    Py_RETURN_FALSE;
}
"""
    object _test_from_agl()

def test_from_agl():
    return _test_from_agl()
