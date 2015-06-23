mkdir c:\tmp
set tmpdir=c:/tmp
cd ../
set WORKDIR=%CD%
echo %WORKDIR%
rem tar -xzf ../R-3.2.1.tar.gz
cd Windows
cp -a ../R-src R-3.2.1

cp -rp c:/R/Tcl R-3.2.1
sed -e "s/Continue/Next/" ..\files\intro.txt > intro.txt
cd R-3.2.1/src/gnuwin32/installer
cp %WORKDIR%/Windows/clarkSmall.bmp .
cp %WORKDIR%/Windows/Makefile .
cp %WORKDIR%/Windows/header1.iss .
cd ../
cp %WORKDIR%/files/Rprofile.site fixed/etc
cp -rp C:/opt/bitmaps/* bitmap
 
rem make 32-bit

cd %WORKDIR%/Windows
mkdir R64
cd R64
rem tar -xzf ../../R-3.2.1.tar.gz
cp -a %WORKDIR%/R-src R-3.2.1
cp -rp c:/R64/Tcl R-3.2.1
cp %WORKDIR%/Windows/checkpoint.R R-3.2.1/etc
cp %WORKDIR%/README.txt  R-3.2.1/etc
cp %WORKDIR%/COPYING R-3.2.1/etc 
rem cp ../../RRO-NEWS.txt R-3.2.1/etc 
cp %WORKDIR%/Windows/REV_14419_Clark_2C.ico R-3.2.1/etc
cd R-3.2.1/src/gnuwin32/installer
cp %WORKDIR%/Windows/clarkSmall.bmp .
cp %WORKDIR%/Windows/Makefile .
cp %WORKDIR%/Windows/header1.iss .
cp %WORKDIR%/Windows/reg3264.iss .
cp %WORKDIR%/Windows/JRins.R .
cp %WORKDIR%/Windows/intro.txt .
cd ../
cp %WORKDIR%/files/Rprofile.site fixed/etc
cp %WORKDIR%/Windows/MkRules_64.local MkRules.local
cp -rp C:/opt/bitmaps/* bitmap
make distribution
rem ..\..\bin\R CMD INSTALL %WORKDIR%/packages/RevoBase_7.3.0.zip
make rinstaller
cd installer
mv R-devel-win.exe R-3.2.1-win.exe
cp R-3.2.1-win.exe RRO-3.2.1-win.exe
cp RRO-3.2.1-win.exe %WORKDIR%
cd %WORKDIR%
