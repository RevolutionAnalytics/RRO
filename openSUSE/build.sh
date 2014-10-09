#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp ../RRO-3.1.1.tar.gz rpmbuild/SOURCES
cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild/SPECS
tar xzf R-3.1.1.tar.gz
mv R-3.1.1 RRO-3.1.1
tar czf RRO-3.1.1.tar.gz RRO-3.1.1
rm R-3.1.1.tar.gz
cd ../
rpmbuild -ba SPECS/R.spec
