STRIDE := 8192
UNROLL := 16

bench_zfec: bench_zfec.c ../zfec/fec.c ../zfec/fec.h ../zfec/zfec_pp.h ../zfec/zfec_macros.h
	${CC} ${CFLAGS} -fno-strict-aliasing -Wall -Wextra -Werror -Wshadow -Wdate-time -Wformat -Werror=format-security -std=c99 -DZFEC_STRIDE=$(STRIDE) -DUNROLL=$(UNROLL) -o bench_zfec bench_zfec.c ../zfec/fec.c  -I../zfec

clean:
	rm bench_zfec
