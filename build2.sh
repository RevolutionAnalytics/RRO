#!/bin/bash
ldconfig
export R_SHELL=/bin/bash

export SYSTEM_LIB_PATH=/usr/lib64
export GCC_PATH=/opt/toolchains/gcc/4.4.7
export GCC_LIB_PATH=${GCC_PATH}/lib64

export PATH=${GCC_PATH}/bin:${PATH}
export LD_LIBRARY_PATH=${GCC_LIB_PATH}


cat /etc/issue

pushd /io

rm -rf build-output
rm -rf R-src-mod

mkdir build-output
cp -r R-src R-src-mod
pushd R-src-mod

patch -p1 -i ../RRO-src/patches/relocatable_r.patch

./configure --prefix=/io/build-output \
            --enable-R-shlib --with-tcltk --with-cairo --with-libpng \
            --with-libtiff --with-x=yes --with-lapack \
            --enable-BLAS-shlib LIBR="-lpthread" --enable-memory-profiling \
            --x-includes=/usr/X11R6/include --x-libraries=/usr/X11R6/lib64

make -j7
make install
popd

pushd build-output

#Copy shared libraries that won't be present on all systems
mkdir lib64/R/deps
cp ${GCC_LIB_PATH}/libstdc++.so.6 lib64/R/deps/
cp ${GCC_LIB_PATH}/libgfortran.so.3 lib64/R/deps/
cp ${GCC_LIB_PATH}/libgomp.so.1 lib64/R/deps/
cp ${SYSTEM_LIB_PATH}/libreadline.so.4 lib64/R/deps/

cp ${SYSTEM_LIB_PATH}/libicuuc.so.36 lib64/R/deps/
cp ${SYSTEM_LIB_PATH}/libicudata.so.36 lib64/R/deps/
cp ${SYSTEM_LIB_PATH}/libicudata.so.36 lib64/R/lib/
cp ${SYSTEM_LIB_PATH}/libicui18n.so.36 lib64/R/deps/

cp ${SYSTEM_LIB_PATH}/libtiff.so.3 lib64/R/deps/
cp ${SYSTEM_LIB_PATH}/libjpeg.so.62 lib64/R/deps/

patchelf --set-rpath '$ORIGIN/../deps' lib64/R/modules/R_X11.so
patchelf --set-rpath '$ORIGIN/../deps' lib64/R/modules/R_de.so
patchelf --set-rpath '$ORIGIN/../deps' lib64/R/modules/internet.so
patchelf --set-rpath '$ORIGIN/../deps' lib64/R/modules/lapack.so
patchelf --set-rpath '$ORIGIN/../deps' lib64/R/lib/libR.so
patchelf --set-rpath '$ORIGIN/../deps' lib64/R/lib/libRblas.so
patchelf --set-rpath '$ORIGIN/../deps' lib64/R/lib/libRlapack.so
patchelf --set-rpath '$ORIGIN/../../deps' 'lib64/R/bin/exec/R'