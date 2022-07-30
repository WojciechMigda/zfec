#ifndef __FEC_PP_H
#define __FEC_PP_H

#define PP_EXPAND(...) __VA_ARGS__

#define PP_REPEAT_2(ss) ss(0) ss(1)
#define PP_REPEAT_3(ss) PP_REPEAT_2(ss) ss(2)
#define PP_REPEAT_4(ss) PP_REPEAT_3(ss) ss(3)
#define PP_REPEAT_5(ss) PP_REPEAT_4(ss) ss(4)
#define PP_REPEAT_6(ss) PP_REPEAT_5(ss) ss(5)
#define PP_REPEAT_7(ss) PP_REPEAT_6(ss) ss(6)
#define PP_REPEAT_8(ss) PP_REPEAT_7(ss) ss(7)
#define PP_REPEAT_9(ss) PP_REPEAT_8(ss) ss(8)
#define PP_REPEAT_10(ss) PP_REPEAT_9(ss) ss(9)
#define PP_REPEAT_11(ss) PP_REPEAT_10(ss) ss(10)
#define PP_REPEAT_12(ss) PP_REPEAT_11(ss) ss(11)
#define PP_REPEAT_13(ss) PP_REPEAT_12(ss) ss(12)
#define PP_REPEAT_14(ss) PP_REPEAT_13(ss) ss(13)
#define PP_REPEAT_15(ss) PP_REPEAT_14(ss) ss(14)
#define PP_REPEAT_16(ss) PP_REPEAT_15(ss) ss(15)
#define PP_REPEAT_17(ss) PP_REPEAT_16(ss) ss(16)
#define PP_REPEAT_18(ss) PP_REPEAT_17(ss) ss(17)
#define PP_REPEAT_19(ss) PP_REPEAT_18(ss) ss(18)
#define PP_REPEAT_20(ss) PP_REPEAT_19(ss) ss(19)
#define PP_REPEAT_21(ss) PP_REPEAT_20(ss) ss(20)
#define PP_REPEAT_22(ss) PP_REPEAT_21(ss) ss(21)
#define PP_REPEAT_23(ss) PP_REPEAT_22(ss) ss(22)
#define PP_REPEAT_24(ss) PP_REPEAT_23(ss) ss(23)
#define PP_REPEAT_25(ss) PP_REPEAT_24(ss) ss(24)
#define PP_REPEAT_26(ss) PP_REPEAT_25(ss) ss(25)
#define PP_REPEAT_27(ss) PP_REPEAT_26(ss) ss(26)
#define PP_REPEAT_28(ss) PP_REPEAT_27(ss) ss(27)
#define PP_REPEAT_29(ss) PP_REPEAT_28(ss) ss(28)
#define PP_REPEAT_30(ss) PP_REPEAT_29(ss) ss(29)
#define PP_REPEAT_31(ss) PP_REPEAT_30(ss) ss(30)
#define PP_REPEAT_32(ss) PP_REPEAT_31(ss) ss(31)
#define PP_REPEAT_33(ss) PP_REPEAT_32(ss) ss(32)
#define PP_REPEAT_34(ss) PP_REPEAT_33(ss) ss(33)
#define PP_REPEAT_35(ss) PP_REPEAT_34(ss) ss(34)
#define PP_REPEAT_36(ss) PP_REPEAT_35(ss) ss(35)
#define PP_REPEAT_37(ss) PP_REPEAT_36(ss) ss(36)
#define PP_REPEAT_38(ss) PP_REPEAT_37(ss) ss(37)
#define PP_REPEAT_39(ss) PP_REPEAT_38(ss) ss(38)
#define PP_REPEAT_40(ss) PP_REPEAT_39(ss) ss(39)
#define PP_REPEAT_41(ss) PP_REPEAT_40(ss) ss(40)

#define PP_REPEAT__(N, X) PP_EXPAND(PP_REPEAT_ ## N)(X)
#define PP_REPEAT_(N, X) PP_REPEAT__(N, X)
#define PP_REPEAT(N, X) PP_REPEAT_(PP_EXPAND(N), X)

/**
 * zfec -- fast forward error correction library with Python interface
 * 
 * Copyright (C) 2007-2008 Allmydata, Inc.
 * Author: Zooko Wilcox-O'Hearn
 * 
 * This file is part of zfec.
 * 
 * See README.rst for licensing information.
 *
 * Modifications by Wojciech Migda (see commits in
 * github.com/WojciechMigda/zfec repository for their scope).
 * Modifications (C) 2022 Wojciech Migda (github.com/WojciechMigda)
 */

/*
 * Much of this work is derived from the "fec" software by Luigi Rizzo, et 
 * al., the copyright notice and licence terms of which are included below 
 * for reference.
 * 
 * fec.h -- forward error correction based on Vandermonde matrices
 * 980614
 * (C) 1997-98 Luigi Rizzo (luigi@iet.unipi.it)
 *
 * Portions derived from code by Phil Karn (karn@ka9q.ampr.org),
 * Robert Morelos-Zaragoza (robert@spectra.eng.hawaii.edu) and Hari
 * Thirumoorthy (harit@spectra.eng.hawaii.edu), Aug 1995
 *
 * Modifications by Dan Rubenstein (see Modifications.txt for 
 * their description.
 * Modifications (C) 1998 Dan Rubenstein (drubenst@cs.umass.edu)
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:

 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 */

#endif /* __FEC_PP_H */
