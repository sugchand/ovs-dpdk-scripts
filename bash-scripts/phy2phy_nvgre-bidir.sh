#!/bin/bash -x

# Variables #
HUGE_DIR=/dev/hugepages
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh


function start_test {
    print_phy_tnl_phy_banner
    set_dpdk_env
    std_start_db


    sudo modprobe uio
    sudo rmmod igb_uio.ko
    sudo insmod $DPDK_IGB_UIO
    sudo $DPDK_BIND_TOOL --bind=igb_uio $DPDK_PCI1 $DPDK_PCI2

    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="$DPDK_LCORE_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="$DPDK_SOCKET_MEM"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra="-w 0000:07:00.0 -w 0000:07:00.1 --file-prefix=ovs_"


    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sleep 22
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0 -- set Bridge br0 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $DPDK_NIC1 -- set Interface $DPDK_NIC1 type=dpdk options:dpdk-devargs=$DPDK_PCI1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Interface $DPDK_NIC1 type=dpdk

    # if flow setting the VNI , create nvgre port as below
    #sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 gre0 -- set interface gre0 type=gre options:remote_ip=100.0.0.2 options:key=flow
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 gre0 -- set interface gre0 type=gre options:remote_ip=10.0.0.2 options:key=1000


    echo "creating the external bridge"
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-phy
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-phy -- set Bridge br-phy datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set bridge br-phy other_config:hwaddr=00:00:64:00:00:01
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-phy $DPDK_NIC2 -- set Interface $DPDK_NIC2 type=dpdk options:dpdk-devargs=$DPDK_PCI2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Interface $DPDK_NIC2 type=dpdk

    sudo ip addr add 10.0.0.1/24 dev br-phy
    sudo ip link set br-phy up
    sudo iptables -F
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 10.0.0.1/24 br-phy
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 0.0.0.0 br0
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br0 10.0.0.1 00:00:64:00:00:01
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy 10.0.0.2 00:00:64:00:00:02
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy 10.0.0.20 20:20:10:10:10:10

    echo "Add necessary rules for the bridges"
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-phy

# set up the tunnel with VNI
#    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,nw_src=192.168.1.101,nw_dst=192.168.3.101,action=set_tunnel:1001,output:2 #Encap
#    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,nw_src=192.168.10.101,nw_dst=192.168.30.101,action=set_tunnel:1000,output:2 #Encap

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,action=output:1
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,action=output:2

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy idle_timeout=0,in_port=1,action=output:LOCAL
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy idle_timeout=0,in_port=LOCAL,action=output:1


    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
#    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br-phy
#    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br-phy
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."
}

function kill_switch {
    echo "Stopping OvS"
    std_stop_ovs
    std_stop_db
	return
}

function menu {
        echo "launching Switch.."
        kill_switch
        start_test
}
