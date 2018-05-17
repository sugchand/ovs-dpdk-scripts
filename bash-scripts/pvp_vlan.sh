#!/bin/bash -x

# Variables #
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh

SOCK_DIR=/usr/local/var/run/openvswitch
HUGE_DIR=/dev/hugepages
MEM=4096M

function start_test {
    sudo umount $HUGE_DIR
    echo "Lets bind the ports to the kernel first"
    sudo $DPDK_BIND_TOOL --bind=$KERNEL_NIC_DRV $DPDK_PCI1 $DPDK_PCI2

    sudo mount -t hugetlbfs nodev $HUGE_DIR
    sudo rm $SOCK_DIR/$VHOST_NIC1
    sudo rm $SOCK_DIR/$VHOST_NIC2

    sudo modprobe uio
    sudo rmmod igb_uio.ko
    sudo insmod $DPDK_IGB_UIO
    sudo $DPDK_BIND_TOOL --bind=igb_uio $DPDK_PCI1 $DPDK_PCI2

    print_pvp_vlan_banner
    sudo rm /usr/local/etc/openvswitch/conf.db
    sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema

    sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="$DPDK_LCORE_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="$DPDK_SOCKET_MEM"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"

    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
# sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --dpdk -vhost_sock_dir /tmp -c 0x2 -n 4 --socket-mem=2048,0 -- --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sleep 20
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Bridge br0 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $DPDK_NIC1 -- set Interface $DPDK_NIC1 type=dpdk options:dpdk-devargs=$DPDK_PCI1
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $DPDK_NIC2 -- set Interface $DPDK_NIC2 type=dpdk options:dpdk-devargs=$DPDK_PCI2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC1 -- set Interface $VHOST_NIC1 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC2 -- set Interface $VHOST_NIC2 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl -O OpenFlow13 add-flow br0 idle_timeout=0,in_port=1,dl_vlan=10,actions=pop_vlan,output:3
    sudo $OVS_DIR/utilities/ovs-ofctl -O OpenFlow13 add-flow br0 idle_timeout=0,in_port=3,actions=push_vlan:0x8100,mod_vlan_vid=10,output:1 # bidi
    #sudo $OVS_DIR/utilities/ovs-ofctl -O OpenFlow13 add-flow br0 idle_timeout=0,in_port=2,dl_vlan=20,actions=pop_vlan,output:4 # Using two different dpdk ports.
    #sudo $OVS_DIR/utilities/ovs-ofctl -O OpenFlow13 add-flow br0 idle_timeout=0,in_port=4,actions=push_vlan:0x8100,mod_vlan_vid=20,output:2 # Two different dpdk port.
    sudo $OVS_DIR/utilities/ovs-ofctl -O OpenFlow13 add-flow br0 idle_timeout=0,in_port=1,dl_vlan=20,actions=pop_vlan,output:4 # same/single dpdk port.
    sudo $OVS_DIR/utilities/ovs-ofctl -O OpenFlow13 add-flow br0 idle_timeout=0,in_port=4,actions=push_vlan:0x8100,mod_vlan_vid=20,output:1 # same/single dpdk port.

    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."

    sleep 5
    echo "launching the VM"
    sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm1 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp 2 -drive file=$VM_IMAGE -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC1 -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1,mrg_rxbuf=off -chardev socket,id=char1,path=$SOCK_DIR/$VHOST_NIC2 -netdev type=vhost-user,id=mynet2,chardev=char1,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:02,netdev=mynet2,mrg_rxbuf=off --nographic -snapshot -vnc :5
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

