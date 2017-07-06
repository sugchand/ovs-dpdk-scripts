#!/bin/bash -x

# Directories #

# Variables #
# SOCK_DIR=/tmp
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh

SOCK_DIR=/usr/local/var/run/openvswitch
HUGE_DIR=/dev/hugepages
MEM=4096M
#MEM=2048M

function start_test {

    print_phy2phy_banner
    set_dpdk_env
    umount $HUGE_DIR
    echo "Lets bind the ports to the kernel first"
    sudo $DPDK_BIND_TOOL --bind=$KERNEL_NIC_DRV $DPDK_PCI1 $DPDK_PCI2
    sudo rmmod openvswitch
    sudo mkdir -p /usr/local/etc/openvswitch
    sudo mount -t hugetlbfs nodev $HUGE_DIR


    sudo make -C $OVS_DIR modules_install
    sudo modprobe openvswitch
    sudo rm /usr/local/etc/openvswitch/conf.db
    sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema
    sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert --pidfile --detach
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/vswitchd/ovs-vswitchd unix:/usr/local/var/run/openvswitch/db.sock --pidfile --detach --log-file=/var/log/openvswitch/ovs-vswitchd.log -vconsole:err -vsyslog:info -vfile:info

    port1=$(sudo $DPDK_BIND_TOOL --status |grep $DPDK_PCI1 | sed -n 's/.* if=\([a-zA-Z0-9_]\+\).*/\1/p')
    port2=$(sudo $DPDK_BIND_TOOL --status |grep $DPDK_PCI2 | sed -n 's/.* if=\([a-zA-Z0-9_]\+\).*/\1/p')
    if [[ -z  $port1 ]]; then
        echo "PCI device $DPDK_PCI1 is not bound to kernel/not found"
        exit 1
    fi
    if [[ -z $port2 ]]; then
        echo "PCI device $DPDK_PCI2 is not bound to kernel/not found"
        exit 1
    fi
    echo "Switching off the auto-negotiation to avoid rate limiting"
    sudo ip link set dev $port1 down
    sudo ip link set dev $port2 down
    sudo ethtool -A $port1 autoneg off
    sudo ethtool -A $port2 autoneg off
    sudo ethtool -A $port1 rx off
    sudo ethtool -A $port2 tx off

    sudo ip link set dev $port1 up
    sudo ip link set dev $port2 up

    sudo ethtool --show-pause $port1
    sudo ethtool --show-pause $port2
    sudo ifconfig $port1 0
    sudo ifconfig $port2 0
    sudo $OVS_DIR/utilities/ovs-vsctl del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl add-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 $port1
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 $port2
    sudo ifconfig br0 172.16.40.1/24 up
    sudo $OVS_DIR/utilities/ovs-ofctl show br0


    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,action=output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,action=output:1
    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo lsmod|grep 'openvswitch'
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
    sudo ip link set dev br0 down
    sudo ip link del br0
}

function menu {
        echo "launching Switch.."
        kill_switch
        start_test
}

#The function has to get called only when its in subshell.
if [ $OVS_RUN_SUBSHELL -eq 1 ]; then
    menu
fi

