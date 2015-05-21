#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp -pr ../R-src rpmbuild/SOURCES

cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild/SOURCES
mv R-src R-3.2.0
tar czf R-3.2.0.tar.gz R-3.2.0
rm -rf R-src RRO-3.2.0-3.2.0
cd ../
rpmbuild -ba SPECS/R.spec
