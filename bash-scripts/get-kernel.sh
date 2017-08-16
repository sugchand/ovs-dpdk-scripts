#!/bin/bash

echo "Installing the kernel version 4.12. Change repo link to get right version"
mkdir kernel-4.12 && cd kernel-4.12

wget -e http_proxy=http://proxy.ir.intel.com:911/ http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.12/linux-headers-4.12.0-041200_4.12.0-041200.201707022031_all.deb
wget -e http_proxy=http://proxy.ir.intel.com:911/ http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.12/linux-headers-4.12.0-041200-generic_4.12.0-041200.201707022031_amd64.deb
wget -e http_proxy=http://proxy.ir.intel.com:911/ http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.12/linux-image-4.12.0-041200-generic_4.12.0-041200.201707022031_amd64.deb
dpkg -i linux-*.deb 
update-grub
reboot now
