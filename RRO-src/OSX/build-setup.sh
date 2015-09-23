#!/bin/bash

touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
PROD=$(softwareupdate -l |
  grep "\*.*Command Line" |
  head -n 1 | awk -F"*" '{print $2}' |
  sed -e 's/^ *//' |
  tr -d '\n')
softwareupdate -i "$PROD" -v;

mkdir -p ~/tmp
pushd ~/tmp
curl -O curl -O http://coudert.name/software/gfortran-4.8.2-Mavericks.dmg
hdid gfortran-4.8.2-Mavericks.dmg
installer -pkg /Volumes/gfortran-4.8.2-Mavericks/gfortran-4.8.2-Mavericks/gfortran.pkg -target /
curl -O http://s.sudre.free.fr/Software/files/Packages.dmg
hdid Packages.dmg
installer -pkg /Volumes/Packages/packages/Packages.pkg -target /
curl -O http://xquartz-dl.macosforge.org/SL/XQuartz-2.7.7.dmg
hdid XQuartz-2.7.7.dmg
installer -pkg /Volumes/XQuartz-2.7.7/XQuartz.pkg -target /

curl -O http://r.research.att.com/libs/readline-5.2-12-darwin8-bin4.tar.gz
tar fvxz readline-5.2-12-darwin8-bin4.tar.gz -C /
curl -O https://r.research.att.com/libs/tiff-4.0.3-darwin.13-x86_64.tar.gz
tar fvxz tiff-4.0.3-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/texinfo-5.2-darwin.13-x86_64.tar.gz
tar fvxz texinfo-5.2-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/tcl8.6.0-darwin10-x86_64.tar.gz
tar fvxz tcl8.6.0-darwin10-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/tk8.6.0-darwin10-x86_64.tar.gz
tar fvxz tk8.6.0-darwin10-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/qpdf-5.1.2-darwin.13-x86_64.tar.gz
tar fvxz qpdf-5.1.2-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/pixman-0.32.6-darwin.13-x86_64.tar.gz
tar fvxz pixman-0.32.6-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/pcre-8.36-darwin.13-x86_64.tar.gz
tar fvxz pcre-8.36-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/mpfr-3.1.2-darwin.13-x86_64.tar.gz
tar fvxz mpfr-3.1.2-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/libpng-1.6.17-darwin.13-x86_64.tar.gz
tar fvxz libpng-1.6.17-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/jpeg-9-darwin.13-x86_64.tar.gz
tar fvxz jpeg-9-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/icu-54.1-darwin.13-x86_64.tar.gz
tar fvxz icu-54.1-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/freetype-2.5.5-darwin.13-x86_64.tar.gz
tar fvxz freetype-2.5.5-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/fontconfig-2.11.1-darwin.13-x86_64.tar.gz
tar fvxz fontconfig-2.11.1-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/cloog-0.18.0-darwin13.tar.gz
tar fvxz cloog-0.18.0-darwin13.tar.gz -C /
curl -O https://r.research.att.com/libs/cairo-1.14.2-darwin.13-x86_64.tar.gz
tar fvxz cairo-1.14.2-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/pkgconfig-0.28-darwin.13-x86_64.tar.gz
tar fvxz pkgconfig-0.28-darwin.13-x86_64.tar.gz -C /
curl -O https://r.research.att.com/libs/pkgconfig-system-stubs-darwin13.tar.gz
tar fvxz pkgconfig-system-stubs-darwin13.tar.gz -C /
popd
