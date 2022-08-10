#ifndef __ZFEX_MACROS_H
#define __ZFEX_MACROS_H

/**
 * zfex -- fast forward error correction library with Python interface
 *
 * Copyright (C) 2022 Wojciech Migda
 *
 * This file is part of zfex.
 *
 * See README.rst for licensing information.
 */

#if ((defined __arm__) || (defined __arm) || (defined _ARM) || (defined _M_ARM))
#define ZFEX_HAS_ARM 1
#else
#define ZFEX_HAS_ARM 0
#endif

#if (ZFEX_HAS_ARM == 1) && ((defined __ARM_NEON__) || (defined __ARM_NEON))
#define ZFEX_HAS_ARM_NEON 1
#else
#define ZFEX_HAS_ARM_NEON 0
#endif

#if (defined ZFEX_USE_ARM_NEON) && (ZFEX_HAS_ARM_NEON == 1)
#define ZFEX_ARM_NEON_FEATURE 1
#else
#define ZFEX_ARM_NEON_FEATURE 0
#endif


#if ((defined __x86_64__) || (defined __i386__))
#define ZFEX_HAS_INTEL 1
#else
#define ZFEX_HAS_INTEL 0
#endif

#if (ZFEX_HAS_INTEL == 1) && (defined __SSSE3__)
#define ZFEX_HAS_INTEL_SSSE3 1
#else
#define ZFEX_HAS_INTEL_SSSE3 0
#endif

#if (defined ZFEX_USE_INTEL_SSSE3) && (ZFEX_HAS_INTEL_SSSE3 == 1)
#define ZFEX_INTEL_SSSE3_FEATURE 1
#else
#define ZFEX_INTEL_SSSE3_FEATURE 0
#endif


#define ZFEX_IS_POWER_OF_2(x) ((x != 0) && !(x & (x - 1)))


#ifndef ZFEX_SIMD_ALIGNMENT
#define ZFEX_SIMD_ALIGNMENT 16
#endif

#if !ZFEX_IS_POWER_OF_2(ZFEX_SIMD_ALIGNMENT)
#error ZFEX_SIMD_ALIGNMENT is not a positive power of 2
#endif


/* __builtin_assume_aligned first appeared in GCC 4.7, and clang 3.6 */
#if (defined __GNUC__ && ((__GNUC__ * 100 + __GNUC_MINOR__) > 407)) || \
    (defined __clang_major__ && ((__clang_major__ * 100 + __clang_minor__) > 306))
#define ZFEX_ASSUME_ALIGNED(what, align) __builtin_assume_aligned(what, align)
#else
#define ZFEX_ASSUME_ALIGNED(what, align) (what)
#endif


#ifndef ZFEX_STRIDE
#define ZFEX_STRIDE 8192
#endif


#ifndef ZFEX_UNROLL_ADDMUL
#define ZFEX_UNROLL_ADDMUL 16
#endif

#ifndef ZFEX_UNROLL_ADDMUL_SIMD
#define ZFEX_UNROLL_ADDMUL_SIMD 1
#endif


#ifdef ZFEX_INLINE_ADDMUL
#define ZFEX_INLINE_ADDMUL_FEATURE 1
#else
#define ZFEX_INLINE_ADDMUL_FEATURE 0
#endif

#ifdef ZFEX_INLINE_ADDMUL_SIMD
#define ZFEX_INLINE_ADDMUL_SIMD_FEATURE 1
#else
#define ZFEX_INLINE_ADDMUL_SIMD_FEATURE 0
#endif


#endif /* __ZFEX_MACROS_H */
