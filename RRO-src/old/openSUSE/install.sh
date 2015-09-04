#!/bin/bash
echo "Installing RRO-3.2.1"
zypper install -y make gcc 2>/dev/null 1>/dev/null
zypper install -y RRO-3.*-openSUSE-13.1.x86_64.rpm 2>/dev/null 1>/dev/null

