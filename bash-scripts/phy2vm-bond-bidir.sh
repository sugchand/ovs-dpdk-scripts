#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
echo $OVS_DIR $DPDK_DIR

# Variables #
HUGE_DIR=/dev/hugepages
SOCK_DIR=/usr/local/var/run/openvswitch
MEM=4096M


function start_test {
    print_phy2vm_bond_banner
    sudo umount $HUGE_DIR
    echo "Lets bind the ports to the kernel first"
    sudo $DPDK_DIR/tools/dpdk-devbind.py -u $DPDK_PCI1 $DPDK_PCI2 $DPDK_PCI3 $DPDK_PCI4
    mkdir -p $HUGE_DIR
    sudo mount -t hugetlbfs nodev $HUGE_DIR

    sudo modprobe uio
    sudo rmmod igb_uio.ko
    sudo insmod $DPDK_DIR/$DPDK_TARGET/kmod/igb_uio.ko
    sudo $DPDK_DIR/tools/dpdk-devbind.py --bind=igb_uio $DPDK_PCI1 $DPDK_PCI2 $DPDK_PCI3 $DPDK_PCI4
    echo "dpdk0 - $DPDK_PCI1"
    echo "dpdk1 - $DPDK_PCI2"
    echo "dpdk2 - $DPDK_PCI3"
    echo "dpdk3 - $DPDK_PCI4"

    echo "USE ONLY NORMAL ACTION. CANNOT USE WITH SPECIFIC OF ACTIONS.."

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
    sleep 22
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0 -- set bridge br0 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl add-bond br0 dpdkbond1 $DPDK_NIC1 $DPDK_NIC2 \
                                                    lacp=active \
                                                    -- set Interface $DPDK_NIC1 type=dpdk options:dpdk-devargs=$DPDK_PCI1 \
                                                    -- set Interface $DPDK_NIC2 type=dpdk options:dpdk-devargs=$DPDK_PCI2
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC1 \
                                -- set Interface $VHOST_NIC1 type=dpdkvhostuser
#    sudo $OVS_DIR/utilities/ovs-vsctl set port dpdkbond1 bond_mode=balance-slb
#    sudo $OVS_DIR/utilities/ovs-vsctl set port dpdkbond1 bond_mode=balance-tcp
    sudo $OVS_DIR/utilities/ovs-vsctl set port dpdkbond1 bond_mode=active-backup
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 actions=NORMAL
    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show

    sleep 5
    echo "launching the VM"
    if [ -z "$VHOST_MAC1" ]; then
        VHOST_MAC1="00:00:00:00:00:01"
    fi
    if [ -z "$VHOST_MAC2"} ]; then
        VHOST_MAC2="00:00:00:00:00:02"
    fi

    sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm1 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp 2 -drive file=$VM_IMAGE -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC1 -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac="$VHOST_MAC1",netdev=mynet1,mrg_rxbuf=off --nographic -snapshot -vnc :5

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
