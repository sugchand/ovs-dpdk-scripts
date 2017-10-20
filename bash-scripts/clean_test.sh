#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh

# Variables #
HUGE_DIR=/dev/hugepages

function clean {
    set_dpdk_env
    sudo $OVS_DIR/utilities/ovs-appctl -t ovs-vswitchd exit
    sudo $OVS_DIR/utilities/ovs-appctl -t ovsdb-server exit
    sudo $OVS_DIR//utilities/ovs-dpctl del-dp ovs-system
    sudo modprobe -r openvswitch
    sleep 1
    sudo umount $HUGE_DIR
    sudo $DPDK_BIND_TOOL --unbind $DPDK_PCI1 $DPDK_PCI2 $DPDK_PCI3 $DPDK_PCI4
    sudo modprobe $KERNEL_NIC_DRV
    sudo $DPDK_BIND_TOOL --bind=$KERNEL_NIC_DRV $DPDK_PCI1 $DPDK_PCI2
    sudo pkill -9 ovs-vswitchd
    sudo pkill -9 ovs-vsctl
    sudo pkill -9 qemu-system-x86_64*
    sudo pkill -9 ovsdb-server
    sudo rm -rf /usr/local/var/run/openvswitch/*
    sudo rm -rf /usr/local/var/log/openvswitch/*
    sudo pkill -9 pmd*
    echo "System cleaned for next test run"
}

#The function has to get called only when its in subshell.
if [ "$OVS_RUN_SUBSHELL" == "1" ]; then
    clean
fi

