#!/bin/bash
set -e

################################################################################
###
### This script will download legacy zfec code and build modified bench_zfex
### tool with different sets of compiler flags. Then, built executable will be
### run with different arguments to measure legacy algorithm's performance.
###
### Use CC environment variable to set a non-default compiler.
###
################################################################################


# cheat sheet: https://en.wikichip.org/wiki/intel/cpuid
lscpu

# Download and unpack zfec@master
wget https://github.com/tahoe-lafs/zfec/archive/refs/heads/master.zip -O zfec.zip
unzip zfec.zip
mv zfec-master zfec


# Create missing stub headers
touch zfec/zfec/zfex_macros.h zfec/zfec/zfex_pp.h


# Create stub zfec/zfec/zfex_status.h
cat <<__HERE > zfec/zfec/zfex_status.h
#ifndef __ZFEX_STATUS_H
#define __ZFEX_STATUS_H

typedef enum zfex_status_code_e
{
    ZFEX_SC_OK = 0,
} zfex_status_code_t;

#endif /* __ZFEX_STATUS_H */
__HERE


# Create stub zfec/zfec/zfex.h
cat <<__HERE > zfec/zfec/zfex.h
#ifndef __ZFEX_H
#define __ZFEX_H

/* patch incompatible legacy API */
#define fec_new fec_new_legacy
#include "fec.h"
#undef fec_new

#include "zfex_status.h"

static inline zfex_status_code_t
fec_new(unsigned short k, unsigned short m, fec_t **out_fec_pp)
{
    *out_fec_pp = fec_new_legacy(k, m);
    return ZFEX_SC_OK;
}

#endif /* __ZFEX_H */
__HERE


# Pass branch name or commit SHA as the first argument. The default is 'main'
# bench_zfec.c will be downloaded from that ref.
ZFEX_HEAD=${1:-main}


# Download bench_zfex.c as bench_zfec.c
wget https://raw.githubusercontent.com/WojciechMigda/zfex/${ZFEX_HEAD}/bench/bench_zfex.c -O zfec/bench/bench_zfec.c


# Create Makefile that will build bench_zfec linked against legacy zfec
cat << 'EOF' > zfec/bench/Makefile
STRIDE := 8192
UNROLL := 16

bench_zfec: bench_zfec.c ../zfec/fec.c ../zfec/fec.h
	# compile legacy zfec.c, redefining incompatible legacy API (fec_new)
	${CC} ${CFLAGS} -fno-strict-aliasing -Wall -Werror -Wshadow -Wdate-time -Wformat -Werror=format-security -std=c99 -DSTRIDE=$(STRIDE) -DZFEX_STRIDE=$(STRIDE) -DZFEX_UNROLL_ADDMUL=$(UNROLL) -DZFEX_UNROLL_ADDMUL_SIMD=1 -Dfec_new=fec_new_legacy -c -o zfec.o ../zfec/fec.c  -I../zfec
	# compile benchmark tool
	${CC} ${CFLAGS} -fno-strict-aliasing -Wall -Werror -Wshadow -Wdate-time -Wformat -Werror=format-security -std=c99 -DSTRIDE=$(STRIDE) -DZFEX_STRIDE=$(STRIDE) -DZFEX_UNROLL_ADDMUL=$(UNROLL) -DZFEX_UNROLL_ADDMUL_SIMD=1 -o bench_zfec bench_zfec.c zfec.o  -I../zfec

clean:
	- rm bench_zfec
EOF


build() {

make -C zfec/bench clean

CFLAGS="${EXTRA_CFLAGS} -DZFEX_SIMD_ALIGNMENT=16 -DZFEX_INTEL_SSSE3_FEATURE=0 -DZFEX_ARM_NEON_FEATURE=0 -DZFEX_INLINE_ADDMUL_FEATURE=0 -DZFEX_INLINE_ADDMUL_SIMD_FEATURE=0 -Dfec_encode_simd=fec_encode" \
  make -C zfec/bench bench_zfec

}

run() {

zfec/bench/bench_zfec ${ARGS} > /dev/null && zfec/bench/bench_zfec ${ARGS}

}

# Benchmark: -O2 and default cpu (pip build scenario)
EXTRA_CFLAGS="-O2" build

ARGS="-k 7 -m 10 -s 1000000 -i 30" run
ARGS="-k 223 -m 255 -s 43488 -i 30" run

# Benchmark: -O3 and default cpu
EXTRA_CFLAGS="-O3" build

ARGS="-k 7 -m 10 -s 1000000 -i 30" run
ARGS="-k 223 -m 255 -s 43488 -i 30" run

# Benchmark: -O2 and -march=native
EXTRA_CFLAGS="-O2 -march=native" build

ARGS="-k 7 -m 10 -s 1000000 -i 30" run
ARGS="-k 223 -m 255 -s 43488 -i 30" run

# Benchmark: -O3 and -march=native
EXTRA_CFLAGS="-O3 -march=native" build

ARGS="-k 7 -m 10 -s 1000000 -i 30" run
ARGS="-k 223 -m 255 -s 43488 -i 30" run
