#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp -a ../R-src rpmbuild/SOURCES/RRO-3.2.1-3.2.1
cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild/SOURCES
tar czf RRO-3.2.1-3.2.1.tar.gz RRO-3.2.1-3.2.1
rm -rf RRO-3.2.1-3.2.1
cd ../
rpmbuild -ba SPECS/R.spec
