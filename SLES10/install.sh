#!/bin/bash
echo "Installing RRO-3.2.1"
zypper install -y make gcc #2>/dev/null 1>/dev/null
rpm -ivh RRO-3.*-SLES10*.x86_64.rpm #2>/dev/null 1>/dev/null

