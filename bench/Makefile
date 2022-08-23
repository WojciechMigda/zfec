STRIDE := 8192
UNROLL := 16

bench_zfex: bench_zfex.c ../zfex/zfex.c ../zfex/zfex.h ../zfex/zfex_pp.h ../zfex/zfex_macros.h ../zfex/zfex_bytemask.h
	${CC} ${CFLAGS} -fno-strict-aliasing -Wall -Wextra -Werror -Wshadow -Wdate-time -Wformat -Werror=format-security -std=c99 -DZFEX_STRIDE=$(STRIDE) -DZFEX_UNROLL_ADDMUL=$(UNROLL) -o bench_zfex bench_zfex.c ../zfex/zfex.c  -I../zfex

clean:
	- rm bench_zfex
