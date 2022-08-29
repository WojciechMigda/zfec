from setuptools import setup
from setuptools.extension import Extension
from distutils.command.build import build as build_base
from distutils import ccompiler

import sys
import os
import versioneer


class build(build_base):
    def finalize_options(self):
        super().finalize_options()
        from Cython.Build import cythonize
        self.distribution.ext_modules = cythonize(
            self.distribution.ext_modules, language_level=3)

DEBUGMODE = False

if "--debug" in sys.argv:
    DEBUGMODE = True
    sys.argv.remove("--debug")

extra_link_args = []
extra_compile_args = []
define_macros = []
undef_macros = []

for arg in sys.argv:
    if arg.startswith("--stride="):
        stride = int(arg[len("--stride="):])
        define_macros.append(('ZFEX_STRIDE', stride))
        sys.argv.remove(arg)
        break

if not 'msvc' in ccompiler.get_default_compiler():
    extra_compile_args.append("-std=c99")
    if DEBUGMODE:
        extra_compile_args.append("-O0")
        extra_compile_args.append("-g")
        extra_compile_args.append("-Wall")
        extra_compile_args.append("-Wextra")
        extra_link_args.append("-g")
        undef_macros.append('NDEBUG')

extensions = [
    Extension(
        "zfex._zfex",
        [
            os.path.join("zfex", "zfex.c"),
            os.path.join("zfex", "_zfexmodule.c"),
        ],
        include_dirs=["zfex/"],
        extra_link_args=extra_link_args,
        extra_compile_args=extra_compile_args,
        define_macros=define_macros,
        undef_macros=undef_macros,
    ),
    Extension(
        "zfex.__zfex",
        [
            os.path.join("zfex", "__zfex.pyx"),
        ],
        include_dirs=["zfex/"],
        extra_link_args=extra_link_args,
        extra_compile_args=extra_compile_args,
        define_macros=define_macros,
        undef_macros=undef_macros,
    ),
]

# Most of our metadata lives in setup.cfg [metadata]. We put "name" here
# because the setuptools-22.0.5 on slackware can't find it there, which breaks
# packaging. We put "version" here so that Versioneer works correctly.
setup(
    name="zfex",
    version=versioneer.get_version(),
    description="A fast, efficient, portable erasure coding tool",
    long_description=open('README.rst', 'r').read(),
    url="https://github.com/WojciechMigda/zfex",
    setup_requires=["cython>=0.25"],
    extras_require={
        "bench": ["pyutil >= 3.0.0"],
        "test": ["twisted", "pyutil >= 3.0.0"],
    },
    ext_modules=extensions,
    cmdclass=versioneer.get_cmdclass({'build': build}),
)
