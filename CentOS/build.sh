#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp ../RRO-3.1.1.tar.gz rpmbuild/SOURCES/RRO-3.1.1.tar.gz
cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild
rpmbuild -ba SPECS/R.spec
