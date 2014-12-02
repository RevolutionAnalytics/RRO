#!/bin/bash
mkdir rpmbuild/SOURCES
cp ../R-3.1.2.tar.gz rpmbuild/SOURCES
cp ../packages/RevoBase.tar.gz rpmbuild
HOME=`pwd`
export HOME
cd rpmbuild/SOURCES
tar xzf R-3.1.2.tar.gz
mv R-3.1.2 RRO-8.0.1-3.1.2
tar czf RRO-8.0.1-3.1.2.tar.gz RRO-8.0.1-3.1.2
rm -rf R-3.1.2.tar.gz RRO-8.0.1-3.1.2
cd ../
rpmbuild -ba SPECS/R.spec
cd RPMS/x86_64
alien --scripts --to-deb RRO-8.0.1-3.1.2-1.x86_64.rpm
cp $HOME/install.sh .
mv rro-8.0.1_3.1.2-2_amd64.deb RRO_3.1.2-1_amd64.deb
