#include "fec.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>


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
    parsed_p->quiet = FALSE;
    parsed_p->xsums = FALSE;
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
            "Usage: bench_zfec [options]\n\n"
            "Options:\n"
            "         -m UINT64 the total number of blocks produced, 1 <= m <= 256\n"
            "         -k UINT64 how many of blocks produced are necessary to reconstruct the original data, 1 <= k <= m\n"
            "         -i UINT64 number of iterations\n"
            "         -r UINT64 number of repetitions within each iteration\n"
            "         -s UINT64 size of data to benchmark\n"
            "         -p STRING static pattern to concatenate as an input\n"
            "         -x        report calculated checksums\n"
            "         -q        quiet mode, do not print anything to the console\n"
            "         -h        show help\n");

        return show_help == TRUE ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

gf *random_fill(gf *data_p, size_t sz)
{
    if (data_p == NULL)
    {
        return data_p;
    }

    srand(time(0));

    size_t ix = 0;

    for (ix = 0; ix < sz; ++ix)
    {
        data_p[ix] = rand();
    }

    return data_p;
}

gf *pattern_fill(gf *data_p, size_t sz, void *patt_p)
{
    if ((data_p == NULL) || (patt_p == NULL))
    {
        return data_p;
    }

    gf const *str_p = (gf const *)patt_p;
    size_t const str_sz = strlen(patt_p);
    size_t ix = 0;

    for (ix = 0; ix < sz; ++ix)
    {
        data_p[ix] = str_p[ix % str_sz];
    }

    return data_p;
}

uint16_t checksum(const uint8_t *data, size_t len)
{
    uint32_t c0, c1;

    for (c0 = c1 = 0; len > 0; )
    {
        size_t blocklen = len;

        if (blocklen > 5002)
        {
            blocklen = 5002;
        }
        len -= blocklen;
        do
        {
            c0 = c0 + *data++;
            c1 = c1 + c0;
        } while (--blocklen);
        c0 = c0 % 255;
    	c1 = c1 % 255;
    }

    return (c1 << 8 | c0);
}


double now()
{
    return (double)clock() / CLOCKS_PER_SEC;
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

    size_t const UNITS_PER_SECOND = 1000000000;
    size_t const DATA_SZ = parsed_args.data_sz;
    size_t const fec_sz = (DATA_SZ + parsed_args.k - 1) / parsed_args.k;

    if (parsed_args.quiet == FALSE)
    {
        printf("measuring encoding of data with K=%hu, M=%hu, reporting results in nanoseconds per byte after encoding %zu bytes %u times in a row...\n", parsed_args.k, parsed_args.m, DATA_SZ, parsed_args.runreps);
    }

    /*
     * I allocate chunk of memory that will be already padded
     * to a multiple of fec_sz.
     */
    gf *data_p = calloc(fec_sz * parsed_args.k, 1);

    fec_t *fec_p = fec_new(parsed_args.k, parsed_args.m);

    size_t const num_block_nums = parsed_args.m - parsed_args.k;
    unsigned int *block_nums_p = calloc(num_block_nums, sizeof (unsigned int));
    gf const **incblocks_pp = calloc(parsed_args.k, sizeof (gf *));
    gf **fecs_pp = calloc(num_block_nums, sizeof (gf *));

    size_t ix = 0;

    /* allocate placeholders for resulting blocks */
    for (ix = 0; ix < num_block_nums; ++ix)
    {
        fecs_pp[ix] = calloc(fec_sz, 1);
    }

    for (ix = 0; ix < parsed_args.k; ++ix)
    {
        /* pointers to consecutive chunks within padded input data */
        incblocks_pp[ix] = &data_p[ix * fec_sz];
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
        pattern_fill(data_p, DATA_SZ, parsed_args.static_pattern);

        if ((parsed_args.quiet == FALSE) && (parsed_args.xsums == TRUE))
        {
            printf("Input checksum: %04X\n", checksum(data_p, DATA_SZ));
        }
    }

    for (it = 0; it < parsed_args.runiters; ++it)
    {
        if (parsed_args.static_pattern == NULL)
        {
            random_fill(data_p, DATA_SZ);
        }

        double const t0 = now();

        for (rit = 0; rit < parsed_args.runreps; ++rit)
        {
            fec_encode(fec_p, incblocks_pp, fecs_pp, block_nums_p, num_block_nums, fec_sz);

            if ((parsed_args.static_pattern != NULL) &&
                (parsed_args.quiet == FALSE) && (parsed_args.xsums == TRUE))
            {
                for (ix = 0; ix < num_block_nums; ++ix)
                {
                    printf("fec[%zu] %04X\n", ix, checksum(fecs_pp[ix], fec_sz));
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
    {
        for (ix = 0; ix < num_block_nums; ++ix)
        {
            free(fecs_pp[ix]);
        }
        free(fecs_pp);
    }
    fec_free(fec_p);

    return EXIT_SUCCESS;
}

