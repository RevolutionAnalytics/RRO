#!/bin/bash
echo "Installing RRO-8.0.1-Beta"
rm /usr/bin/R 2>/dev/null 1>/dev/null
rm /usr/bin/Rscript 2>/dev/null 1>/dev/null
apt-get -y install gcc  2>/dev/null 1>/dev/null
apt-get -y install make  2>/dev/null 1>/dev/null
apt-get -y install gfortran-4.8  2>/dev/null 1>/dev/null
apt-get -y install liblzma-dev 2>/dev/null 1>/dev/null
dpkg -i RRO-8.0.1-Beta-Ubuntu-14.04.x86_64.deb 2>/dev/null 1>/dev/null
if [ "$?" -ne 0 ]; then 
apt-get -y -f install
fi
