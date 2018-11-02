#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/std_funcs.sh

# Variables #
NUM_VHOST_IFACES=4

function start_test {

    set_dpdk_env
    std_start_db
    std_start_ovs

    sudo $OVS_DIR/utilities/ovs-vsctl set Bridge br0 mcast_snooping_enable=true

    std_create_ifaces $NUM_VHOST_IFACES   # writes to global STD_IFACT_TO_PORT

    echo "Setting up OF rules.."
    set -e #fail if i/f name -> of port mapping does not exist
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    #sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=${STD_IFACE_TO_PORT[dpdk_0]},action=output:${STD_IFACE_TO_PORT[dpdk_1]}
    #sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=${STD_IFACE_TO_PORT[dpdk_1]},action=output:${STD_IFACE_TO_PORT[dpdk_0]}
    #sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=${STD_IFACE_TO_PORT[dpdk_0]},action=in_port
    #sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=${STD_IFACE_TO_PORT[dpdk_1]},action=in_port
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 action=NORMAL
    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    set +e

    echo "Starting VMs.."
    for idx in $(seq 0 $[$NUM_VHOST_IFACES-1])
    do
        std_start_vm $idx
    done

    echo "Current state.."
    set -x
    sudo $OVS_DIR/utilities/ovs-vsctl show
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-ofctl show br0
    sudo $OVS_DIR/utilities/ovs-appctl vlog/set ANY info
    set +x

    echo "All done."
	return
}

function menu {
        echo "launching Switch.."
        start_test
}

#The function has to get called only when its in subshell.
if [ "$OVS_RUN_SUBSHELL" == "1" ]; then
    menu
fi
