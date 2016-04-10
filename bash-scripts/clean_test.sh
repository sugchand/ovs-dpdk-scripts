#!/bin/bash -x

# Directories #

OVS_DIR=/home/sugeshch/repo/ovs_vxlan_fvl
DPDK_DIR=/home/sugeshch/repo/ovs_dpdk/dpdk
DPDK_PHY1=0000:07:00.0
DPDK_PHY2=0000:07:00.1
#KERNEL_DRV=ixgbe
KERNEL_DRV=i40e


# Variables #
HUGE_DIR=/dev/hugepages

sudo $OVS_DIR/utilities/ovs-appctl -t ovs-vswitchd exit
sudo $OVS_DIR/utilities/ovs-appctl -t ovsdb-server exit
sleep 1
sudo umount $HUGE_DIR
sudo $DPDK_DIR/tools/dpdk_nic_bind.py --bind=$KERNEL_DRV $DPDK_PHY1 $DPDK_PHY2
sudo pkill -f ovs*
sudo pkill -f qemu-system-x86_64*
sudo rm -rf /usr/local/var/run/openvswitch/*
sudo rm -rf /usr/local/var/log/openvswitch/*
sudo pkill -f pmd*


