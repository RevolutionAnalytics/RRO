#
# unix-style build of universal R.app
#
# it relies on Xcode to create the bundle and compiles the binary itself
# using Apple's and FSF gcc. it works only on Intel Macs and only if you
# have FSF gcc installed in /usr/local/gcc4.0
# this is a temporary hack until the compiler situation is sorted out.
#
# additional variables that influence the build:
# STYLE  - defined the Xcode configuration to use when building R.app
#          it has no effect on the binary itself - use xxFLAGS as usual
#          for that
# ARCH   - defines the architecture to build for, but doesn't automatically
#          add the -arch parameter aas it's not always supported
#          default is the native architecture
# OBJCC/OBJCFLAGS - special compiler/flags for Obj-C files (default is to
#          use OBJCC=$CC and OBJCFLAGS='')
#
# targets:
# R.$(ARCH)  - binary for $(ARCH)
# R          - universal binary for R (calls make for i386 and ppc)
# R.app      - universal R.app bundle (uses Xcode and R target)
# clean      - as usual
#

NATIVE_ARCH:=$(shell arch)

# get the native architecture (override on the command line)
ifeq ($(ARCH),)
  ARCH:=$(shell arch)
endif

# sources
SRC_H = $(wildcard *.h AMPrefs/*.h PrefPanes/*.h Quartz/*.h REngine/*.h Tools/*.h)
SRC_M = $(wildcard *.m AMPrefs/*.m PrefPanes/*.m Quartz/*.m REngine/*.m Tools/*.m)
SRC_C = $(wildcard Quartz/*.c REngine/*.c) Tools/Authorization.c

SRC = $(SRC_M) $(SRC_C) $(SRC_H)
OBJ_M = $(SRC_M:%.m=%.$(ARCH).o)
OBJ_C = $(SRC_C:%.c=%.$(ARCH).o)
OBJ = $(OBJ_M) $(OBJ_C)

LD=$(CC)

# cc->gcc and add corresponding flags when on ix86
ifeq ($(CC),cc)
  CC=gcc
endif

ifeq ($(OBJCC),)
  OBJCC=$(CC)
endif

# add tuning flags if we're on i386 - this is crucial, because the
# stack pointer bug in gcc is still there if not tuned
ifeq ($(ARCH),i386)
    CFLAGS+=-msse3 -march=pentium-m -mtune=prescott -O3
endif

CPPFLAGS+=-I. -I/Library/Frameworks/R.framework/Headers -I/Library/Frameworks/R.framework/PrivateHeaders
OBJCFLAGS+=-fobjc-exceptions
LIBS+=-framework R -framework Cocoa -framework Security -framework ExceptionHandling -framework WebKit -framework AppKit

ifeq ($(STYLE),)
  STYLE:=Deployment
endif

CFLAGS+=-g

ifeq ($(NATIVE_ARCH)$(ARCH),ppci386)
  CFLAGS+=-isysroot /Developer/SDKs/MacOSX10.4u.sdk
  LDFLAGS+=-isysroot /Developer/SDKs/MacOSX10.4u.sdk
  # linking must be done with apple's gcc, because apparently we don't support -isysroot
  LD=/usr/bin/gcc
endif

all: R.app

R.app: R sush build/$(STYLE)/R.app
	rm -rf R.app
	cp -r build/$(STYLE)/R.app .
	cp R R.app/Contents/MacOS/R
	cp sush R.app/Contents/Resources/sush

build/$(STYLE)/R.app: .svn/entries
	rm -rf build/$(STYLE)
	mkdir -p build/$(STYLE)
	xcodebuild -configuration $(STYLE) BUILD_DIR=`pwd`/build
	touch build/$(STYLE)/R.app

R.$(ARCH): $(OBJ)
	$(LD) -arch $(ARCH) -o $@ $^ $(LDFLAGS) $(LIBS)

R: $(SRC)
	$(MAKE) CC=/usr/bin/gcc ARCH=ppc 'CFLAGS=-g -O2' R.ppc
	$(MAKE) CC=/usr/local/gcc4.0/bin/gcc ARCH=i386 R.i386
	lipo -create R.ppc R.i386 -o R

sush.$(ARCH): Tools/sush.c
	$(LD) -arch $(ARCH) -o $@ $^ $(CFLAGS)

sush: Tools/sush.c
	$(MAKE) CC=/usr/bin/gcc ARCH=ppc 'CFLAGS=-g -O2' sush.ppc
	$(MAKE) CC=/usr/local/gcc4.0/bin/gcc ARCH=i386 sush.i386
	lipo -create sush.ppc sush.i386 -o sush

%.$(ARCH).o: %.c
	$(CC) -arch $(ARCH) -c $(CFLAGS) $(CPPFLAGS) -o $@ $^

%.$(ARCH).o: %.m
	$(OBJCC) -arch $(ARCH) -c $(CFLAGS) $(CPPFLAGS) $(OBJCFLAGS) -o $@ $^

clean-obj:
	rm -f $(OBJ)

clean: clean-obj
	$(MAKE) ARCH=ppc clean-obj
	$(MAKE) ARCH=i386 clean-obj
	rm -rf R R.fat R.i386 R.ppc sush sush.i386 sush.ppc build R.app

.PHONY: clean clean-obj all
