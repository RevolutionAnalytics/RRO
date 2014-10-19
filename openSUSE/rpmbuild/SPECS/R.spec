Summary: The "Cran R" program from GNU
Name: RRO
Version: 3.1.1
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
%define DIR_VERSION 8.0
%define version 3.1.1

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
if [ -e /opt/Intel_MKL/64 ]; then
MKL_LIB_PATH=/opt/Intel_MKL/64
export LD_LIBRARY_PATH=$MKL_LIB_PATH
MKL="-L${MKL_LIB_PATH} -lmkl_core -lmkl_gf_lp64 -lmkl_gnu_thread -fopenmp -lpthread"
./configure --prefix=%{_libdir}/RRO-%{DIR_VERSION}/R-%{version} --enable-R-shlib --with-blas="$MKL" --with-tcltk --with-tk-config=/usr/lib64/tkConfig.sh --with-tcl-config=/usr/lib64/tclConfig.sh --with-cairo --with-libpng --with-libtiff --with-x=yes --with-lapack --enable-BLAS-shlib LIBR="-lpthread" --enable-memory-profiling
# %configure_no --prefix=/usr/lib/RRO-3.1/R-3.1.1/ --enable-R-shlib --with-blas="$MKL" --with-lapack --enable-BLAS-shlib LIBR="-lpthread" --enable-memory-profiling
else
./configure --prefix=%{_libdir}/RRO-%{DIR_VERSION}/R-%{version} --enable-R-shlib --with-tcltk --with-cairo --with-libpng --with-libtiff --with-x=no --with-lapack --enable-BLAS-shlib LIBR="-lpthread" --enable-memory-profiling
fi
make -j2
if [ -e /opt/Intel_MKL/64 ]; then
cp /opt/Intel_MKL/64/*.so lib
bin/R CMD INSTALL ../../RevoBase.tar.gz
fi

%install
%make_install
# make install
# %find_lang %{name}
rm -f %{buildroot}/%{_infodir}/dir
rm -rf %{buildroot}/lib
if [ -e /opt/Intel_MKL/64 ]; then
cp /opt/Intel_MKL/64/*.so  %{buildroot}%{_libdir}/RRO-8.0/R-3.1.1/lib64/R/lib
fi
cp ../../../../files/Rprofile.site %{buildroot}%{_libdir}/RRO-8.0/R-3.1.1/lib64/R/etc
cp ../../../../README-legal.txt %{buildroot}%{_libdir}/RRO-8.0
cp ../../../../README.txt %{buildroot}%{_libdir}/RRO-8.0
cp ../../../../COPYING %{buildroot}%{_libdir}/RRO-8.0

%post
if test "${RPM_INSTALL_PREFIX0}" = ""; then
    RPM_INSTALL_PREFIX0=/usr/
fi
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/R $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/bin/R
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/Rscript $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/bin/Rscript
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/R /usr/bin
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/RRO-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/Rscript /usr/bin
echo 'install.packages("checkpoint",repos="http://cran.revolutionanalytics.com")' | R -q --vanilla
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
%{_libdir}/RRO-%{DIR_VERSION}/README-legal.txt
%{_libdir}/RRO-%{DIR_VERSION}/README.txt
#  %{_libdir}/RRO-%{DIR_VERSION}/sources/
#%{_bindir}/Revo64
#%{_bindir}/Revoscript

%exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/%{libnn}/R/etc/repositories
# %exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/%{libnn}/R/lib/libRblas.so
# %exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/%{libnn}/R/lib/libRlapack.so
%exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/bin/R
%exclude %{_libdir}/RRO-%{DIR_VERSION}/R-%{version}/bin/Rscript

%changelog
* Tue Sep 06 2011 The Coon of Ty <Ty@coon.org> 2.8-1
- Initial version of the package
ORG-LIST-END-MARKER
