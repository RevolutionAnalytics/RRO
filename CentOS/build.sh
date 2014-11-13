#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp ../R-3.1.2.tar.gz rpmbuild/SOURCES
cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild/SOURCES
tar xzf R-3.1.2.tar.gz
mv R-3.1.2 RRO-3.1.2
cp ../../../files/configure.patch RRO-3.1.2/configure
tar czf RRO-3.1.2.tar.gz RRO-3.1.2
rm R-3.1.2.tar.gz
cd ../
rpmbuild -ba SPECS/R.spec
