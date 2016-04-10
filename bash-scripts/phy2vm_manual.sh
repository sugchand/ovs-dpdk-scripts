#!/bin/bash -x

# Directories #
#OVS_DIR=/home/sugeshch/repo/ovs_dpdk/ovs_dpdk
OVS_DIR=/home/sugeshch/repo/ovs_master
DPDK_DIR=/home/sugeshch/repo/dpdk_master
QEMU_DIR=/home/sugeshch/repo/ovs_dpdk/qemu
DPDK_PHY1=0000:05:00.0
DPDK_PHY2=0000:05:00.1
#KERNEL_DRV=i40e
KERNEL_DRV=ixgbe

# Variables #
PORT0_NAME=dpdkvhostuser0
PORT1_NAME=dpdkvhostuser1
# SOCK_DIR=/tmp
SOCK_DIR=/usr/local/var/run/openvswitch
HUGE_DIR=/dev/hugepages
MEM=4096M

sudo umount $HUGE_DIR
echo "Lets bind the ports to the kernel first"
sudo $DPDK_DIR/tools/dpdk_nic_bind.py --bind=$KERNEL_DRV $DPDK_PHY1 $DPDK_PHY2

sudo mount -t hugetlbfs nodev $HUGE_DIR
sudo rm $SOCK_DIR/$PORT0_NAME
sudo rm $SOCK_DIR/$PORT1_NAME

sudo modprobe uio
sudo rmmod igb_uio.ko
sudo insmod $DPDK_DIR/x86_64-native-linuxapp-gcc/kmod/igb_uio.ko
sudo $DPDK_DIR/tools/dpdk_nic_bind.py --bind=igb_uio $DPDK_PHY1 $DPDK_PHY2

sudo rm /usr/local/etc/openvswitch/conf.db
sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema

sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile &
sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --dpdk -c 0x2 -n 4 --socket-mem=2048,0 -- --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
# sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --dpdk -vhost_sock_dir /tmp -c 0x2 -n 4 --socket-mem=2048,0 -- --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
sleep 23
sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0
sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Bridge br0 datapath_type=netdev
sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Open_vSwitch . other_config:pmd-cpu-mask=10
sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 dpdk0 -- set Interface dpdk0 type=dpdk
sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 dpdk1 -- set Interface dpdk1 type=dpdk
sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $PORT0_NAME -- set Interface $PORT0_NAME type=dpdkvhostuser
sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $PORT1_NAME -- set Interface $PORT1_NAME type=dpdkvhostuser
sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,action=output:3
sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=3,action=output:1 # bidi
sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,action=output:4
sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=4,action=output:2 # bidi
sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
sudo $OVS_DIR/utilities/ovs-vsctl show
echo "Finished setting up the bridge, ports and flows..."

read -p "Press enter to continue....to launch vm 1"

# QEMU v2.2.0
sudo -E $QEMU_DIR/x86_64-softmmu/qemu-system-x86_64 -name us-vhost-vm1 -cpu host -enable-kvm -m $MEM -object memory-backend-file,id=mem,size=$MEM,mem-path=$HUGE_DIR,share=on -numa node,memdev=mem -mem-prealloc -smp 2 -drive file=/home/sugeshch/repo/test_scripts/ovdk_guest_release.qcow2 -chardev socket,id=char0,path=$SOCK_DIR/$PORT0_NAME -netdev type=vhost-user,id=mynet1,chardev=char0,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1,mrg_rxbuf=off -chardev socket,id=char1,path=$SOCK_DIR/$PORT1_NAME -netdev type=vhost-user,id=mynet2,chardev=char1,vhostforce -device virtio-net-pci,mac=00:00:00:00:00:02,netdev=mynet2,mrg_rxbuf=off --nographic -snapshot -vnc :5

read -p "Press enter to kill"

sudo $OVS_DIR/utilities/ovs-appctl -t ovs-vswitchd exit
sudo $OVS_DIR/utilities/ovs-appctl -t ovsdb-server exit 
