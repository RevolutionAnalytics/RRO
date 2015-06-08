Summary: The "Cran R" program from GNU
Name: RRO-3.2.1
Version: 3.2.1
Release: 1%{?dist}
Source0: %{name}-%{version}.tar.gz
License: GPLv3+
Group: Development/Tools

BuildRequires: ed, gcc, gcc-c++, gcc-objc
BuildRequires: perl, texinfo
BuildRequires: libpng-devel, libjpeg-devel, readline5-devel, libtiff-devel
BuildRequires: libSM-devel, libX11-devel, libICE-devel,
BuildRequires: libXt-devel, libXmu-devel, pango-devel
BuildRequires: cairo-devel, ncurses-devel
Requires: make, gcc, gcc-fortran,  libpng, readline, cairo-devel
Requires: libtiff, libjpeg8, ghostscript-fonts-std
Requires(post): info
Requires(preun): info

%define libnn lib64
%define DIR_VERSION 3.2.1
%define version 3.2.1

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
./configure --prefix=%{_libdir}/RRO-%{DIR_VERSION}/R-%{version} --enable-R-shlib --with-tcltk --with-cairo --with-libpng --with-libtiff --with-x=no --with-lapack --enable-BLAS-shlib LIBR="-lpthread" --enable-memory-profiling

make -j2

%install
%make_install
# make install
# %find_lang %{name}
rm -f %{buildroot}/%{_infodir}/dir
rm -rf %{buildroot}/lib
cp ../../../../files/Rprofile.site %{buildroot}%{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/lib64/R/etc
cp ../../../../README.txt %{buildroot}%{_libdir}/RRO-%{DIR_VERSION}
cp ../../../../COPYING %{buildroot}%{_libdir}/RRO-%{DIR_VERSION}
##cp ../../../../RRO-NEWS.txt %{buildroot}%{_libdir}/RRO-%{DIR_VERSION}

%post
if test "${RPM_INSTALL_PREFIX0}" = ""; then
    RPM_INSTALL_PREFIX0=/usr/
fi
rm -f /usr/bin/R
rm -f /usr/bin/Rscript
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/R $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/bin/R
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/Rscript $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/bin/Rscript
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/R /usr/bin
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/Rscript /usr/bin
echo 'install.packages("checkpoint",repos="http://mran.revolutionanalytics.com/snapshot/2015-05-01")' | R -q --vanilla
%postun
if test "${revo_prefix}" = ""; then
    revo_prefix=/usr/
fi
revo_prefix=`echo "$revo_prefix" | sed "s/\/*$//"`
if test -h ${revo_prefix}/bin/R
    then
    rm -f ${revo_prefix}/%{libnn}/RRO-%{DIR_VERSION}/R-%{version}/bin/R
    rm -f ${revo_prefix}/%{libnn}/RRO-%{DIR_VERSION}/R-%{version}/bin/Rscript
    rm -f /usr/bin/R
    rm -f /usr/bin/Rscript
else
    echo "Warning: cannot find Revo executables.  Check revo_prefix."
fi

# %files -f %{name}.lang
%files
%defattr(-, root, root)
%{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/
%{_libdir}/RRO-%{DIR_VERSION}/COPYING
#%{_libdir}/RRO-%{DIR_VERSION}/RRO-NEWS.txt
%{_libdir}/RRO-%{DIR_VERSION}/README.txt
#  %{_libdir}/RRO-%{DIR_VERSION}/sources/
#%{_bindir}/Revo64
#%{_bindir}/Revoscript

# %exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/%{libnn}/R/etc/repositories
# %exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/%{libnn}/R/lib/libRblas.so
# %exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/%{libnn}/R/lib/libRlapack.so
%exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/bin/R
%exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/bin/Rscript

%changelog
* Tue Sep 06 2011 The Coon of Ty <Ty@coon.org> 2.8-1
- Initial version of the package
ORG-LIST-END-MARKER
