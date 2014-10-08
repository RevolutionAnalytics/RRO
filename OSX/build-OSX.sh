#!/bin/bash
uname -a
pwd
export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
cd OSX
tar xzf NcFTP.tar.gz
sudo installer -package NcFTP.pkg -target /
mkdir mkl
cd mkl
ncftp -u ftpuser -p revo-ftp 23.253.35.131 << FOO1
cd lib
mget *.dylib
quit
FOO1
cd ../
tar xzf ../RRO-3.1.1.tar.gz
cp Makefile.fw RRO-3.1.1
brew install cairo
brew install jpeg
curl -O http://r.research.att.com/libs/gfortran-4.8.2-darwin13.tar.bz2
bzip2 -d gfortran-4.8.2-darwin13.tar.bz2
cd /
sudo tar xf /Users/travis/build/RevolutionAnalytics/RRO/OSX/gfortran-4.8.2-darwin13.tar
cd /Users/travis/build/RevolutionAnalytics/RRO/OSX
mkdir rd64
cd rd64
export MKLROOT="/Users/travis/build/RevolutionAnalytics/RRO/OSX/mkl"
export MKL=" -L${MKLROOT}/lib ${MKLROOT}/lib/libmkl_blas95_ilp64.a ${MKLROOT}/lib/libmkl_lapack95_ilp64.a -lmkl_intel_ilp64 -lmkl_intel_thread -lmkl_core -liomp5 -lpthread -lm -lmkl_gf_ilp64"
../RRO-3.1.1/configure 'CC=clang' 'CXX=clang++' 'OBJC=clang' 'F77=gfortran-4.8' 'FC=gfortran-4.8' 'CFLAGS=-Wall -mtune=core2 -g -O2' 'CXXFLAGS=-Wall -mtune=core2 -g -O2' 'OBJCFLAGS=-Wall -mtune=core2 -g -O2' 'FCFLAGS=-Wall -g -O2' 'F77FLAGS=-Wall -g -O2' '--with-blas="${MKL}"' '--with-lapack' '--with-system-zlib' '--enable-memory-profiling' 'CPPFLAGS=-I/usr/local/include -I/usr/local/include/freetype2 -I/opt/X11/include' '--x-libraries=/opt/X11/lib' '--with-libtiff=no'
make
bin/R CMD INSTALL ../../packages/Revobase_OSX_7.3.0.tgz
cp /usr/local/lib/libquadmath.0.dylib lib
cp /usr/local/lib/libgfortran.3.dylib lib
cp /usr/local/lib/libgcc_s_x86_64.1.dylib lib
cp /usr/local/lib/libgcc_s.1.dylib lib
cp /usr/local/opt/readline/lib/libreadline.6.3.dylib lib
cp ../mkl/*.dylib lib
sudo make install
sudo ln -s /Library/Frameworks/R.framework/Libraries/libreadline.6.3.dylib /Library/Frameworks/R.framework/Libraries/libreadline.dylib
sudo cp /Users/travis/build/RevolutionAnalytics/RRO/packages/Rprofile.site /Library/Frameworks/R.framework/Resources/etc
cd /Users/travis/build/RevolutionAnalytics/RRO/OSX
## OS X GUI
tar xzf Mac-GUI-1.65.tar.gz
cd Mac-GUI-1.65
xcodebuild -target R -configuration SnowLeopard64
cd ../
sudo cp -a Mac-GUI-1.65/build/Release/R.app /Applications
ls -l /Applications
#pkgbuild --identifier com.R.pkg.app --scripts Scripts --install-location / --root ./R RRO-3.1.1.pkg
#curl --ftp-create-dirs -T RRO-3.1.1.pkg -u ftpuser:revo-ftp ftp://162.242.172.183
## make package
curl -O http://s.sudre.free.fr/Software/files/Packages.dmg
sudo hdiutil mount Packages.dmg
cd /Volumes/Packages/packages
sudo installer -package Packages.pkg -target /
cd /Users/travis/build/RevolutionAnalytics/RRO/OSX/project
/usr/local/bin/packagesbuild RevolutionBasic.pkgproj
cp ./build/RevolutionBasic.pkg RRO-3.1.1.pkg 
ncftp -u ftpuser -p revo-ftp 23.253.35.131 << FOO/project
rm RRO-3.1.1.pkg
put RRO-3.1.1.pkg
quit
FOO
