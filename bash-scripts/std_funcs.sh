#!/usr/bin/env bash

# This file contains a place to put standard code that is common across several
# test scripts. All the functions should be called std_...

declare DPDK_IGB_UIO
declare DPDK_BIND_TOOL

# Load the ovs schema and start ovsdb.
std_start_db() {
    sudo rm /usr/local/etc/openvswitch/conf.db
    sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema

    sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
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

