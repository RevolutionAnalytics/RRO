#!/bin/bash

pwd
cd ../
PWDD=`pwd`
BUILD_DIR=$PWDD
export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
cp COPYING OSX/project
cp COPYING COPYING.txt
cp README-legal.txt OSX/project
cp README.txt OSX/project
cp RRO-NEWS.txt OSX/project
cp files/intro.txt OSX/project
cd OSX
cp -a /opt/intel/mkl .
### build RRO.framework
rm -rf R-3.1.2
rm -rf rd64-RRO
tar xzf ../R-3.1.2.tar.gz
cp Makefile-RRO.fw R-3.1.2/Makefile.fw
cp Makeconf-RRO.in R-3.1.2/Makeconf.in
mkdir rd64-RRO
cd rd64-RRO
export MKLROOT="$BUILD_DIR/RRO/OSX/mkl"
export MKL=" -L${MKLROOT}/lib ${MKLROOT}/lib/libmkl_blas95_ilp64.a ${MKLROOT}/lib/libmkl_lapack95_ilp64.a -lmkl_rt "
../R-3.1.2/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'F77=gfortran-4.8' 'FC=gfortran-4.8' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' 'FCFLAGS=-Wall -g -O2' 'F77FLAGS=-Wall -g -O2' --with-blas="${MKL}" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--with-libtiff=yes' --disable-openmp
mkdir lib
cp $MKLROOT/lib/libiomp5.dylib lib
cp $MKLROOT/lib/libmkl_avx.dylib lib
cp $MKLROOT/lib/libmkl_core.dylib lib
cp $MKLROOT/lib/libmkl_intel_ilp64.dylib lib
cp $MKLROOT/lib/libmkl_intel_lp64.dylib lib
cp $MKLROOT/lib/libmkl_intel_thread.dylib lib
cp $MKLROOT/lib/libmkl_mc.dylib lib
cp $MKLROOT/lib/libmkl_rt.dylib lib
make
bin/R CMD INSTALL $BUILD_DIR/RRO/packages/Revobase_OSX_7.3.0.tgz
cp /usr/local/lib/libquadmath.0.dylib lib
cp /usr/local/lib/libgfortran.3.dylib lib
cp /usr/local/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/lib/libgcc_s.1.dylib lib
cp /usr/local/opt/readline/lib/libreadline.6.3.dylib lib
sudo make install
sudo ln -s /Library/Frameworks/RRO.framework/Libraries/libreadline.6.3.dylib /Library/Frameworks/RRO.framework/Libraries/libreadline.dylib
sudo cp $BUILD_DIR/RRO/files/Rprofile.site /Library/Frameworks/RRO.framework/Resources/etc
sudo cp $BUILD_DIR/RRO/COPYING /Library/Frameworks/RRO.framework
sudo cp $BUILD_DIR/RRO/README-legal.txt /Library/Frameworks/RRO.framework
sudo cp $BUILD_DIR/RRO/README.txt /Library/Frameworks/RRO.framework
sudo cp $BUILD_DIR/RRO/RRO-NEWS.txt /Library/Frameworks/RRO.framework
## done building RRO.framework

cd $BUILD_DIR/RRO/OSX
rm -rf R-3.1.2
rm -rf rd64
tar xzf ../R-3.1.2.tar.gz
cp Makefile.fw R-3.1.2
# brew install cairo
# brew install jpeg
mkdir rd64
cd rd64
../R-3.1.2/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'F77=gfortran-4.8' 'FC=gfortran-4.8' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' 'FCFLAGS=-Wall -g -O2' 'F77FLAGS=-Wall -g -O2' --with-blas="-framework Accelerate" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--with-libtiff=yes' 
mkdir lib
make
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
rm -rf Mac-GUI-1.65
tar xzf Mac-GUI-1.65.tar.gz
cd Mac-GUI-1.65
xcodebuild -target "Revolution R Open" 
cd ../
sudo cp -a Mac-GUI-1.65/build/Release/Revo*.app /Applications
## make package
cd $BUILD_DIR/RRO/OSX/project
/usr/local/bin/packagesbuild RevolutionBasic.pkgproj
cp ./build/RevolutionBasic.pkg R-3.1.2.pkg 
