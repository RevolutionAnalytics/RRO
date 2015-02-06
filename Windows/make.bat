mkdir c:\tmp
set tmpdir=c:/tmp
rem tar -xzf ../R-3.1.2.tar.gz
cp ../R-src R-3.1.2
cp -rp c:/R/Tcl R-3.1.2
sed -e "s/Continue/Next/" ..\files\intro.txt > intro.txt
cd R-3.1.2/src/gnuwin32/installer
cp ../../../../clarkSmall.bmp .
cp ../../../../Makefile .
cp ../../../../header1.iss .
cp ../../../../../packages/Revobase_7.3.0.zip .
cd ../
cp ../../../../files/Rprofile.site fixed/etc
cp -rp C:/opt/bitmaps/* bitmap
 
rem make 32-bit

cd ../../../
mkdir R64
cd R64
rem tar -xzf ../../R-3.1.2.tar.gz
cp ../../R-src R-3.1.2
cp -rp c:/R64/Tcl R-3.1.2
cp ../checkpoint.R R-3.1.2/etc
cp ../../README-legal.txt  R-3.1.2/etc
cp ../../README.txt  R-3.1.2/etc
cp ../../COPYING R-3.1.2/etc 
cp ../../RRO-NEWS.txt R-3.1.2/etc 
cp ../REV_14419_Clark_2C.ico R-3.1.2/etc
cp ../../packages/Revobase_7.3.0.zip R-3.1.2/etc
cd R-3.1.2/src/gnuwin32/installer
cp ../../../../../clarkSmall.bmp .
cp ../../../../../Makefile .
cp ../../../../../header1.iss .
cp ../../../../../reg3264.iss .
cp ../../../../../JRins.R .
cp ../../../../../intro.txt .
cp ../../../../../../README-legal.txt .
cd ../
cp ../../../../../files/Rprofile.site fixed/etc
cp ../../../../MkRules_64.local MkRules.local
cp -rp C:/opt/bitmaps/* bitmap
make distribution
pwd
..\..\bin\R CMD INSTALL ../../../../../packages/RevoBase_7.3.0.zip
make rinstaller
cd installer
cp R-3.1.2-win.exe RRO-8.0.2-Beta-win.exe
cp RRO-8.0.2-Beta-win.exe ../../../../../../
cd
