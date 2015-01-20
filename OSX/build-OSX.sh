#!/bin/bash

uname -a
## clean up previous installs
sudo rm -rf /Library/Frameworks/R.framework
sudo rm -rf /Library/Frameworks/RRO.framework
sudo rm -rf /Applications/Revo*.app
cd ../

BUILD_RRO_FRAMEWORK=0
pwd
PWDD=`pwd`
BUILD_DIR=$PWDD
export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
cp COPYING OSX/project
cp OSX/README-legal.txt OSX/project
cp OSX/README.txt OSX/project
cp files/intro.txt OSX/project

if [ $BUILD_RRO_FRAMEWORK -eq 1 ] ; then
cd OSX
### build RRO.framework
#rm -rf R-3.1.2
rm -rf rd64-RRO
#tar xzf ../R-3.1.2.tar.gz
cp Makefile-RRO.fw R-src/Makefile.fw
cp Makeconf-RRO.in R-src/Makeconf.in
#mkdir rd64-RRO
cd rd64
#export MKLROOT="/opt/intel/mkl"
#export MKL=" -L${MKLROOT}/lib ${MKLROOT}/lib/libmkl_blas95_ilp64.a ${MKLROOT}/lib/libmkl_lapack95_ilp64.a -lmkl_rt "
../../R-src/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang'  'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' 'FCFLAGS=-Wall -g -O2'  --with-blas="${MKL}" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--x-includes=/opt/X11/include' '--with-libtiff=yes' --disable-openmp
mkdir lib
cp $MKLROOT/lib/libiomp5.dylib lib
cp $MKLROOT/lib/libmkl_avx.dylib lib
cp $MKLROOT/lib/libmkl_avx2.dylib lib
cp $MKLROOT/lib/libmkl_core.dylib lib
cp $MKLROOT/lib/libmkl_intel_ilp64.dylib lib
cp $MKLROOT/lib/libmkl_intel_lp64.dylib lib
cp $MKLROOT/lib/libmkl_intel_thread.dylib lib
cp $MKLROOT/lib/libmkl_mc.dylib lib
cp $MKLROOT/lib/libmkl_rt.dylib lib
make
bin/R CMD INSTALL $BUILD_DIR/packages/Revobase_OSX_7.3.0.tgz
cp /usr/local/lib/libquadmath.0.dylib lib
cp /usr/local/lib/libgfortran.3.dylib lib
cp /usr/local/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/lib/libgcc_s.1.dylib lib
cp /usr/local/opt/readline/lib/libreadline.6.3.dylib lib
sudo make install
sudo ln -s /Library/Frameworks/RRO.framework/Libraries/libreadline.6.3.dylib /Library/Frameworks/RRO.framework/Libraries/libreadline.dylib
sudo cp $BUILD_DIR/files/Rprofile.site /Library/Frameworks/RRO.framework/Resources/etc
sudo cp $BUILD_DIR/COPYING /Library/Frameworks/RRO.framework
sudo cp $BUILD_DIR/README-legal.txt /Library/Frameworks/RRO.framework
sudo cp $BUILD_DIR/README.txt /Library/Frameworks/RRO.framework
sudo cp $BUILD_DIR/RRO-NEWS.txt /Library/Frameworks/RRO.framework
## done building RRO.framework
fi
### End of MKL RRO Framework


cd $BUILD_DIR/OSX
#rm -rf R-3.1.2
rm -rf rd64
#tar xzf ../R-3.1.2.tar.gz
cp Makefile.fw R-src
# brew install cairo
# brew install jpeg
mkdir rd64
cd rd64
../R-src/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' --with-blas="-framework Accelerate" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--x-includes=/opt/X11/include/' '--with-libtiff=yes'
mkdir lib
make
cp /usr/local/lib/libquadmath.0.dylib lib
cp /usr/local/lib/libgfortran.3.dylib lib
cp /usr/local/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/lib/libgcc_s.1.dylib lib
cp /usr/local/opt/readline/lib/libreadline.6.3.dylib lib
sudo make install
sudo ln -s /Library/Frameworks/R.framework/Libraries/libreadline.6.3.dylib /Library/Frameworks/R.framework/Libraries/libreadline.dylib
sudo cp $BUILD_DIR/files/Rprofile.site /Library/Frameworks/R.framework/Resources/etc
sudo cp $BUILD_DIR/COPYING /Library/Frameworks/R.framework
sudo cp $BUILD_DIR/README-legal.txt /Library/Frameworks/R.framework
sudo cp $BUILD_DIR/README.txt /Library/Frameworks/R.framework
sudo cp $BUILD_DIR/RRO-NEWS.txt /Library/Frameworks/R.framework
cd $BUILD_DIR/OSX

## OS X GUI
rm -rf Mac-GUI-1.65
tar xzf Mac-GUI-1.65.tar.gz
cd Mac-GUI-1.65
xcodebuild -target "Revolution R Open" 
cd ../
sudo cp -a Mac-GUI-1.65/build/Release/Revo*.app /Applications
## make package
cd $BUILD_DIR/OSX/project
/usr/local/bin/packagesbuild RRO.pkgproj
