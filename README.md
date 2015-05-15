# Revolution R Open

This is the build system for Revolution R Open. It starts with the unmodified R-3.2.0 distribution, and incorporates the Revolution R Open modifications, and then builds executables on various platforms.

## To build Revolution R Open

### Windows:

```
git clone https://github.com/RevolutionAnalytics/RRO.git rro-win-build
cd rro-win-build/Windows
make.bat
```

### CentOS:

```
git clone https://github.com/RevolutionAnalytics/RRO.git rro-centos-build
cd rro-centos-build/CentOS
chmod +x build.sh
./build.sh
```

### Ubuntu:

```
git clone https://github.com/RevolutionAnalytics/RRO.git rro-ubuntu-build
cd rro-ubuntu-build/Ubuntu
chmod +x build.sh
./build.sh
```

### OSX:

The OSX build uses Travis CI's build environment (https://travis-ci.com/)

```
git clone https://github.com/RevolutionAnalytics/RRO.git rro-osx-build
cd rro-osx-build/OSX
chmod +x build-OSX.sh
./build-OSX.sh
```

### OpenSUSE:

```
git clone https://github.com/RevolutionAnalytics/RRO.git rro-openSUSE-build
cd rro-openSUSE-build/openSUSE
chmod +x build.sh
./build.sh
```

## Test Suite

To test the build, perform the following

1. build the test bundle

  ```
  git clone https://github.com/RevolutionAnalytics/RRO.git R-test-bundle
  cd R-test-bundle/test-bundle
  chmod +x build.sh
  ./build.sh
  ```
2. Install RRO on the appropriate platform
3. Copy the test bundle `test.tar.gz`, to `lib` directory of R (i.e. `/usr/lib64/RRO-3.2/R-3.2.0/lib`)
4. Untar the test bundle in the `lib` directory of R
5. Run the tests from this github repository: `test/standardRTests.R` 
