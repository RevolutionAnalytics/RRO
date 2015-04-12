#!/bin/bash
HOME=`pwd`
export HOME
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,BUILDROOT,SRPMS}
cp -pr ../R-src rpmbuild/SOURCES
cp ../packages/RevoBase.tar.gz rpmbuild
cd rpmbuild/SOURCES
mv R-src RRO-8.0.3-3.1.3
## set --no-save as default
sed -i -e "/done/a\
flag=\`echo $args|awk '{print match($0,\"--save\")}'\`;\n\
if [ $flag -eq 0 ];then\n\
args=\"${args} --no-save\"\n\
fi" RRO-8.0.3-3.1.3/src/scripts/R.sh.in
tar czf RRO-8.0.3-3.1.3.tar.gz RRO-8.0.3-3.1.3
rm -rf R-src RRO-8.0.3-3.1.3
cd ../
rpmbuild -ba SPECS/R.spec

