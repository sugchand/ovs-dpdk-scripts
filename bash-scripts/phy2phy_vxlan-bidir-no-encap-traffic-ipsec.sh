#!/bin/bash -x



# Variables #
HUGE_DIR=/dev/hugepages
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh


function start_test {
    set_dpdk_env
    sudo mkdir -p $HUGE_DIR
    sudo umount $HUGE_DIR
    echo "Lets bind the ports to the kernel first"
    sudo $DPDK_BIND_TOOL --bind=$KERNEL_NIC_DRV $DPDK_PCI1 $DPDK_PCI2
    sudo mount -t hugetlbfs nodev $HUGE_DIR

    sudo modprobe uio
    sudo insmod $DPDK_IGB_UIO
    sudo $DPDK_BIND_TOOL --bind=igb_uio $DPDK_PCI1 $DPDK_PCI2

    #sudo rm /usr/local/etc/openvswitch/conf.db
    #sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema
    std_start_db

    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="0x4"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,0"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"

    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sleep 22

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-phy1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-phy2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-tun1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-tun2

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-phy1 -- set Bridge br-phy1 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-phy2 -- set Bridge br-phy2 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-tun1 -- set Bridge br-tun1 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-tun2 -- set Bridge br-tun2 datapath_type=netdev

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set bridge br-tun1 other_config:hwaddr=00:00:10:00:00:01
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set bridge br-tun2 other_config:hwaddr=00:00:20:00:00:01

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-phy1 $DPDK_NIC1 -- set Interface $DPDK_NIC1 type=dpdk options:dpdk-devargs=$DPDK_PCI1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-phy2 $DPDK_NIC2 -- set Interface $DPDK_NIC2 type=dpdk options:dpdk-devargs=$DPDK_PCI2
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br-phy1 vxlanipsec0 -- set interface vxlanipsec0 type=vxlanipsec options:remote_ip=10.0.0.2 options:key=1000
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br-phy2 vxlanipsec1 -- set interface vxlanipsec1 type=vxlanipsec options:remote_ip=20.0.0.2 options:key=1000
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-tun1 br-tun1-p -- set interface br-tun1-p type=patch options:peer=br-tun2-p
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-tun2 br-tun2-p -- set interface br-tun2-p type=patch options:peer=br-tun1-p

    sudo ip addr add 10.0.0.1/24 dev br-tun1
    sudo ip addr add 20.0.0.1/24 dev br-tun2
    sudo ip link set br-phy1 up
    sudo ip link set br-phy2 up
    sudo ip link set br-tun1 up
    sudo ip link set br-tun2 up
    sudo iptables -F
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 10.0.0.1/24 br-tun1
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 20.0.0.1/24 br-tun2
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy1 10.0.0.1 00:00:10:00:00:01
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy2 20.0.0.1 00:00:20:00:00:01
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-tun1 10.0.0.2 00:00:10:00:00:02
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-tun2 20.0.0.2 00:00:20:00:00:02
#    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy1 10.0.0.2 00:00:10:00:00:02
#    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy2 20.0.0.2 00:00:20:00:00:02


    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-phy1
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-phy2
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-tun1
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-tun2

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy1 idle_timeout=0,in_port=1,action=output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy1 idle_timeout=0,in_port=2,action=output:1

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy2 idle_timeout=0,in_port=1,action=output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy2 idle_timeout=0,in_port=2,action=output:1

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-tun1 idle_timeout=0,in_port=1,action=output:LOCAL
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-tun1 idle_timeout=0,in_port=LOCAL,actions=mod_dl_src:00:00:20:00:00:02,mod_dl_dst:00:00:20:00:00:01,mod_nw_src:20.0.0.2,mod_nw_dst:20.0.0.1,mod_nw_tos=0x10,output:1 #Change IP ...

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-tun2 idle_timeout=0,in_port=1,action=output:LOCAL
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-tun2 idle_timeout=0,in_port=LOCAL,actions=mod_dl_src:00:00:10:00:00:02,mod_dl_dst:00:00:10:00:00:01,mod_nw_src:10.0.0.2,mod_nw_dst:10.0.0.1,mod_nw_tos=0x10,output:1 # Change Ip



    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br-tun1
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br-tun2
#    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br-phy
#    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br-phy
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."
}

function kill_switch {
    echo "Killing the switch.."
    sudo $OVS_DIR/utilities/ovs-appctl -t ovs-vswitchd exit
    sudo $OVS_DIR/utilities/ovs-appctl -t ovsdb-server exit
    sleep 1
    sudo pkill -9 ovs-vswitchd
    sudo pkill -9 ovsdb-server
    sudo umount $HUGE_DIR
    sudo pkill -f qemu-system-x86_64*
    sudo rm -rf /usr/local/var/run/openvswitch/*
    sudo rm -rf /usr/local/var/log/openvswitch/*
    sudo pkill -f pmd*
    sudo ip link del br-phy1
    sudo ip link del br-phy2
    sudo ip link del br-tun1
    sudo ip link del br-tun2
}

function menu {
        echo "launching Switch.."
        kill_switch
        start_test
}
