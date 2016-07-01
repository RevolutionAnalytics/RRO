# Microsoft R Open

This is the build system for Microsoft R Open. It starts with the unmodified R-3.2.5 distribution, and incorporates the Microsoft R Open modifications, and then builds executables on various platforms.

## To build Microsoft R Open

### Windows:

```
git clone https://github.com/RevolutionAnalytics/RRO.git rro-win-build
cd rro-win-build/Windows
make.bat
```

### Linux:

Install mono using the instructions on the mono project Web site:
http://www.mono-project.com/docs/getting-started/install/linux/

Once mono is installed:

```
git clone https://github.com/RevolutionAnalytics/RRO.git rro-build
cd rro-build
chmod +x build.sh
./build.sh
```

### OSX:

The OSX build uses Travis CI's build environment (https://travis-ci.com/)

```
git clone https://github.com/RevolutionAnalytics/RRO.git rro-build
cd rro-build/RRO-src/OSX
chmod +x build-OSX.sh
./build-OSX.sh
```


