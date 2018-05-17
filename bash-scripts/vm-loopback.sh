#!/bin/bash -x

# Variables #
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh

SOCK_DIR=/usr/local/var/run/openvswitch
HUGE_DIR=/mnt/huge
MEM=4096M

function start_test {
    set_dpdk_env
    sudo umount $HUGE_DIR
    sudo mount -t hugetlbfs nodev $HUGE_DIR
    sudo rm $SOCK_DIR/$VHOST_NIC1
    sudo rm $SOCK_DIR/$VHOST_NIC2

    sudo modprobe uio
    sudo rmmod igb_uio.ko
    sudo insmod $DPDK_IGB_UIO

    #sudo rm /usr/local/etc/openvswitch/conf.db
    #sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema
    std_start_db

    #sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="$DPDK_LCORE_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,0"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"

    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
# sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --dpdk -vhost_sock_dir /tmp -c 0x2 -n 4 --socket-mem=2048,0 -- --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sleep 10
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Bridge br0 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC1 -- set Interface $VHOST_NIC1 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC2 -- set Interface $VHOST_NIC2 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,action=output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,action=output:1 # bidi
   sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."

    sleep 5
    echo "launching the VM"
    sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm1 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp cpus=4 -drive file=$VM_IMAGE -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC1 -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1,mrg_rxbuf=off -chardev socket,id=char2,path=$SOCK_DIR/$VHOST_NIC2 -netdev type=vhost-user,id=mynet2,chardev=char2,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:02,netdev=mynet2,mrg_rxbuf=off --nographic -vnc :5 &
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

