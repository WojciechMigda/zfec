STRIDE := 8192
UNROLL := 16

bench_zfec: bench_zfec.c ../zfec/fec.c ../zfec/fec.h
	${CC} ${CFLAGS} -fno-strict-aliasing -Wall -Wextra -Werror -Wshadow -Wdate-time -Wformat -Werror=format-security -std=c99 -DSTRIDE=$(STRIDE) -DUNROLL=$(UNROLL) -o bench_zfec bench_zfec.c ../zfec/fec.c  -I../zfec

clean:
	rm bench_zfec
