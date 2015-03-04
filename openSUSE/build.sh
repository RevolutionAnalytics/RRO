#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp -a ../R-src rpmbuild/SOURCES/RRO-8.0.2-3.1.2
cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild/SOURCES
tar czf RRO-8.0.2-3.1.2.tar.gz RRO-8.0.2-3.1.2
rm -rf RRO-8.0.2-3.1.2
cd ../
rpmbuild -ba SPECS/R.spec
