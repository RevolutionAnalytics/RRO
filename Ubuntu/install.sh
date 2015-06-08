#!/bin/bash
echo "Installing RRO-3.2.1"
rm /usr/bin/R 2>/dev/null 1>/dev/null
rm /usr/bin/Rscript 2>/dev/null 1>/dev/null
apt-get -y install gcc g++ gfortran make liblzma-dev 2>/dev/null 1>/dev/null
dpkg -i RRO-3.2.*-Ubuntu*.deb 2>/dev/null 1>/dev/null
if [ "$?" -ne 0 ]; then
apt-get -y -f install
fi
