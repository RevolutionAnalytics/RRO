#!/bin/bash

uname -a
## clean up previous installs
sudo rm -rf /Library/Frameworks/R.framework
sudo rm -rf /Library/Frameworks/RRO.framework
sudo rm -rf /Applications/Revo*.app
cd ../../

BUILD_MATH_LIBRARIES=1
pwd
PWDD=`pwd`
BUILD_DIR=$PWDD
export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
cp COPYING RRO-src/OSX/project
cp README.txt RRO-src/OSX/project
cp RRO-src/files/common/intro.txt RRO-src/OSX/project

if [ $BUILD_MATH_LIBRARIES -eq 1 ] ; then
cd $BUILD_DIR/RRO-src/OSX
rm -rf rd64_LIBS
cp -a ../../R-src R-3.2.2
cp Makefile.fw R-3.2.2
mkdir rd64_LIBS
cd rd64_LIBS
../R-3.2.2/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--x-includes=/opt/X11/include/' '--with-libtiff=yes' 'LDFLAGS=-L/opt/X11/lib -L/usr/local/lib /usr/local/lib/libcairo.a /usr/local/lib/libpixman-1.a /usr/local/lib/libfreetype.a /usr/local/lib/libfontconfig.a -lxml2 /usr/local/lib/libreadline.a'
mkdir lib
make -j8
ls -l lib
cp /usr/local/gfortran/lib/libquadmath.0.dylib lib
cp /usr/local/gfortran/lib/libgfortran.3.dylib lib
cp /usr/local/gfortran/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/gfortran/lib/libgcc_s.1.dylib lib
fi
### End of BUILD_MATH_LIBRARIES


cd $BUILD_DIR/RRO-src/OSX
rm -rf rd64
cp -a ../../R-src R-3.2.2
cp Makefile.fw R-3.2.2
mkdir rd64
cd rd64
../R-3.2.2/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' --with-blas="-framework Accelerate" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--x-includes=/opt/X11/include/' 'LDFLAGS=-L/opt/X11/lib -L/usr/local/lib /usr/local/lib/libcairo.a /usr/local/lib/libpixman-1.a /usr/local/lib/libfreetype.a /usr/local/lib/libfontconfig.a -lxml2 /usr/local/lib/libreadline.a'
##../R-3.2.2/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' --with-blas="-framework Accelerate" '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' "CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include -DPLATFORM_PKGTYPE='\"mac.binary.mavericks\"'" '--x-libraries=/opt/X11/lib' '--x-includes=/opt/X11/include/' '--with-libtiff=yes'
mkdir lib
make -j8
cp $BUILD_DIR/RRO-src/OSX/rd64_LIBS/lib/libRblas.dylib lib
cp $BUILD_DIR/RRO-src/OSX/rd64_LIBS/lib/libRlapack.dylib lib
cp /usr/local/gfortran/lib/libquadmath.0.dylib lib
cp /usr/local/gfortran/lib/libgfortran.3.dylib lib
cp /usr/local/gfortran/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/gfortran/lib/libgcc_s.1.dylib lib
sudo make install
sudo ln -s /Library/Frameworks/R.framework/Libraries/libreadline.6.3.dylib /Library/Frameworks/R.framework/Libraries/libreadline.dylib
sudo cp $BUILD_DIR/RRO-src/files/OSX/Rprofile.site /Library/Frameworks/R.framework/Resources/etc
sudo cp $BUILD_DIR/COPYING /Library/Frameworks/R.framework
sudo cp $BUILD_DIR/README.txt /Library/Frameworks/R.framework
sudo cp $BUILD_DIR/RRO-NEWS.txt /Library/Frameworks/R.framework
sudo cp /Users/builder/R_X11.so /Library/Frameworks/R.framework/Resources/modules
cd $BUILD_DIR/RRO-src/OSX
## add checkpoint package
git clone https://github.com/RevolutionAnalytics/checkpoint.git
cd checkpoint
git checkout 0.3.13
cd ../
tar czf checkpoint.tar.tgz checkpoint
sudo cp checkpoint.tar.tgz /Library/Frameworks/R.framework/Resources/etc

## OS X GUI
cd Mac-GUI
xcodebuild -target "Revolution R Open" 
cd ../
sudo cp -a Mac-GUI/build/Release/Revo*.app /Applications
## make package
cd $BUILD_DIR/RRO-src/OSX/project
/usr/local/bin/packagesbuild RRO.pkgproj
