#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh
echo $OVS_DIR $DPDK_DIR

function start_test {

    print_phy2phy_banner
    set_dpdk_env
    std_umount
    std_mount
    std_start_db
    std_start_ovs

    std_create_ifaces 0

    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=${STD_IFACE_TO_PORT[dpdk_0]},action=output:${STD_IFACE_TO_PORT[dpdk_1]}
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=${STD_IFACE_TO_PORT[dpdk_1]},action=output:${STD_IFACE_TO_PORT[dpdk_0]}
    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."
}

function menu {
        echo "launching Switch.."
        start_test
}

#The function has to get called only when its in subshell.
if [ "$OVS_RUN_SUBSHELL" == "1" ]; then
    menu
fi
