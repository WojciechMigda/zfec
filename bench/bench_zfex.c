#include "zfex.h"
#include "zfex_macros.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <sys/time.h>


typedef enum
{
    FALSE,
    TRUE
} bool_t;

typedef struct parsed_args_s
{
    bool_t help;
    bool_t quiet;
    bool_t xsums;
    bool_t simd;
    unsigned short k;
    unsigned short m;
    unsigned int runiters;
    unsigned int runreps;
    unsigned long data_sz;
    void *static_pattern;
} parsed_args_t;

int parse_args(int argc, char* argv[], parsed_args_t *parsed_p)
{
    bool_t show_help = FALSE;
    int c = 0;

    if (parsed_p == NULL)
    {
        return EXIT_FAILURE;
    }

    /* initialize default arguments */
    parsed_p->help = FALSE;
    parsed_p->quiet = FALSE;
    parsed_p->xsums = FALSE;
    parsed_p->simd = FALSE;
    parsed_p->k = 3;
    parsed_p->m = 10;
    parsed_p->runiters = 10;
    parsed_p->runreps = 64;
    parsed_p->data_sz = 1000000;
    parsed_p->static_pattern = NULL;

    while ((--argc > 0) && ((*++argv)[0] == '-'))
    {
        while ((c = *++argv[0]))
        {
            switch (c)
            {
                case 'k':
                {
                    if (--argc > 0)
                    {
                        long val = atol(argv[1]);
                        if ((1 <= val) && (val <= 256))
                        {
                            parsed_p->k = val;
                        }
                        else
                        {
                            fprintf(stderr, "Invalid value of k passed: %s\n", argv[1]);
                            argc = 0;
                        }

                        argv++;
                        *argv+= strlen(*argv) - 1;
                    }
                    break;
                }
                case 'm':
                {
                    if (--argc > 0)
                    {
                        int val = atoi(argv[1]);
                        if ((1 <= val) && (val <= 256))
                        {
                            parsed_p->m = val;
                        }
                        else
                        {
                            fprintf(stderr, "Invalid value of m passed: %s\n", argv[1]);
                            argc = 0;
                        }

                        argv++;
                        *argv+= strlen(*argv) - 1;
                    }
                    break;
                }
                case 'i':
                {
                    if (--argc > 0)
                    {
                        long val = atol(argv[1]);
                        if (val >= 1)
                        {
                            parsed_p->runiters = val;
                        }
                        else
                        {
                            fprintf(stderr, "Invalid number of iterations passed: %s\n", argv[1]);
                            argc = 0;
                        }

                        argv++;
                        *argv+= strlen(*argv) - 1;
                    }
                    break;
                }
                case 'r':
                {
                    if (--argc > 0)
                    {
                        long val = atol(argv[1]);
                        if (val >= 1)
                        {
                            parsed_p->runreps = val;
                        }
                        else
                        {
                            fprintf(stderr, "Invalid number of repetitions passed: %s\n", argv[1]);
                            argc = 0;
                        }

                        argv++;
                        *argv+= strlen(*argv) - 1;
                    }
                    break;
                }
                case 's':
                {
                    if (--argc > 0)
                    {
                        long val = atol(argv[1]);
                        if (val >= 1)
                        {
                            parsed_p->data_sz = val;
                        }
                        else
                        {
                            fprintf(stderr, "Invalid size of data to benchmark: %s\n", argv[1]);
                            argc = 0;
                        }

                        argv++;
                        *argv+= strlen(*argv) - 1;
                    }
                    break;
                }
                case 'p':
                {
                    if (--argc > 0)
                    {
                        /* no strdup with c99 flag */
                        size_t const ssz = strlen(argv[1]);
                        parsed_p->static_pattern = malloc(ssz + 1);
                        strcpy(parsed_p->static_pattern, argv[1]);

                        argv++;
                        *argv+= strlen(*argv) - 1;
                    }
                    break;
                }
                case 'x':
                    parsed_p->xsums = TRUE;
                    break;
                case 'q':
                    parsed_p->quiet = TRUE;
                    break;
                case 'A':
                    parsed_p->simd = TRUE;
                    break;
                case 'h':
                    show_help = TRUE;
                    parsed_p->help = show_help;
                    break;

                default:
                {
                    fprintf(stderr, "Illegal option [%c]\n", (char)c);
                    argc = 0;
                    break;
                }
            }
        }
    }

    if ((show_help == TRUE) || (argc != 0) || (parsed_p->k > parsed_p->m))
    {
        if (parsed_p->k > parsed_p->m)
        {
            fprintf(stderr, "Value of k cannot be greater than m\n");
        }

        fprintf(stderr,
            "\n"
            "Usage: bench_zfex [options]\n\n"
            "Options:\n"
            "         -m UINT64 the total number of blocks produced, 1 <= m <= 256\n"
            "         -k UINT64 how many of blocks produced are necessary to reconstruct the original data, 1 <= k <= m\n"
            "         -i UINT64 number of iterations\n"
            "         -r UINT64 number of repetitions within each iteration\n"
            "         -s UINT64 size of data to benchmark\n"
            "         -p STRING static pattern to concatenate as an input\n"
            "         -A        invoke SIMD-friendly API\n"
            "         -x        report calculated checksums\n"
            "         -q        quiet mode, do not print anything to the console\n"
            "         -h        show help\n");

        return show_help == TRUE ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

gf *random_fill(
    gf *data_p,
    size_t data_sz,
    size_t tile_sz,
    size_t block_sz)
{
    if (data_p == NULL)
    {
        return data_p;
    }

    srand(time(0));

    /* nblocks may be smaller than k if block_sz < k.
     * In such case, some blocks at the end will be empty */
    size_t const nblocks = (data_sz + block_sz - 1) / block_sz;
    size_t pix = 0;
    size_t bix = 0;
    size_t ix = 0;

    for (bix = 0; bix < nblocks; ++bix)
    {
        for (ix = 0; (ix < block_sz) && (pix < data_sz); ++ix, ++pix)
        {
            data_p[bix * tile_sz + ix] = rand();
        }
    }

    return data_p;
}

gf *pattern_fill(
    gf *data_p,
    size_t data_sz,
    size_t tile_sz,
    size_t block_sz,
    void *patt_p)
{
    if ((data_p == NULL) || (patt_p == NULL))
    {
        return data_p;
    }

    gf const *str_p = (gf const *)patt_p;
    size_t const str_sz = strlen(patt_p);

    /* nblocks may be smaller than k if block_sz < k.
     * In such case, some blocks at the end will be empty */
    size_t const nblocks = (data_sz + block_sz - 1) / block_sz;
    size_t pix = 0;
    size_t bix = 0;
    size_t ix = 0;

    for (bix = 0; bix < nblocks; ++bix)
    {
        for (ix = 0; (ix < block_sz) && (pix < data_sz); ++ix, ++pix)
        {
            data_p[bix * tile_sz + ix] = str_p[pix % str_sz];
        }
    }

    return data_p;
}

typedef struct checksum_state_s
{
    uint32_t c0;
    uint32_t c1;
} checksum_state_t;

uint16_t checksum(uint8_t const *data, size_t len, checksum_state_t *state_p)
{
    uint32_t c0 = 0;
    uint32_t c1 = 0;

    /* if no external state is passed then use local state */
    uint32_t *c0_p = state_p ? &state_p->c0 : &c0;
    uint32_t *c1_p = state_p ? &state_p->c1 : &c1;

    while (len > 0)
    {
        size_t blocklen = len;

        if (blocklen > 5002)
        {
            blocklen = 5002;
        }
        len -= blocklen;
        do
        {
            *c0_p = *c0_p + *data++;
            *c1_p = *c1_p + *c0_p;
        } while (--blocklen);
        *c0_p = *c0_p % 255;
        *c1_p = *c1_p % 255;
    }

    return ((*c1_p << 8) | *c0_p);
}


double now()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);

    return (double)tv.tv_sec + tv.tv_usec / 1.0e6;
}

int double_cmp(void const *a_p, void const *b_p)
{
    double const lhs = *(double const *)a_p;
    double const rhs = *(double const *)b_p;

    return
        (lhs == rhs) ? 0 :
        ((lhs < rhs) ? -1 : 1);
}

int main(int argc, char **argv)
{
    parsed_args_t parsed_args;

    int const parsed_status = parse_args(argc, argv, &parsed_args);

    if (parsed_status != EXIT_SUCCESS)
    {
        return parsed_status;
    }

    if (parsed_args.help == TRUE)
    {
        return EXIT_SUCCESS;
    }

    size_t const UNITS_PER_SECOND = 1000000000;
    size_t const DATA_SZ = parsed_args.data_sz;
    size_t const fec_sz = (DATA_SZ + parsed_args.k - 1) / parsed_args.k;
    /* fec_simd_aligned_sz is fec_sz rounded up to ZFEX_SIMD_ALIGNMENT boundary */
    size_t const fec_simd_aligned_sz = parsed_args.simd ?
        (fec_sz + ZFEX_SIMD_ALIGNMENT - 1) & ~(ZFEX_SIMD_ALIGNMENT - 1) : fec_sz;

    if (parsed_args.quiet == FALSE)
    {
        printf("Built with:\n  ZFEX_STRIDE=%d\n  UNROLL=%d\n", ZFEX_STRIDE, UNROLL);
        printf("  ZFEX_SIMD_ALIGNMENT=%d\n", ZFEX_SIMD_ALIGNMENT);
        printf("  ZFEX_INTEL_SSSE3_FEATURE=%d\n", ZFEX_INTEL_SSSE3_FEATURE);
        printf("  ZFEX_ARM_NEON_FEATURE=%d\n", ZFEX_ARM_NEON_FEATURE);
        printf("  ZFEX_INLINE_ADDMUL_FEATURE=%d\n", ZFEX_INLINE_ADDMUL_FEATURE);
        printf("  ZFEX_INLINE_ADDMUL_SIMD_FEATURE=%d\n", ZFEX_INLINE_ADDMUL_SIMD_FEATURE);

        printf("Measuring encoding of data with K=%hu, M=%hu, reporting results in nanoseconds per byte after encoding %zu bytes %u times in a row...\n", parsed_args.k, parsed_args.m, DATA_SZ, parsed_args.runreps);
    }

    /*
     * I allocate chunk of memory that will be already padded
     * to a multiple of fec_sz. It will store both input and
     * output blocks, a total of m blocks.
     * Allocated chunk might not be aligned on ZFEX_SIMD_ALIGNMENT,
     * so I need to compensate for this by allocating extra ZFEX_SIMD_ALIGNMENT - 1 bytes
     * and then rounding the address up to the ZFEX_SIMD_ALIGNMENT boundary.
     */
    gf *unaligned_data_p = calloc(fec_simd_aligned_sz * parsed_args.m + (ZFEX_SIMD_ALIGNMENT - 1), 1);
    gf *data_p = (gf *)(((uintptr_t)unaligned_data_p + ZFEX_SIMD_ALIGNMENT - 1) & ~(ZFEX_SIMD_ALIGNMENT - 1));

    fec_t *fec_p = fec_new(parsed_args.k, parsed_args.m);

    size_t const num_block_nums = parsed_args.m - parsed_args.k;
    /* allocate placeholder for indices of blocks
     * that will be requested to be produced by the encoder */
    unsigned int *block_nums_p = calloc(num_block_nums, sizeof (unsigned int));
    /* allocate placeholder for pointers to k input blocks */
    gf const **incblocks_pp = calloc(parsed_args.k, sizeof (gf *));
    /* allocate placeholder for pointers to (m - k) output blocks */
    gf **fecs_pp = calloc(num_block_nums, sizeof (gf *));

    size_t ix = 0;

    /* assign pointers to output blocks */
    for (ix = 0; ix < num_block_nums; ++ix)
    {
        /* (m - k) output blocks are located after k input blocks */
        fecs_pp[ix] = &data_p[fec_simd_aligned_sz * (ix + parsed_args.k)];
    }

    for (ix = 0; ix < parsed_args.k; ++ix)
    {
        /* pointers to consecutive chunks within padded input data */
        incblocks_pp[ix] = &data_p[ix * fec_simd_aligned_sz];
    }

    for (ix = 0; ix < num_block_nums; ++ix)
    {
        block_nums_p[ix] = parsed_args.k + ix;
    }

    size_t rit = 0;
    size_t it = 0;
    double *tls_p = calloc(parsed_args.runiters, sizeof (double));

    if (parsed_args.static_pattern != NULL)
    {
        pattern_fill(data_p,
            /* data_sz= */ DATA_SZ,
            /* tile_sz= */ fec_simd_aligned_sz,
            /* block_sz= */ fec_sz,
            parsed_args.static_pattern);

        if ((parsed_args.quiet == FALSE) && (parsed_args.xsums == TRUE))
        {
            checksum_state_t xsum_state = {0};
            uint16_t xsum = 0;

            /* nblocks may be smaller than k if block_sz < k.
             * In such case, some blocks at the end are empty */
            size_t const nblocks = (DATA_SZ + fec_sz - 1) / fec_sz;

            /* Accumulate checksum block-by-block */
            for (ix = 0; ix < nblocks; ++ix)
            {
                size_t const remaining_bytes = DATA_SZ - ix * fec_sz;

                xsum = checksum(data_p + ix * fec_simd_aligned_sz,
                     /* MIN(fec_sz, remaining_bytes) */ fec_sz < remaining_bytes ? fec_sz : remaining_bytes,
                     &xsum_state);
            }

            printf("Input xsum: %04X\n", xsum);
        }
    }

    for (it = 0; it < parsed_args.runiters; ++it)
    {
        if (parsed_args.static_pattern == NULL)
        {
            random_fill(data_p,
            /* data_sz= */ DATA_SZ,
            /* tile_sz= */ fec_simd_aligned_sz,
            /* block_sz= */ fec_sz);
        }

        double const t0 = now();

        for (rit = 0; rit < parsed_args.runreps; ++rit)
        {
            if (parsed_args.simd == TRUE)
            {
                fec_encode_simd(fec_p, incblocks_pp, fecs_pp, block_nums_p, num_block_nums, fec_sz);
            }
            else
            {
                fec_encode(fec_p, incblocks_pp, fecs_pp, block_nums_p, num_block_nums, fec_sz);
            }

            if ((parsed_args.static_pattern != NULL) &&
                (parsed_args.quiet == FALSE) && (parsed_args.xsums == TRUE))
            {
                for (ix = 0; ix < num_block_nums; ++ix)
                {
                    printf("fec[%zu] xsum %04X\n", ix, checksum(fecs_pp[ix], fec_sz, NULL));
                }
            }
        }

        tls_p[it] = (UNITS_PER_SECOND / DATA_SZ) * (now() - t0) / parsed_args.runreps;
    }

    double sumtls = 0;
    for (ix = 0; ix < parsed_args.runiters; ++ix)
    {
        sumtls += tls_p[ix];
    }
    double const mean = sumtls / parsed_args.runiters;
    qsort(tls_p, parsed_args.runiters, sizeof (*tls_p), double_cmp);
    double const best = tls_p[0];
    double const worst = tls_p[parsed_args.runiters - 1];
    unsigned int const mth = parsed_args.runiters / 4;
    double const mthbest = mth > 0 ? tls_p[mth - 1] : tls_p[0];
    double const mthworst = mth > 0 ? tls_p[parsed_args.runiters - mth] : tls_p[parsed_args.runiters - 1];

    if (parsed_args.quiet == FALSE)
    {
        printf(
            "best: %8.03e,"
            " %3dth-best: %8.03e,"
            " mean: %8.03e,"
            " %3dth-worst: %8.03e,"
            " worst: %8.03e (of %6d)"
            "\n",
            best,
            mth + 1, mthbest,
            mean,
            mth + 1, mthworst,
            worst,
            parsed_args.runiters
        );

        printf("and now represented in MB/s...\n\n");
        printf("best:  %4.3f MB/sec\n", 1e3 / best);
        printf("mean:  %4.3f MB/sec\n", 1e3 / mean);
        printf("worst: %4.3f MB/sec\n", 1e3 / worst);
    }

    free(parsed_args.static_pattern);
    free(tls_p);
    free(block_nums_p);
    free(incblocks_pp);
    free(fecs_pp);
    free(unaligned_data_p);
    fec_free(fec_p);

    return EXIT_SUCCESS;
}
