#!/bin/bash
mkdir rpmbuild/SOURCES
cp ../packages/RevoBase.tar.gz rpmbuild
HOME=`pwd`
export HOME
cd ../
mv R-src RRO-8.0.2-3.1.2
tar czf RRO-8.0.2-3.1.2.tar.gz RRO-8.0.2-3.1.2
cp RRO-8.0.2-3.1.2.tar.gz Ubuntu/rpmbuild/SOURCES
cd Ubuntu/rpmbuild
rpmbuild -ba SPECS/R.spec
cd RPMS/x86_64
alien --scripts --to-deb RRO-8.0.2-3.1.2-1.x86_64.rpm
cp $HOME/install.sh .
mv rro-8.0.2_3.1.2-2_amd64.deb RRO_3.1.2-1_amd64.deb
