#!/bin/bash
mkdir rpmbuild/SOURCES
cp ../RRO-3.1.1.tar.gz rpmbuild/SOURCES
cp ../packages/RevoBase.tar.gz rpmbuild
HOME=`pwd`
export HOME
cd rpmbuild
rpmbuild -ba SPECS/R.spec
cd RPMS/x86_64
alien --scripts --to-deb RRO-3.1.1-1.x86_64.rpm
cp $HOME/install.sh .
mv rro_3.1.1-2_amd64.deb RRO_3.1.1-2_amd64.deb
