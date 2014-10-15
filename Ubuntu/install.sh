#!/bin/bash
echo "Installing RRO-8.0-Beta"
dpkg -i RRO-8.0-Beta-Ubuntu-14.04.x86_64.deb 2>/dev/null 1>/dev/null
if [ "$?" -ne 0 ]; then 
apt-get -y -f install
apt-get -y install gcc make gfortran-4.8 liblzma-dev
fi
