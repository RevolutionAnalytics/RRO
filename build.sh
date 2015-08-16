#!/bin/bash

if [ ! -f nuget.exe ]; then
    wget http://nuget.org/nuget.exe --no-check-certificate
fi
mono nuget.exe restore RRO-src/buildFiles/RRO_build.sln
pushd RRO-src/buildFiles
xbuild /p:Configuration=Release
mono packages/FAKE.4.0.3/tools/FAKE.exe
popd
