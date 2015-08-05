Summary: The "Cran R" program from GNU
Name: R
Version: 3.2.1
%define debug_package %{nil}
Release: 1%{?dist}
Source0: %{name}-%{version}.tar.gz
License: GPLv3+
Group: Development/Tools

Requires(post): info
Requires(preun): info

%define libnn lib64
%define DIR_VERSION 3.2
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
pwd
./configure --prefix=%{_libdir}/Revo-%{DIR_VERSION}/R-%{version} --enable-R-shlib --with-tcltk --with-cairo --with-libpng --with-libtiff --with-x=yes --with-lapack --enable-BLAS-shlib LIBR="-lpthread" --enable-memory-profiling
make -j2

%install
if grep -q "release 5" /etc/redhat-release; then
make install
make install-tests
else 
%make_install
make install-tests
cp -a tests %{buildroot}%{_libdir}/Revo-3.2/R-3.2.1/lib64/R
tar czf test.tar.gz tests
cp test.tar.gz /opt/hudson/workspace
fi
# %find_lang %{name}
rm -f %{buildroot}/%{_infodir}/dir
rm -rf %{buildroot}/lib

%post
if test "${RPM_INSTALL_PREFIX0}" = ""; then
    RPM_INSTALL_PREFIX0=/usr
fi
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/Revo-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/R $RPM_INSTALL_PREFIX0/%{_lib}/Revo-%{DIR_VERSION}/R-%{version}/bin/R
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/Revo-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/R /usr/bin
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/Revo-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/Rscript $RPM_INSTALL_PREFIX0/%{_lib}/Revo-%{DIR_VERSION}/R-%{version}/bin/Rscript
ln -s $RPM_INSTALL_PREFIX0/%{_lib}/Revo-%{DIR_VERSION}/R-%{version}/%libnn/R/bin/Rscript /usr/bin
%postun
if test "${revo_prefix}" = ""; then
    revo_prefix=/usr/
fi
revo_prefix=`echo "$revo_prefix" | sed "s/\/*$//"`
if test -h ${revo_prefix}/bin/R
    then
    rm -f ${revo_prefix}/%{libnn}/Revo-%{DIR_VERSION}/R-%{version}/bin/R
    rm -f ${revo_prefix}/%{libnn}/Revo-%{DIR_VERSION}/R-%{version}/bin/Rscript
    rm -f /usr/bin/R
    rm -f /usr/bin/Rscript
else
    echo "Warning: cannot find Revo executables.  Check revo_prefix."
fi

# %files -f %{name}.lang
%files
%defattr(-, root, root)
%{_libdir}/Revo-%{DIR_VERSION}/R-%{version}/
#  %{_libdir}/Revo-%{DIR_VERSION}/sources/
#%{_bindir}/Revo64
#%{_bindir}/Revoscript

%exclude %{_libdir}/Revo-%{DIR_VERSION}/R-%{version}/%{libnn}/R/etc/repositories
# %exclude %{_libdir}/Revo-%{DIR_VERSION}/R-%{version}/%{libnn}/R/lib/libRblas.so
# %exclude %{_libdir}/Revo-%{DIR_VERSION}/R-%{version}/%{libnn}/R/lib/libRlapack.so
%exclude %{_libdir}/Revo-%{DIR_VERSION}/R-%{version}/bin/R
%exclude %{_libdir}/Revo-%{DIR_VERSION}/R-%{version}/bin/Rscript

%changelog
* Tue Sep 06 2011 The Coon of Ty <Ty@coon.org> 2.8-1
- Initial version of the package
ORG-LIST-END-MARKER
