``bench_zfec`` benchmark tool
=============================

``bench_zfec`` is a ``zfec`` benchmark tool written in C. It makes it easier to debug
``zfec`` code and profile it. On top of that it provides few more functionalities compared
to ``bench_zfec.py``.

Usage
-----

::

  Usage: bench_zfec [options]

  Options:
           -m UINT64 the total number of blocks produced, 1 <= m <= 256
           -k UINT64 how many of blocks produced are necessary to reconstruct the original data, 1 <= k <= m
           -i UINT64 number of iterations
           -r UINT64 number of repetitions within each iteration
           -s UINT64 size of data to benchmark
           -p STRING static pattern to concatenate as an input
           -x        report calculated checksums
           -q        quiet mode, do not print anything to the console
           -h        show help

Options `k` and `m` allow to specify the two main parameters of ``zfec`` algorithm. When they are not provided then default values of 3 and 10 are assigned, respectively.

Benchmark is run by repeatingly invoking ``zfec`` algorithm in `i` iterations, with each iteration consisting of `r` repetitions. For each iteration a new random input is generated (but see option ``-p``). Default values of `i` and `r` equal 10 and 64.

Size of input to ``zfec`` is controlled with parameter `s`. Default value of `s` is 1'000'000.

One can switch from random generation of input to having a static pattern applied. This is done with parameter `p`, which accepts a string literal. This literal will be used to repetitively fill input data until desired size is reached.

``bench_zfec`` prints some output to the console. This can be supressed by passing `q` flag.

In addition to default console output one can tell ``bench_zfec`` to display checksums of input and blocks produced by ``zfec`` algorithm. This can be useful to test validity of the algorithm between different implementations. To enable this functionality pass the `x` flag.

Finally, one can request displaying of usage help message, like the one above. This is simply achieved with `h` flag.

Building
--------

To build ``bench_zfec`` simply execute ``make`` pointing it to ``Makefile`` which resides in the same folder as ``bench_zfec.c`` file and this README. ``CC`` and ``CFLAGS`` environment variables apply.

Default value of compile-time parameters ``STRIDE`` and ``UNROLL`` can be overriden by executing:

::

  make STRIDE=<new value> UNROLL=<new value>
