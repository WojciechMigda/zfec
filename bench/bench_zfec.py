from zfec import easyfec, Encoder, filefec

import os, sys

from pyutil import benchutil

K=3
M=10

d = ""
easyfecenc = None
def _make_new_rand_data(size, k, m):
    global d, easyfecenc, K, M
    K = k
    M = m
    d = os.urandom(size)
    easyfecenc = easyfec.Encoder(k, m)

def _encode_data_easyfec(N):
    easyfecenc.encode(d)

def bench(k, m):
    SIZE = 10**6
    MAXREPS = 64
    # for f in [_encode_file_stringy_easyfec, _encode_file_stringy, _encode_file, _encode_file_not_really,]:
    # for f in [_encode_file,]:
    # for f in [_encode_file_not_really, _encode_file_not_really_and_hash, _encode_file, _encode_file_and_hash,]:
    # for f in [_encode_data_not_really, _encode_data_easyfec, _encode_data_fec,]:
    print "measuring encoding of data with K=%d, M=%d, reporting results in nanoseconds per byte after encoding %d bytes %d times in a row..." % (k, m, SIZE, MAXREPS)
    # for f in [_encode_data_fec, _encode_data_not_really]:
    for f in [_encode_data_easyfec]:
        def _init_func(size):
            return _make_new_rand_data(size, k, m)
        for BSIZE in [SIZE]:
            results = benchutil.rep_bench(f, n=BSIZE, initfunc=_init_func, runreps=MAXREPS, UNITS_PER_SECOND=1000000000)
            print "and now represented in MB/s..."
            print
            best = results['best']
            mean = results['mean']
            worst = results['worst']
            print "best:  % 4.3f MB/sec" % (10**3 / best)
            print "mean:  % 4.3f MB/sec" % (10**3 / mean)
            print "worst: % 4.3f MB/sec" % (10**3 / worst)

k = K
m = M
for arg in sys.argv:
    if arg.startswith('--k='):
        k = int(arg[len('--k='):])
    if arg.startswith('--m='):
        m = int(arg[len('--m='):])

bench(k, m)
