#!/bin/bash
set -e

################################################################################
###
### This script will download zfex code and build bench_zfex
### tool with different sets of compiler flags. Then, built executable will be
### run with different arguments to measure algorithm's performance.
###
### Use CC environment variable to set a non-default compiler.
###
################################################################################


# cheat sheet: https://en.wikichip.org/wiki/intel/cpuid
lscpu

wget https://github.com/WojciechMigda/zfex/archive/refs/heads/main.zip -O zfex.zip
unzip zfex.zip
mv zfex-main zfex

build() {

make -C zfex/bench clean

CFLAGS="${EXTRA_CFLAGS} -DZFEX_SIMD_ALIGNMENT=16 -DZFEX_USE_INTEL_SSSE3 -mssse3 -DZFEX_INLINE_ADDMUL -DZFEX_INLINE_ADDMUL_SIMD" \
  make -C zfex/bench bench_zfex

}

run() {

zfex/bench/bench_zfex ${ARGS} > /dev/null && zfex/bench/bench_zfex ${ARGS}

}

# Benchmark: -O2 -DZFEX_UNROLL_ADDMUL_SIMD=1
EXTRA_CFLAGS="-O2 -DZFEX_UNROLL_ADDMUL_SIMD=1" build

ARGS="-A -k 7 -m 10 -s 1000000 -i 30" run
ARGS="-A -k 223 -m 255 -s 43488 -i 30" run

# Benchmark: -O3 -DZFEX_UNROLL_ADDMUL_SIMD=1
EXTRA_CFLAGS="-O3 -DZFEX_UNROLL_ADDMUL_SIMD=1" build

ARGS="-A -k 7 -m 10 -s 1000000 -i 30" run
ARGS="-A -k 223 -m 255 -s 43488 -i 30" run

# Benchmark: -O3 -DZFEX_UNROLL_ADDMUL_SIMD=2
EXTRA_CFLAGS="-O3 -DZFEX_UNROLL_ADDMUL_SIMD=2" build

ARGS="-A -k 7 -m 10 -s 1000000 -i 30" run
ARGS="-A -k 223 -m 255 -s 43488 -i 30" run

# Benchmark: -O3 -DZFEX_UNROLL_ADDMUL_SIMD=4
EXTRA_CFLAGS="-O3 -DZFEX_UNROLL_ADDMUL_SIMD=4" build

ARGS="-A -k 7 -m 10 -s 1000000 -i 30" run
ARGS="-A -k 223 -m 255 -s 43488 -i 30" run

# Benchmark: -O3 -DZFEX_UNROLL_ADDMUL_SIMD=8
EXTRA_CFLAGS="-O3 -DZFEX_UNROLL_ADDMUL_SIMD=8" build

ARGS="-A -k 7 -m 10 -s 1000000 -i 30" run
ARGS="-A -k 223 -m 255 -s 43488 -i 30" run
