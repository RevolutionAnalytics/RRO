mkdir c:\tmp
set tmpdir=c:/tmp
cd ../
set WORKDIR=%CD%
echo %WORKDIR%
rem tar -xzf ../R-3.1.2.tar.gz
cd Windows
cp -a ../R-src R-3.1.2
cp -rp c:/R/Tcl R-3.1.2
sed -e "s/Continue/Next/" ..\files\intro.txt > intro.txt
cd R-3.1.2/src/gnuwin32/installer
cp %WORKDIR%/clarkSmall.bmp .
cp %WORKDIR%/Windows/Makefile .
cp %WORKDIR%/Windows/header1.iss .
cp %WORKDIR%/packages/Revobase_7.3.0.zip .
cd ../
cp %WORKDIR%/files/Rprofile.site fixed/etc
cp -rp C:/opt/bitmaps/* bitmap
 
rem make 32-bit

cd %WORKDIR%/Windows
mkdir R64
cd R64
rem tar -xzf ../../R-3.1.2.tar.gz
cp -a %WORKDIR%/R-src R-3.1.2
cp -rp c:/R64/Tcl R-3.1.2
cp %WORKDIR%/Windows/checkpoint.R R-3.1.2/etc
cp %WORKDIR%/Windows/README-legal.txt  R-3.1.2/etc
cp %WORKDIR%/Windows/README.txt  R-3.1.2/etc
cp %WORKDIR%/COPYING R-3.1.2/etc 
rem cp ../../RRO-NEWS.txt R-3.1.2/etc 
cp %WORKDIR%/Windows/REV_14419_Clark_2C.ico R-3.1.2/etc
cp %WORKDIR%/packages/Revobase_7.3.0.zip R-3.1.2/etc
cd R-3.1.2/src/gnuwin32/installer
cp %WORKDIR%/Windows/clarkSmall.bmp .
cp %WORKDIR%/Windows/Makefile .
cp %WORKDIR%/Windows/header1.iss .
cp %WORKDIR%/Windows/reg3264.iss .
cp %WORKDIR%/Windows/JRins.R .
cp %WORKDIR%/Windows/intro.txt .
cp %WORKDIR%/Windows/README-legal.txt .
cd ../
cp %WORKDIR%/files/Rprofile.site fixed/etc
cp %WORKDIR%/Windows/MkRules_64.local MkRules.local
cp -rp C:/opt/bitmaps/* bitmap
make distribution
pwd
..\..\bin\R CMD INSTALL %WORKDIR%/packages/RevoBase_7.3.0.zip
make rinstaller
cd installer
cp R-3.1.2-win.exe RRO-8.0.2-Beta-win.exe
cp RRO-8.0.2-Beta-win.exe %WORKDIR%
cd %WORKDIR%
