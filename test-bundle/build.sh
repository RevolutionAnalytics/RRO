#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp ../R-3.1.2.tar.gz rpmbuild/SOURCES
cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild
rpmbuild -ba SPECS/R.spec
