#!/bin/bash
echo "Installing RRO-3.2.0"
yum -y install make gcc gcc-gfortran 2>/dev/null 1>/dev/null
yum -y --nogpgcheck localinstall RRO-3.*.x86_64.rpm 2>/dev/null 1>/dev/null

