#!/bin/bash
echo "Installing RRO-8.0-Beta"
dpkg -i RRO-8.0-Beta-Ubuntu-14.04.x86_64.deb 2>/dev/null 1>/dev/null
if [ "$?" -ne 0 ]; then 
apt-get -y -f install
fi
apt-get -y install gcc 
apt-get -y install make 
apt-get -y install gfortran-4.8 
apt-get -y install liblzma-dev
