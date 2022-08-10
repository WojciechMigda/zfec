"""
zfex -- fast forward error correction library with Python interface

maintainer web site: U{https://github.com/WojciechMigda/zfex}

zfex web site: U{https://github.com/WojciechMigda/zfex}
"""

from ._version import get_versions
__version__ = get_versions()['version']
del get_versions

from ._zfex import Encoder, Decoder, Error
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
