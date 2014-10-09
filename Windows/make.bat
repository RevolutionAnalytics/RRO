mkdir c:\tmp
set tmpdir=c:/tmp
tar -xzf ../R-3.1.1.tar.gz
cp -rp c:/R/Tcl R-3.1.1
cd R-3.1.1/src/gnuwin32/installer
cp ../../../../clarkSmall.bmp .
cp ../../../../Makefile .
cp ../../../../header1.iss .
cp ../../../../../packages/Revobase_7.3.0.zip .
cd ../
cp ../../../../packages/Rprofile.site fixed/etc
cp -rp C:/opt/bitmaps/* bitmap
 
make 32-bit
pwd
cp C:/opt/Intel_MKL/Win/32/*.dll ../../bin/i386
cp ../../../../../license.txt ../../

cd ../../../
mkdir R64
cd R64
tar -xzf ../../R-3.1.1.tar.gz
cp -rp c:/R64/Tcl R-3.1.1
cp ../checkpoint.R R-3.1.1/etc
cp ../REV_14419_Clark_2C.ico R-3.1.1/etc
cd R-3.1.1/src/gnuwin32/installer
cp ../../../../../clarkSmall.bmp .
cp ../../../../../Makefile .
cp ../../../../../header1.iss .
cp ../../../../../reg3264.iss .
cp ../../../../../JRins.R .
cp ../../../../../../OSX/project/Intro.txt .
cp ../../../../../../OSX/project/License.txt .
cp ../../../../../../packages/Revobase_7.3.0.zip .
cd ../
pwd
cp ../../../../../packages/Rprofile.site fixed/etc
cp ../../../../MkRules_64.local MkRules.local
cp -rp C:/opt/bitmaps/* bitmap
make distribution
pwd
cp C:/opt/Intel_MKL/Win/64/*.dll ../../bin/x64
cp ../../../../../../license.txt ../../
..\..\bin\R CMD INSTALL ../../../../../packages/RevoBase_7.3.0.zip
make rinstaller
cd installer
cp R-3.1.1-win.exe RRO-8.0-Beta-win.exe
cp RRO-8.0-Beta-win.exe ../../../../../../
cd
