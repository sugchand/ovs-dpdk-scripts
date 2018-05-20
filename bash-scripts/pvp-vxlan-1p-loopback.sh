#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh
echo $OVS_DIR $DPDK_DIR

# Variables #
HUGE_DIR=/dev/hugepages
TMUX_VM_SESSION=vm_session
MEM=4096M
SOCK_DIR=/usr/local/var/run/openvswitch
SSH_PORT=10022

print_pvp_1p_vxlan_banner() {
cat <<"EOT"

<<<<<<<<<<<<<<<< PHY1 ==> VM ==> PHY1 >>>>>>>>>>>>>>>>>>>

                           {pop_vxlan}
{vxlan 1000} ==> DPDK_NIC2 ==> OVS ==> vhostuser0 ==> VM


               {push_vxlan,1000}
VM ==> vhostuser1 ==> OVS ==> DPDK_NIC2 ==> {vxlan 1000}


**********************************************************
                 VXLAN input traffic
**********************************************************

                   ------          
dl_src=00:00:64:00:00:02 |         
                         |         
dl_dst=00:00:64:00:00:01 |         
                         |       \ 
nw_src=10.0.0.2          | ------ >
                         |       / 
nw_dst=10.0.0.1          |         
                         |         
vni=1000                 |         
                   ------          

**********************************************************

EOT
sleep 3
}

function start_test {
    set_dpdk_env
    std_mount
	std_start_db

    sudo modprobe uio
    sudo rmmod igb_uio.ko
    sudo insmod $DPDK_IGB_UIO
    sudo $DPDK_BIND_TOOL --bind=igb_uio $DPDK_PCI2

    print_pvp_1p_vxlan_banner

    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=$DPDK_LCORE_MASK
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem=$DPDK_SOCKET_MEM
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"

	sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0 -- set bridge br0 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC1 -- set Interface $VHOST_NIC1 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl add-port br0 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=10.0.0.2 options:key=1000

    echo "creating the external bridge"
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br-phy
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br-phy -- set Bridge br-phy datapath_type=netdev

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set bridge br-phy other_config:hwaddr=00:00:64:00:00:01
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br-phy $DPDK_NIC2 -- set Interface $DPDK_NIC2 type=dpdk options:dpdk-devargs=$DPDK_PCI2 options:n_rxq=2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Interface $DPDK_NIC2 type=dpdk

    sudo ip addr add 10.0.0.1/24 dev br-phy
    sudo ip link set br-phy up
    sudo iptables -F
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 10.0.0.1/24 br-phy
    sudo $OVS_DIR/utilities/ovs-appctl ovs/route/add 0.0.0.0 br0
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br0 10.0.0.1 00:00:64:00:00:01
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy 10.0.0.2 00:00:64:00:00:02
    sudo $OVS_DIR/utilities/ovs-appctl tnl/arp/set br-phy 10.0.0.20 20:20:10:10:10:10

    echo "Installing flows..."
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,action=output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,action=output:1

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy idle_timeout=0,in_port=1,action=output:LOCAL
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br-phy idle_timeout=0,in_port=LOCAL,action=output:1

    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0

    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br-phy
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br-phy
    sudo $OVS_DIR/utilities/ovs-vsctl show


    sudo pkill -9 qemu-system-x86_64

    command -v tmux
    if [ $? -ne 0 ]; then
        echo "*** ERROR : Cannot start VM, tmux binary is missing ***"
        return
    fi
    tmux kill-session -t $TMUX_VM_SESSION
    echo "***  Setting up the VM in a TMUX session, ***"

    tmux new -d -s $TMUX_VM_SESSION "sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 \
    -name vm1 -cpu host -enable-kvm -m $MEM \
    -netdev user,id=nttsip,hostfwd=tcp::${SSH_PORT}-:22 \
    -device e1000,netdev=nttsip,mac=AA:BB:CC:DD:EE:FF \
    -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on \
    -numa node,memdev=mem -mem-prealloc -smp 2 \
    -drive file=$VM_IMAGE \
    -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC1 \
    -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce \
    -device virtio-net-pci,mac=DE:AD:BE:EF:00:01,netdev=mynet1,mrg_rxbuf=off \
    --nographic -vnc :5"

    echo " *** VM is running on tmux-session $TMUX_VM_SESSION ***"
    echo " *** Log into the VM at 'tmux a -t $TMUX_VM_SESSION' ***"

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

#The function has to get called only when its in subshell.
if [ "$OVS_RUN_SUBSHELL" == "1" ]; then
    menu
fi


