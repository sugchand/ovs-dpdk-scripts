#!/bin/bash -x

# Variables #
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh

SOCK_DIR=/usr/local/var/run/openvswitch
HUGE_DIR=/dev/hugepages
MEM=4096M


function start_test {
    echo ${BASH_SOURCE[0]} ${FUNCNAME[0]}
    set_dpdk_env
    #sudo umount $HUGE_DIR
    #mkdir -p $HUGE_DIR
    #sudo mount -t hugetlbfs nodev $HUGE_DIR

    std_start_db

    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="$DPDK_LCORE_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="$DPDK_SOCKET_MEM"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:emc-insert-inv-prob=1          #x => insert 1 per x times, 1 => always. Special 0 => never.
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra="-w 0000:05:00.0 -w 0000:05:00.1 -w 0000:05:00.2 -w 0000:05:00.3 --file-prefix=bom"

    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file -vconsole:err -vsyslog:info -vfile:info &
    sleep 22

    set -x
    #read -n 1 -s -r -p "Press any key to continue"
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Bridge br0 datapath_type=netdev

    VHOST_NIC=dpdkvh
    for i in {1..6}; do
        sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 ${VHOST_NIC}$i \
            -- set Interface ${VHOST_NIC}$i type=dpdkvhostuserclient options:vhost-server-path="${SOCK_DIR}/${VHOST_NIC}$i"
    done

    #read -n 1 -s -r -p "Press any key to continue"
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 action=NORMAL

    #read -n 1 -s -r -p "Press any key to continue"
    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."

    sleep 5
    return

    echo "launching the VMs"
    #sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 \
    #  -name us-vhost-vm1 -cpu host -enable-kvm -m $MEM \
    #  -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on \
    #  -numa node,memdev=mem -mem-prealloc -smp 2 \
    #  -drive file=$VM_IMAGE \
    #  \
    #  -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC1,server \
    #  -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce \
    #  -device virtio-net-pci,mac=00:00:00:00:01:01,netdev=mynet1,mrg_rxbuf=off \
    #  \
    #  --nographic -snapshot -vnc :1

    #sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 \
    #  -name us-vhost-vm2 -cpu host -enable-kvm -m $MEM \
    #  -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on \
    #  -numa node,memdev=mem -mem-prealloc -smp 2 \
    #  -drive file=$VM_IMAGE \
    #  \
    #  -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC2,server \
    #  -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce \
    #  -device virtio-net-pci,mac=00:00:00:00:02:01,netdev=mynet1,mrg_rxbuf=off \
    #  \
    #  --nographic -snapshot -vnc :2
}

function kill_switch {
    echo "Killing the switch.."
    sudo $OVS_DIR/utilities/ovs-appctl -t ovs-vswitchd exit
    sudo $OVS_DIR/utilities/ovs-appctl -t ovsdb-server exit
    sleep 1
    sudo pkill -9 ovs-vswitchd
    sudo pkill -9 ovsdb-server
    #sudo umount $HUGE_DIR
    #sudo pkill -9 qemu-system-x86_64*
    #sudo rm -rf /usr/local/var/run/openvswitch/*
    #sudo rm -rf /usr/local/var/log/openvswitch/*
    #sudo pkill -9 pmd*
}

function menu {
        echo "launching Switch.."
        start_test
}

#The function has to get called only when its in subshell.
if [ "$OVS_RUN_SUBSHELL" == "1" ]; then
    menu
fi

