#!/bin/bash -x

# Ipsec testing on Vanilla OVS. verify the logs to make sure the ipsec daemon
# is running in the background. As a prerequisite the ipsec-tools, setkey must
# be installed on the DUT before running the script. This script is not linked
# with python master launcher. OVS must be installed from the .deb before
# running the script. No support for running the script from source.
# Traffic pattern VM --> IPSEC-GRE --> ETH1
# Make sure the VM image present at the given location.


echo $OVS_DIR $DPDK_DIR

OVS_DIR=/home/sugeshch/repo/ovs-apr16
DPDK_DIR=/home/sugeshch/repo/dpdk-apr16
# Variables #
HUGE_DIR=/dev/hugepages


function start_phy_phy {
    echo "Running OVS vanilla":
    sudo modprobe libcrc32c
    sudo modprobe gre 
    sudo modprobe ip_gre 
    sudo modprobe ip6_gre 
    sudo modprobe nf_defrag_ipv6
    sudo tunctl -d tap0
    sudo ovs-vsctl --timeout 10 del-br br0
    sudo ovs-vsctl --timeout 10 add-br br0
    sudo ovs-vsctl --timeout 10 add-port br0 gre1 -- \
    set interface gre1 type=ipsec_gre \
    options:remote_ip=100.0.0.2 options:psk=test
#    options:certificate=cert.pem

    sudo ovs-vsctl --timeout 10 add-br br-phy
    sudo ovs-vsctl --timeout 10 add-port br-phy eth1
    sudo ovs-vsctl --timeout 10 add-port br-phy tep0 -- set interface tep0 type=internal
    sudo ip link set dev tep0 up
    sudo ip addr add 100.0.0.1/24 dev tep0
    sudo ip addr flush dev eth1
    sudo ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,action=output:2
    sudo ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,action=output:1
    sudo ovs-ofctl add-flow br-phy idle_timeout=0,in_port=1,action=output:2    
    sudo ovs-ofctl add-flow br-phy idle_timeout=0,in_port=2,action=output:1
    sudo /home/sugeshch/repo/ovs_dpdk/qemu/x86_64-softmmu/qemu-system-x86_64 -name vm1 -cpu host -enable-kvm -m 4096M -smp 2 -drive file=/home/sugeshch/repo/test_scripts/ovdk_guest_release.qcow2 -net nic,model=virtio,macaddr=00:00:00:00:00:01,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,vhost=on --nographic -snapshot -vnc :5
    sudo ovs-vsctl --timeout 10 add-port br0 tap0 
    sudo ip link set dev tap0 up  
    sudo ovs-vsctl show
}

function kill_switch {
    echo "Killing the switch.."
    sudo ovs-appctl -t ovs-vswitchd exit
    sudo ovs-appctl -t ovsdb-server exit
    sleep 1
    sudo pkill -9 ovs-vswitchd
    sudo pkill -9 ovsdb-server
    sudo pkill -9 python
    sudo umount $HUGE_DIR
    sudo pkill -9 qemu-system-x86_64*
    sudo rm -rf /usr/local/var/run/openvswitch/*
    sudo rm -rf /usr/local/var/log/openvswitch/*
    sudo rm -rf /var/run/openvswitch/*                                
    sudo rm -rf /var/log/openvswitch/*
    sudo pkill -9 pmd*
    sudo rmmod openvswitch
}

function run_test {
    echo "Starting the test "
    start_phy_phy
}

run_test
