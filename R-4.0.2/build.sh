#!/bin/sh

export CXXFLAGS="-O2 -ggdb3"
export CPPFLAGS="-O2 -ggdb3"
export CFLAGS="-O2 -ggdb3"
export R_KEEP_PKG_SOURCE=yes
export CXX="g++"

./configure --with-blas --with-lapack --without-ICU --with-x        \
            --with-tcltk --without-aqua --with-recommended-packages \
            --without-internal-tzcode --with-included-gettext &&     
make clean &&
make -j