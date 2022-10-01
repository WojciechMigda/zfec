"""
zfex -- fast forward error correction library with Python interface

maintainer web site: U{https://github.com/WojciechMigda/zfex}

zfex web site: U{https://github.com/WojciechMigda/zfex}
"""

from . import _version
__version__ = _version.get_versions()['version']

try:
    __ZFEX_SETUP__  # type: ignore
except NameError:
    __ZFEX_SETUP__ = False

# Only go on if not in setup.py
if not __ZFEX_SETUP__:
    from ._zfex import Encoder, Decoder, Error
    from . import _zfex_test
    from . import easyfec, filefec, cmdline_zfex, cmdline_zunfex

    quiet_pyflakes=[__version__, Error, Encoder, Decoder, cmdline_zunfex, filefec, cmdline_zfex, easyfec]

# zfex -- fast forward error correction library with Python interface
#
# Copyright (C) 2007-2010 Allmydata, Inc.
# Author: Zooko Wilcox-O'Hearn
# mailto:zooko@zooko.com
#
# This file is part of zfex.
#
# See README.rst for licensing information.
