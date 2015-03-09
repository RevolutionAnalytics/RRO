# Revolution R Open

This is the build system for Revolution R Open. It starts with the unmodified R-3.1.3 distribution, and incorporates the Revolution R Open modifications, and then builds executables on various platforms.

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
3. Copy the test bundle `test.tar.gz`, to `lib` directory of R (i.e. `/usr/lib64/RRO-8.0/R-3.1.3/lib`)
4. Untar the test bundle in the `lib` directory of R
5. Run the tests from this github repository: `test/standardRTests.R` and `test/MKL_Benchmarks.R`


## About the Intel MKL


To build Revolution R Open with the Intel Math Kernel Libraries, you will
need the [Intel MKL developer kit.](https://software.intel.com/en-us/intel-mkl)
If you have the MKL developer kit, refer to `build.sh` file for
the appropriate platform to configure the build to use the MKL libraries.
If you do not have the Intel MKL developer kit, Revolution R Open will
build with the standard R BLAS/LAPACK libraries.

We have successfully tested RRO with Intel MKL on Windows and Linux platforms.
We do not recommend building with MKL on Mac, where the default build uses
the [Mac Accelerate Performance Framework](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man7/Accelerate.7.html) and has comparable performance to MKL builds.
