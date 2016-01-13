#!/bin/bash

issue=`cat /etc/issue`

echo $NUGET_PASSWORD

if [ ! -f nuget.exe ]; then
    wget http://nuget.org/nuget.exe --no-check-certificate
fi

if [[ $issue == *"SUSE Linux Enterprise Server 10"* ]]
then
    mkdir -p RRO-src/buildFiles/packages/FAKE.4.0.3
    pushd RRO-src/buildFiles/packages/FAKE.4.0.3
    wget https://www.nuget.org/api/v2/package/FAKE/4.0.3 --no-check-certificate
    unzip fake.4.0.3.nupkg
    popd
else
    mono nuget.exe restore RRO-src/buildFiles/RRO_build.sln
fi

pushd RRO-src/buildFiles
xbuild /p:Configuration=Release
mono packages/FAKE.4.0.3/tools/FAKE.exe
popd
