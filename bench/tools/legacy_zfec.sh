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

wget https://github.com/tahoe-lafs/zfec/archive/refs/heads/master.zip -O zfec.zip
unzip zfec.zip
mv zfec-master zfec
ln -sf fec.h zfec/zfec/zfex.h && touch zfec/zfec/zfex_macros.h zfec/zfec/zfex_pp.h

wget https://raw.githubusercontent.com/WojciechMigda/zfex/main/bench/bench_zfex.c -O zfec/bench/bench_zfec.c

cat << 'EOF' > zfec/bench/Makefile
STRIDE := 8192
UNROLL := 16

bench_zfec: bench_zfec.c ../zfec/fec.c ../zfec/fec.h
	${CC} ${CFLAGS} -fno-strict-aliasing -Wall -Werror -Wshadow -Wdate-time -Wformat -Werror=format-security -std=c99 -DSTRIDE=$(STRIDE) -DZFEX_STRIDE=$(STRIDE) -DZFEX_UNROLL_ADDMUL=$(UNROLL) -DZFEX_UNROLL_ADDMUL_SIMD=1 -o bench_zfec bench_zfec.c ../zfec/fec.c  -I../zfec

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
