#!/bin/bash
HOME=`pwd`
export HOME

echo 'Patching R source to be relocatable'
pushd ../R-src
patch -p1 < ../patches/relocatable_r.patch
popd

echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp -pr ../R-src rpmbuild/SOURCES
cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild/SOURCES
mv R-src RRO-8.0.3-3.1.3
tar czf RRO-8.0.3-3.1.3.tar.gz RRO-8.0.3-3.1.3
rm -rf R-src RRO-8.0.3-3.1.3
cd ../
rpmbuild -ba SPECS/R.spec

