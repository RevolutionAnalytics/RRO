#!/bin/bash
echo "Installing RRO-8.0.3"
zypper install -y make gcc 2>/dev/null 1>/dev/null
zypper install -y RRO-8.*-SLES10*.x86_64.rpm 2>/dev/null 1>/dev/null

