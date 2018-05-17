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
    sudo $OVS_DIR/utilities/ovs-vsctl del-br br1
    sudo $OVS_DIR/utilities/ovs-vsctl del-br br2
    sudo $OVS_DIR/utilities/ovs-vsctl del-br br3
    sudo $OVS_DIR/utilities/ovs-vsctl add-br br1  
	sudo $OVS_DIR/utilities/ovs-vsctl add-br br0                      
	sudo $OVS_DIR/utilities/ovs-vsctl add-br br2                     
	sudo $OVS_DIR/utilities/ovs-vsctl add-br br3                      
	                                                                               
	disable_ipv6 br0                                                               
	disable_ipv6 br1                                                               
	disable_ipv6 br2                                                               
	disable_ipv6 br3                                                               
	                                                                               
	ifconfig br0 up                                                                
	ifconfig br3 up                                                                
	                                                                               
	sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0                                                        
	sudo $OVS_DIR/utilities/ovs-ofctl del-flows br1                                                        
	sudo $OVS_DIR/utilities/ovs-ofctl del-flows br2                                                        
	sudo $OVS_DIR/utilities/ovs-ofctl del-flows br3                                                        
	                                                                               
	sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 $port1
	                                                                               
	sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 p01 -- set interface p01 type=patch options:peer=p10 ofport_request=10
	sudo $OVS_DIR/utilities/ovs-vsctl add-port br1 p10 -- set interface p10 type=patch options:peer=p01 ofport_request=20
	sudo $OVS_DIR/utilities/ovs-vsctl add-port br1 p12 -- set interface p12 type=patch options:peer=p21 ofport_request=30
	sudo $OVS_DIR/utilities/ovs-vsctl add-port br2 p21 -- set interface p21 type=patch options:peer=p12 ofport_request=40
	sudo $OVS_DIR/utilities/ovs-vsctl add-port br2 p23 -- set interface p23 type=patch options:peer=p32 ofport_request=50
	sudo $OVS_DIR/utilities/ovs-vsctl add-port br3 p32 -- set interface p32 type=patch options:peer=p23 ofport_request=60
                                                                               
	sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 "in_port=1,actions=dec_ttl,output:p01"                  
	sudo $OVS_DIR/utilities/ovs-ofctl add-flow br1 in_port=p10,actions=p12                                 
#	sudo $OVS_DIR/utilities/ovs-ofctl add-flow br2 -OOpenFlow13 "in_port=p21,ip,actions=dec_ttl,dec_ttl,dec_ttl,dec_ttl,output:LOCAL,dec_ttl,mod_dl_src:aa:aa:aa:bb:bb:ff,encap(ethernet),dec_ttl,output:p23"
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br2 -O OpenFlow13 "in_port=p21,actions=mod_dl_dst=FF:FF:FF:FF:FF:FF,output:p23"
	sudo $OVS_DIR/utilities/ovs-ofctl add-flow br3 "in_port=p32,actions=LOCAL"                             
                                                                               
	sudo $OVS_DIR/utilities/ovs-appctl ofproto/trace br0 'in_port=1,ip'                                    
                                          
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

