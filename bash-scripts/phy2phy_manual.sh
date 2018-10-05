#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh
echo $OVS_DIR $DPDK_DIR

# Variables #
HUGE_DIR=/dev/hugepages


function start_test {

    print_phy2phy_banner
    set_dpdk_env
    std_umount
    std_mount
    std_start_db

    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=$DPDK_LCORE_MASK
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem=$DPDK_SOCKET_MEM
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:emc-insert-inv-prob=100          #x => insert 1 per x times, 1 => always. Special 0 => never.
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra="$STD_WHITELIST --file-prefix=ovs_"

    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sleep 22

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0 -- set bridge br0 datapath_type=netdev
    std_create_ifaces 0
    #sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $DPDK_NIC1 \
		#-- set Interface $DPDK_NIC1 type=dpdk \
		#options:dpdk-devargs=$DPDK_PCI1 options:n_rxq=2
    #sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $DPDK_NIC2 \
		#-- set Interface $DPDK_NIC2 type=dpdk \
		#options:dpdk-devargs=$DPDK_PCI2 options:n_rxq=2

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
