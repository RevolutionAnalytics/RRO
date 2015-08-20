Summary: A language for data analysis and graphics
Name: :::RPM_NAME:::
Version: :::RPM_VERSION:::
Release: 1%{?dist}
Source0: %{name}-%{version}.tar.gz
License: GPL
Group: Applications/Engineering
Packager: Martyn Plummer <martyn.plummer@r-project.org> #Later Pat Shields <pat@revolution-computing.com>
URL: http://www.r-project.org
BuildRoot: %{_tmppath}/%{name}-%{version}
Prefix: /usr/lib64
BuildRequires: ed, gcc, gcc-c++, gcc-objc
BuildRequires: gcc-fortran, perl, texinfo
BuildRequires: libpng-devel, libjpeg-devel, readline-devel, libtiff-devel
BuildRequires: xorg-x11-devel, pango-devel
BuildRequires: cairo-devel, ncurses-devel
Requires: libpng, libjpeg, readline
Requires: libtiff, ghostscript-fonts-std
Requires: gcc, make, gcc-fortran, gcc-c++
Requires: glibc, glibc-devel, curl 
AutoReqProv: No

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
#%setup -q
rm -rf ${RPM_PACKAGE_NAME}-${RPM_PACKAGE_VERSION}
tar -xf %{_sourcedir}/${RPM_PACKAGE_NAME}-%{version}.tar.gz
cd ${RPM_PACKAGE_NAME}-${RPM_PACKAGE_VERSION}
mkdir -p %{_rpmdir}/%{_arch}/

%build
cd ${RPM_PACKAGE_NAME}-${RPM_PACKAGE_VERSION}
./configure --prefix=%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version} --enable-R-shlib --with-tcltk --with-cairo --with-libpng --with-libtiff --with-x=no --with-lapack --enable-BLAS-shlib LIBR="-lpthread" --enable-memory-profiling
make -j6
if test "${CHECK_ALL}" = "YES"
    then
    make check-all
fi
make info

%install
cd ${RPM_PACKAGE_NAME}-${RPM_PACKAGE_VERSION}
make DESTDIR=${RPM_BUILD_ROOT} install
pushd ${RPM_BUILD_ROOT}/%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/lib64/R/lib
cp /usr/local/lib64/libstdc++.so.6.0.10 .
ln -s libstdc++.so.6.0.10 libstdc++.so.6 
ln -s libstdc++.so.6.0.10 libstdc++.so
cp /usr/local/lib64/libgomp.so.1.0.0 .
ln -s libgomp.so.1.0.0 libgomp.so.1
ln -s libgomp.so.1.0.0 libgomp.so
cp /usr/local/lib64/libgfortran.so.3.0.0 .
ln -s libgfortran.so.3.0.0 libgfortran.so.3
ln -s libgfortran.so.3.0.0 libgfortran.so
popd
cp %{_topdir}/Rprofile.site %{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/lib64/R/etc
if [ -d "/tmp/rro_extra_pkgs" ]
then
    pushd /tmp/rro_extra_pkgs
    for filename in :::EXTRA_PKGS:::; do
        if grep -q "release 5" /etc/redhat-release; then
            /usr/lib64/%{name}-%{DIR_VERSION}/R-%{r_version}/lib64/R/bin/R --vanilla CMD INSTALL ${filename}
        else
            %{buildroot}%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/lib64/R/bin/R --vanilla CMD INSTALL ${filename}
        fi
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
ln -s $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/%libnn/R/bin/Rscript $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/Rscript
ln -s $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/%libnn/R/bin/R /usr/bin
ln -s $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/%libnn/R/bin/Rscript /usr/bin
echo 'install.packages("checkpoint",repos="http://mran.revolutionanalytics.com/snapshot/2015-04-29")' | /usr/bin/R -q --vanilla


%postun
rm -f $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/R
rm -f $RPM_INSTALL_PREFIX0/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/Rscript
rm -f /usr/bin/R
rm -f /usr/bin/Rscript


%files
%defattr(-, root, root)
%{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/

%exclude %{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/R
%exclude %{_libdir}/%{name}-%{DIR_VERSION}/R-%{r_version}/bin/Rscript

%changelog
