#!/bin/bash
mkdir rpmbuild/SOURCES
HOME=`pwd`
export HOME
cd ../
mv R-src RRO-3.2.1-3.2.1
tar czf RRO-3.2.1-3.2.1.tar.gz RRO-3.2.1-3.2.1
cp RRO-3.2.1-3.2.1.tar.gz Ubuntu/rpmbuild/SOURCES
cd Ubuntu/rpmbuild
rpmbuild -ba SPECS/R.spec
cd RPMS/x86_64
alien --scripts --to-deb RRO-3.2.1-3.2.1-1.x86_64.rpm
cp $HOME/install.sh .
mv rro-3.2.1_3.2.1-2_amd64.deb RRO_3.2.1-1_amd64.deb
