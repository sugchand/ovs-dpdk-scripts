#!/usr/bin/env bash

# This file contains a place to put standard code that is common across several
# test scripts. All the functions should be called std_...

declare DPDK_IGB_UIO
declare DPDK_BIND_TOOL

# Load the ovs schema and start ovsdb.
std_start_db() {
    sudo rm /usr/local/etc/openvswitch/conf.db
    sudo $OVS_DIR/ovsdb/ovsdb-tool \
        create /usr/local/etc/openvswitch/conf.db \
        $OVS_DIR/vswitchd/vswitch.ovsschema
    sudo $OVS_DIR/ovsdb/ovsdb-server \
        --remote=punix:/usr/local/var/run/openvswitch/db.sock \
        --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
        --pidfile --detach
}

function std_stop_db() {
    sudo $OVS_DIR/utilities/ovs-appctl --timeout=3 -t ovsdb-server exit
    sleep 1
    sudo pkill -9 ovsdb-server
}

function std_stop_ovs() {
    sudo $OVS_DIR/utilities/ovs-appctl --timeout=3 -t ovs-vswitchd exit
    sleep 1
    sudo rm -rf /usr/local/var/log/openvswitch/*
    sudo rm -rf /usr/local/var/run/openvswitch/*
    sudo pkill -9 ovs-vsctl
    sudo pkill -9 pmd*
    sudo pkill -9 ovs-vswitchd
}

function std_umount() {
    sudo umount $HUGE_DIR
}

function std_bind_kernel() {
    sudo $DPDK_DIR/tools/dpdk-devbind.py --unbind $DPDK_PCI1 $DPDK_PCI2 $DPDK_PCI3 $DPDK_PCI4
    sudo modprobe $KERNEL_NIC_DRV
    sudo $DPDK_BIND_TOOL --bind=$KERNEL_NIC_DRV $DPDK_PCI1 $DPDK_PCI2
}

function std_stop_vms() {
    sudo pkill -9 qemu-system-x86_64*
}

function std_clean {
    std_stop_vms
    std_stop_ovs
    std_stop_db
    std_umount
}

####################################
#  DPDK specific functions         #
####################################

#Set environment specific for DPDK version
set_dpdk_env() {
    case "$DPDK_VER" in
    16.04)
        DPDK_IGB_UIO=$DPDK_DIR/$DPDK_TARGET/kmod/igb_uio.ko
        DPDK_BIND_TOOL=$DPDK_DIR/tools/dpdk_nic_bind.py
        ;;
    16.07|16.11)
        DPDK_IGB_UIO=$DPDK_DIR/$DPDK_TARGET/kmod/igb_uio.ko
        DPDK_BIND_TOOL=$DPDK_DIR/tools/dpdk-devbind.py
        ;;
    17.02|17.05|17.11)
        DPDK_IGB_UIO=$DPDK_DIR/$DPDK_TARGET/kmod/igb_uio.ko
        DPDK_BIND_TOOL=$DPDK_DIR/usertools/dpdk-devbind.py
        ;;
    *)
        echo "DPDK version is not specified, Use default version settings"
        DPDK_IGB_UIO=$DPDK_DIR/$DPDK_TARGET/kmod/igb_uio.ko
        DPDK_BIND_TOOL=$DPDK_DIR/tools/dpdk-devbind.py
        ;;
    esac
}

