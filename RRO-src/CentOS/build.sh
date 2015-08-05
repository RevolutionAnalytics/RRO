#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp -pr ../R-src rpmbuild/SOURCES
# cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild/SOURCES
mv R-src RRO-3.2.1-3.2.1
tar czf RRO-3.2.1-3.2.1.tar.gz RRO-3.2.1-3.2.1
rm -rf R-src RRO-3.2.1-3.2.1
cd ../
rpmbuild -ba SPECS/R.spec

