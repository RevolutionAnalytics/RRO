#!/bin/bash

cd ../
uname -a
pwd
BUILD_DIR=/Users/builder/
export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
cp COPYING OSX/project
cp COPYING COPYING.txt
cp README-legal.txt OSX/project
cp README.txt OSX/project
cp RRO-NEWS.txt OSX/project
cp files/intro.txt OSX/project
cd OSX
tar xzf ../R-3.1.2.tar.gz
cp Makefile.fw R-3.1.2
# brew install cairo
# brew install jpeg
mkdir rd64
cd rd64
### export MKLROOT="$BUILD_DIR/RRO/OSX/mkl"
### export MKL=" -L${MKLROOT}/lib ${MKLROOT}/lib/libmkl_blas95_ilp64.a ${MKLROOT}/lib/libmkl_lapack95_ilp64.a -lmkl_intel -lmkl_core -lmkl_intel_ilp64 -lmkl_intel_thread -lpthread -lm"
### ../R-3.1.2/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'F77=gfortran-4.8' 'FC=gfortran-4.8' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' 'FCFLAGS=-Wall -g -O2' 'F77FLAGS=-Wall -g -O2' --with-blas="${MKL}" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--with-libtiff=no' 
../R-3.1.2/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'F77=gfortran-4.8' 'FC=gfortran-4.8' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' 'FCFLAGS=-Wall -g -O2' 'F77FLAGS=-Wall -g -O2' --with-blas="-framework Accelerate" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--with-libtiff=yes' 
mkdir lib
###cp ../mkl/libiomp5.dylib lib
###cp ../mkl/libmkl_avx.dylib lib
###cp ../mkl/libmkl_core.dylib lib
###cp ../mkl/libmkl_intel_ilp64.dylib lib
###cp ../mkl/libmkl_intel_lp64.dylib lib
###cp ../mkl/libmkl_intel_thread.dylib lib
###cp ../mkl/libmkl_mc.dylib lib
make
### bin/R CMD INSTALL ../../packages/Revobase_OSX_7.3.0.tgz
cp /usr/local/lib/libquadmath.0.dylib lib
cp /usr/local/lib/libgfortran.3.dylib lib
cp /usr/local/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/lib/libgcc_s.1.dylib lib
cp /usr/local/opt/readline/lib/libreadline.6.3.dylib lib
sudo make install
sudo ln -s /Library/Frameworks/R.framework/Libraries/libreadline.6.3.dylib /Library/Frameworks/R.framework/Libraries/libreadline.dylib
sudo cp $BUILD_DIR/RRO/files/Rprofile.site /Library/Frameworks/R.framework/Resources/etc
sudo cp $BUILD_DIR/RRO/COPYING /Library/Frameworks/R.framework
sudo cp $BUILD_DIR/RRO/README-legal.txt /Library/Frameworks/R.framework
sudo cp $BUILD_DIR/RRO/README.txt /Library/Frameworks/R.framework
sudo cp $BUILD_DIR/RRO/RRO-NEWS.txt /Library/Frameworks/R.framework
cd $BUILD_DIR/RRO/OSX
## OS X GUI
tar xzf Mac-GUI-1.65.tar.gz
cd Mac-GUI-1.65
xcodebuild -target "Revolution R Open" 
cd ../
sudo cp -a Mac-GUI-1.65/build/Release/Revo*.app /Applications
## make package
cd $BUILD_DIR/RRO/OSX/project
/usr/local/bin/packagesbuild RevolutionBasic.pkgproj
cp ./build/RevolutionBasic.pkg R-3.1.2.pkg 
