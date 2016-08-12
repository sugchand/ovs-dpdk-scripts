#!/bin/bash

# mount hugepages
sysctl vm.nr_hugepages=256
mkdir -p /dev/hugepages
mount -t hugetlbfs hugetlbfs /dev/hugepages

# mount shared directory

# build and configure system for dpdk
cd /root/ovdk/DPDK
export CC=gcc
export RTE_SDK=/root/ovdk/DPDK
export RTE_TARGET=x86_64-native-linuxapp-gcc

#if enabled, build all of DPDK, if not build only the kernel module
make uninstall
make install T=x86_64-native-linuxapp-gcc

modprobe uio
rmmod igb_uio

insmod x86_64-native-linuxapp-gcc/kmod/igb_uio.ko
./tools/dpdk-devbind.py --status
./tools/dpdk-devbind.py -b igb_uio 00:03.0 00:04.0

# build and run 'test-pmd'
cd /root/ovdk/DPDK/app/test-pmd
make clean
make
./testpmd -c 0x3 -n 4 --socket-mem 128 -- --burst=64 -i --txqflags=0xf00
set fwd mac_retry
start

