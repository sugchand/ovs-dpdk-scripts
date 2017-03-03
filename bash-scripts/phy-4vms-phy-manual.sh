#!/bin/bash -x

# Variables #
SOCK_DIR=/usr/local/var/run/openvswitch
HUGE_DIR=/dev/hugepages
MEM=3072M
VHOST_NIC3=dpdkvhostuser2
VHOST_NIC4=dpdkvhostuser3
VHOST_NIC5=dpdkvhostuser4
VHOST_NIC6=dpdkvhostuser5
VHOST_NIC7=dpdkvhostuser6                                                       
VHOST_NIC8=dpdkvhostuser7

function start_test {
    sudo umount $HUGE_DIR
    echo "Lets bind the ports to the kernel first"
    echo -e "Running 4 PHY-VM-PHY bidirectional test"
    echo -e "CPU MASKs\n VM1 :- 4,5 \n VM2 :- 6,7 \n VM3 :- 8,9 \n VM4 :- 10,11"
    echo -e "Target traffic streams with dst_macs \n 
    --> 00:00:00:00:00:01, 00:00:00:00:00:02, 00:00:00:00:00:03, 00:00:00:00:00:04 
    \n   <-- 00:00:00:00:01:01, 00:00:00:00:01:02, 00:00:00:00:01:03, 00:00:00:00:01:04"
    sudo $DPDK_DIR/tools/dpdk-devbind.py --bind=$KERNEL_NIC_DRV $DPDK_PCI1 $DPDK_PCI2

    sudo mount -t hugetlbfs nodev $HUGE_DIR
    sudo rm $SOCK_DIR/$VHOST_NIC1
    sudo rm $SOCK_DIR/$VHOST_NIC2

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
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC3 -- set Interface $VHOST_NIC3 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC4 -- set Interface $VHOST_NIC4 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC5 -- set Interface $VHOST_NIC5 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC6 -- set Interface $VHOST_NIC6 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC7 -- set Interface $VHOST_NIC7 type=dpdkvhostuser
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $VHOST_NIC8 -- set Interface $VHOST_NIC8 type=dpdkvhostuser

    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,dl_dst=00:00:00:00:00:01,action=output:3
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=3,action=output:1 # bidi
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,dl_dst=00:00:00:00:01:01,action=output:4
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=4,action=output:2 # bidi

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,dl_dst=00:00:00:00:00:02,action=output:5
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=5,action=output:1 # bidi
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,dl_dst=00:00:00:00:01:02,action=output:6
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=6,action=output:2 # bidi

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,dl_dst=00:00:00:00:00:03,action=output:7
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=7,action=output:1 # bidi
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,dl_dst=00:00:00:00:01:03,action=output:8
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=8,action=output:2 # bidi

    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,dl_dst=00:00:00:00:00:04,action=output:9
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=9,action=output:1 # bidi
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,dl_dst=00:00:00:00:01:04,action=output:10
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=10,action=output:2 # bidi

    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."

    sleep 5
    echo "launching the VM-1, VNC:5"
    sudo taskset 0x00000030 sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm1 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp cpus=2,cores=2 -drive file=$VM_IMAGE -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC1 -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1,mrg_rxbuf=off -chardev socket,id=char1,path=$SOCK_DIR/$VHOST_NIC2 -netdev type=vhost-user,id=mynet2,chardev=char1,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:10,netdev=mynet2,mrg_rxbuf=off --nographic -snapshot -vnc :5 &
    sleep 5
    echo "launching the VM-2, VNC:6"
    sudo taskset 0x000000C0 sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm2 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp cpus=2,cores=2 -drive file=$VM_IMAGE -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC3 -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:02,netdev=mynet1,mrg_rxbuf=off -chardev socket,id=char1,path=$SOCK_DIR/$VHOST_NIC4 -netdev type=vhost-user,id=mynet2,chardev=char1,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:20,netdev=mynet2,mrg_rxbuf=off --nographic -snapshot -vnc :6 &
    sleep 5
    echo "launching the VM-3, VNC:7"
    sudo taskset 0x00000300 sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm3 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp cpus=2,cores=2 -drive file=$VM_IMAGE -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC5 -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:03,netdev=mynet1,mrg_rxbuf=off -chardev socket,id=char1,path=$SOCK_DIR/$VHOST_NIC6 -netdev type=vhost-user,id=mynet2,chardev=char1,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:30,netdev=mynet2,mrg_rxbuf=off --nographic -snapshot -vnc :7 &
    sleep 5
    echo "launching the VM-4, VNC:8"
    sudo taskset 0x00000C00 sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm4 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp cpus=2,cores=2 -drive file=$VM_IMAGE -chardev socket,id=char0,path=$SOCK_DIR/$VHOST_NIC7 -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:04,netdev=mynet1,mrg_rxbuf=off -chardev socket,id=char1,path=$SOCK_DIR/$VHOST_NIC8 -netdev type=vhost-user,id=mynet2,chardev=char1,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:40,netdev=mynet2,mrg_rxbuf=off --nographic -snapshot -vnc :8 &

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

