Summary: The "Cran R" program from GNU
Name: :::RPM_NAME:::
Version: :::RPM_VERSION:::
%define debug_package %{nil}
Release: 1%{?dist}
Source0: %{name}-%{version}.tar.gz
License: GPLv3+
Group: Development/Tools
BuildRequires: ed, gcc, gcc-c++, gcc-objc
BuildRequires: gcc-gfortran, perl
BuildRequires: libpng-devel, libjpeg-devel, readline-devel, libtiff-devel
BuildRequires: pango-devel, libXt-devel, libICE-devel, libX11-devel, libSM-devel
BuildRequires: cairo-devel, ncurses-devel
Requires: libpng, libjpeg, readline, libtiff, gcc, make, gcc-gfortran 
Requires: ghostscript-fonts, libgfortran, cairo, curl, libicu
Requires: pango, libSM, libXt, libXmu, zip
AutoReqProv: No
BuildRoot: %{_tmppath}/%{name}-%{version}-build
Prefix: /usr/lib64
Requires(post): info
Requires(preun): info

%define libnn lib64
%define DIR_VERSION :::RPM_VERSION:::
%define r_version :::R_VERSION:::

%description
'GNU S' - A language and environment for statistical computing and
graphics. R is similar to the award-winning S system, which was
developed at Bell Laboratories by John Chambers et al. It provides a
wide variety of statistical and graphical techniques (linear and
nonlinear modelling, statistical tests, time series analysis,
classification, clustering, ...).

R is designed as a true computer language with control-flow
constructions for iteration and alternation, and it allows users to
add additional functionality by defining new functions. For
computationally intensive tasks, C, C++ and Fortran code can be linked
and called at run time.

%prep
%setup -q 

%build

env LDFLAGS='-L/opt/build/build/lib' LIBS='-licui18n -licuuc -licudata -lstdc++' CPPFLAGS='-I/opt/build/build/include -DU_STATIC_IMPLEMENTATION' CFLAGS='-I/opt/build/build/include -DU_STATIC_IMPLEMENTATION' CURL_LIBS='-lcurl -ldl -lssl -lcrypto -lz -lrt' ./configure --prefix=%{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version} --enable-R-shlib --with-tcltk --with-cairo --with-libpng --with-ICU --with-jpeglib --with-libtiff --with-x=yes --with-lapack --enable-BLAS-shlib LIBR="-lpthread" --enable-memory-profiling 
make -j8

%install

make install

# %find_lang %{name}

cp %{_topdir}/Rprofile.site %{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/lib64/R/etc
cp %{_topdir}/README.txt %{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}
cp %{_topdir}/COPYING %{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}
cp %{_topdir}/ThirdPartyNotices.pdf %{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}
cp %{_topdir}/microsoft-r-cacert.pem %{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}

if [ -d "/tmp/rro_extra_pkgs" ]
then
    pushd /tmp/rro_extra_pkgs
    for filename in :::EXTRA_PKGS:::; do
        %{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/lib64/R/bin/R --vanilla --install-tests CMD INSTALL ${filename}
    done
    popd
fi


%post
if test "${RPM_INSTALL_PREFIX0}" = ""; then
    RPM_INSTALL_PREFIX0=/usr/lib64
fi
rm -f /usr/bin/R
rm -f /usr/bin/Rscript
ln -s $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/%libnn/R/bin/R $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/R
ln -s $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/%libnn/R/bin/R /usr/bin
ln -s $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/%libnn/R/bin/Rscript $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/Rscript
ln -s $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/%libnn/R/bin/Rscript /usr/bin
cp $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/microsoft-r-cacert.pem /etc

%preun
if test "${revo_prefix}" = ""; then
    revo_prefix=/usr/lib64
fi
rm -f ${revo_prefix}/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/R
rm -f ${revo_prefix}/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/Rscript
rm -f /usr/bin/R
rm -f /usr/bin/Rscript


# %files -f %{name}.lang
%files
%defattr(-, root, root)
%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/
%{_libdir}/%{name}-%{DIR_VERSION}/COPYING
%{_libdir}/%{name}-%{DIR_VERSION}/README.txt
%{_libdir}/%{name}-%{DIR_VERSION}/ThirdPartyNotices.pdf
%{_libdir}/%{name}-%{DIR_VERSION}/microsoft-r-cacert.pem
#  %{_libdir}/%{name}-%{DIR_VERSION}/sources/
#%{_bindir}/Revo64
#%{_bindir}/Revoscript

%exclude %{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/R
%exclude %{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/Rscript
