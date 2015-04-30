#!/bin/bash
echo "Installing RRO-8.0.3"
yum -y install make gcc gcc-gfortran 2>/dev/null 1>/dev/null
yum -y --nogpgcheck localinstall RRO-8.*.x86_64.rpm 2>/dev/null 1>/dev/null

