mkdir c:\tmp
set tmpdir=c:/tmp
tar -xzf ../R-3.1.2.tar.gz
REM cp -rp c:/R/Tcl R-3.1.2
REM sed -e "s/Continue/Next/" ..\files\intro.txt > intro.txt
REM cd R-3.1.2/src/gnuwin32/installer
REM cp ../../../../clarkSmall.bmp .
REM cp ../../../../Makefile .
REM cp ../../../../header1.iss .
REM cp ../../../../../packages/Revobase_7.3.0.zip .
REM cd ../
REM cp ../../../../files/Rprofile.site fixed/etc
REM cp -rp C:/opt/bitmaps/* bitmap
 
REM make 32-bit
REM cp C:/opt/Intel_MKL/Win/32/*.dll ../../bin/i386

REM cd ../../../
mkdir R64
cd R64
tar -xzf ../../R-3.1.2.tar.gz
cp -rp c:/R64/Tcl R-3.1.2
cp ../checkpoint.R R-3.1.2/etc
cp ../../README-legal.txt  R-3.1.2/etc
cp ../../README.txt  R-3.1.2/etc
cp ../../COPYING R-3.1.2/etc 
cp ../REV_14419_Clark_2C.ico R-3.1.2/etc
cd R-3.1.2/src/gnuwin32/installer
cp ../../../../../clarkSmall.bmp .
cp ../../../../../Makefile .
cp ../../../../../header1.iss .
cp ../../../../../reg3264.iss .
cp ../../../../../JRins.R .
cp ../../../../../intro.txt .
cp ../../../../../../COPYING .
cp ../../../../../../packages/Revobase_7.3.0.zip .
cd ../
cp ../../../../../files/Rprofile.site fixed/etc
cp ../../../../MkRules_64.local MkRules.local
cp -rp C:/opt/bitmaps/* bitmap
make distribution
pwd
cp C:/opt/Intel_MKL/Win/64/*.dll ../../bin/x64
..\..\bin\R CMD INSTALL ../../../../../packages/RevoBase_7.3.0.zip
make rinstaller
cd installer
cp R-3.1.2-win.exe RRO-8.0.1-Beta-win.exe
cp RRO-8.0.1-Beta-win.exe ../../../../../../
cd
