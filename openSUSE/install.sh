#!/bin/bash
echo "Installing RRO-8.0.3"
zypper install -y make gcc gfortran 2>/dev/null 1>/dev/null
zypper install -y localinstall RRO-8.*-openSUSE-13.1.x86_64.rpm 2>/dev/null 1>/dev/null

