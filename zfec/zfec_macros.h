#ifndef __ZFEC_MACROS_H
#define __ZFEC_MACROS_H


#if ((defined __arm__) || (defined __arm) || (defined _ARM) || (defined _M_ARM))
#define ZFEC_HAS_ARM 1
#else
#define ZFEC_HAS_ARM 0
#endif

#if (ZFEC_HAS_ARM == 1) && ((defined __ARM_NEON__) || (defined __ARM_NEON))
#define ZFEC_HAS_ARM_NEON 1
#else
#define ZFEC_HAS_ARM_NEON 0
#endif

#if (defined ZFEC_USE_ARM_NEON) && (ZFEC_HAS_ARM_NEON == 1)
#define ZFEC_ARM_NEON_FEATURE 1
#else
#define ZFEC_ARM_NEON_FEATURE 0
#endif


#if ((defined __x86_64__) || (defined __i386__))
#define ZFEC_HAS_INTEL 1
#else
#define ZFEC_HAS_INTEL 0
#endif

#if (ZFEC_HAS_INTEL == 1) && (defined __SSSE3__)
#define ZFEC_HAS_INTEL_SSSE3 1
#else
#define ZFEC_HAS_INTEL_SSSE3 0
#endif

#if (defined ZFEC_USE_INTEL_SSSE3) && (ZFEC_HAS_INTEL_SSSE3 == 1)
#define ZFEC_INTEL_SSSE3_FEATURE 1
#else
#define ZFEC_INTEL_SSSE3_FEATURE 0
#endif


#define IS_POWER_OF_2(x) ((x != 0) && !(x & (x - 1)))


#ifndef ZFEC_SIMD_ALIGNMENT
#define ZFEC_SIMD_ALIGNMENT 16
#endif

#if !IS_POWER_OF_2(ZFEC_SIMD_ALIGNMENT)
#error ZFEC_SIMD_ALIGNMENT is not a positive power of 2
#endif


#endif /* __ZFEC_MACROS_H */
