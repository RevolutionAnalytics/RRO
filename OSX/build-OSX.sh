#!/bin/bash

uname -a
## clean up previous installs
sudo rm -rf /Library/Frameworks/R.framework
sudo rm -rf /Library/Frameworks/RRO.framework
sudo rm -rf /Applications/Revo*.app
cd ../

BUILD_MATH_LIBRARIES=1
pwd
PWDD=`pwd`
BUILD_DIR=$PWDD
export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
cp COPYING OSX/project
cp README.txt OSX/project
cp files/intro.txt OSX/project

if [ $BUILD_MATH_LIBRARIES -eq 1 ] ; then
cd $BUILD_DIR/OSX
rm -rf rd64_LIBS
cp -a ../R-src R-3.2.0
cp Makefile.fw R-3.2.0
mkdir rd64_LIBS
cd rd64_LIBS
../R-3.2.0/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--x-includes=/opt/X11/include/' '--with-libtiff=yes'
mkdir lib
make
ls -l lib
cp /usr/local/lib/libquadmath.0.dylib lib
cp /usr/local/lib/libgfortran.3.dylib lib
cp /usr/local/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/lib/libgcc_s.1.dylib lib
cp /usr/local/opt/readline/lib/libreadline.6.3.dylib lib
fi
### End of BUILD_MATH_LIBRARIES


cd $BUILD_DIR/OSX
rm -rf rd64
cp -a ../R-src R-3.2.0
cp Makefile.fw R-3.2.0
mkdir rd64
cd rd64
../R-3.2.0/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' --with-blas="-framework Accelerate" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--x-includes=/opt/X11/include/' '--with-libtiff=yes'
mkdir lib
make
cp $BUILD_DIR/OSX/rd64_LIBS/lib/libRblas.dylib lib
cp $BUILD_DIR/OSX/rd64_LIBS/lib/libRlapack.dylib lib
cp /usr/local/lib/libquadmath.0.dylib lib
cp /usr/local/lib/libgfortran.3.dylib lib
cp /usr/local/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/lib/libgcc_s.1.dylib lib
cp /usr/local/opt/readline/lib/libreadline.6.3.dylib lib
sudo make install
sudo ln -s /Library/Frameworks/R.framework/Libraries/libreadline.6.3.dylib /Library/Frameworks/R.framework/Libraries/libreadline.dylib
sudo cp $BUILD_DIR/files/Rprofile.site /Library/Frameworks/R.framework/Resources/etc
sudo cp $BUILD_DIR/COPYING /Library/Frameworks/R.framework
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
