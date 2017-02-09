#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
echo $OVS_DIR $DPDK_DIR

# Variables #
HUGE_DIR=/dev/hugepages


function start_test {

	sudo umount $HUGE_DIR
	echo "Lets bind the ports to the kernel first"
	sudo $DPDK_DIR/tools/dpdk-devbind.py --bind=$KERNEL_NIC_DRV $DPDK_PCI1 $DPDK_PCI2
    mkdir -p $HUGE_DIR
	sudo mount -t hugetlbfs nodev $HUGE_DIR

	sudo modprobe uio
	sudo rmmod igb_uio.ko
	sudo insmod $DPDK_DIR/$DPDK_TARGET/kmod/igb_uio.ko
	sudo $DPDK_DIR/tools/dpdk-devbind.py --bind=igb_uio $DPDK_PCI1 $DPDK_PCI2

	sudo rm /usr/local/etc/openvswitch/conf.db
	sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema

	sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="0x4"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,0"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch .  other_config:n-handler-threads=1

	sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
	sleep 22
	sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-in
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-out
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-p1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-p2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-phy

    echo "Adding bridges "
	sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-in -- set bridge br-in datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-out -- set bridge br-out datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-p1 -- set bridge br-p1 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-p2 -- set bridge br-p2 datapath_type=netdev

    echo "Adding ports to bridges.."
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-in $DPDK_NIC1 -- set Interface $DPDK_NIC1 type=dpdk options:dpdk-devargs=$DPDK_PCI1 
	sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-out $DPDK_NIC2 -- set Interface $DPDK_NIC2 type=dpdk options:dpdk-devargs=$DPDK_PCI2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-in patch1S1 -- set Interface patch1S1 type=patch options:peer=patch1S2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-in patch2S1 -- set Interface patch2S1 type=patch options:peer=patch2S2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-p1 patch1S2 -- set Interface patch1S2 type=patch options:peer=patch1S1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-p2 patch2S2 -- set Interface patch2S2 type=patch options:peer=patch2S1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-out patch3S1 -- set Interface patch3S1 type=patch options:peer=patch3S2
#    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-out patch4S1 -- set Interface patch4S1 type=patch options:peer=patch4S2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-p1 patch3S2 -- set Interface patch3S2 type=patch options:peer=patch3S1
#    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-p2 patch4S2 -- set Interface patch4S2 type=patch options:peer=patch4S1

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-p2 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=10.0.0.2 options:key=1000
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set bridge br-out other_config:hwaddr=00:00:64:00:00:01
    sudo ip addr add 10.0.0.1/24 dev br-out
    sudo ip link set br-out up
    sudo iptables -F
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 10.0.0.1/24 br-out
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 0.0.0.0 br-p2

    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-p2 10.0.0.1 00:00:64:00:00:01
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-out 10.0.0.2 00:00:64:00:00:02
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-out 10.0.0.20 20:20:10:10:10:10
    
	sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-in
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-out
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-p1
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br-p2

    echo "Adding flows to the bridge"
	sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-in idle_timeout=0,in_port=1,actions=output:3,output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-p2 idle_timeout=0,in_port=1,actions=mod_dl_src=00:00:00:00:00:00,mod_nw_src=1.1.1.1,output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow -O OpenFlow13 br-p1 idle_timeout=0,in_port=1,actions=push_vlan:0x8100,mod_vlan_vid=0xFF,mod_dl_dst=FF:FF:FF:FF:FF:FF,output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-out idle_timeout=0,in_port=LOCAL,actions=output:1
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-out idle_timeout=0,in_port=2,actions=output:1
	sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br-in
	sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br-out
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br-p1
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br-p2

	sudo $OVS_DIR/utilities/ovs-vsctl show
	sudo $OVS_DIR/utilities/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"

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
    sudo pkill -9 qemu-system-x86_64*
    sudo rm -rf /usr/local/var/run/openvswitch/*
    sudo rm -rf /usr/local/var/log/openvswitch/*
    sudo pkill -9 pmd*
}

function menu {
        echo "launching Switch.."
	    kill_switch
    	start_test
}

#The function has to get called only when its in subshell.
if [ "$OVS_RUN_SUBSHELL" == "1" ]; then
    menu
fi
