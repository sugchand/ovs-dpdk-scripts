#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh
echo $OVS_DIR $DPDK_DIR

# Variables #
HUGE_DIR=/dev/hugepages
VF_NICS_BD="0000:05:02"
NUM_VFS=4
PF_BDF=0000:05:00.0

function start_test {

    print_phy2phy_banner
    set_dpdk_env

    sudo umount $HUGE_DIR

    #echo "Lets bind the ports to the kernel first"
    #for vf in {0..3}
	#do
    	#sudo $DPDK_BIND_TOOL --bind=i40evf $VF_NICS_BD.$vf
	#done
   	#sudo $DPDK_BIND_TOOL --bind=i40e $PF_BDF

    mkdir -p $HUGE_DIR
    sudo mount -t hugetlbfs nodev $HUGE_DIR

    #sudo modprobe uio
    #sudo rmmod igb_uio.ko
    #sudo insmod $DPDK_IGB_UIO
    #echo "Lets bind the ports to the kernel first"
    #for vf in {0..3}
	#do
    	#sudo $DPDK_BIND_TOOL --bind=igb_uio $VF_NICS_BD.$vf
	#done
   	#sudo $DPDK_BIND_TOOL --bind=igb_uio $PF_BDF
#
    std_start_db

	set -x

    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait init
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask="$DPDK_LCORE_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:emc-insert-inv-prob=0          #x => insert 1 per x times, 1 => always. Special 0 => never.
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra="-w 0000:05:00.0 -w 0000:05:00.1 -w 0000:05:00.2 -w 0000:05:00.3 --file-prefix=bom"


    #sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file &
    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file -vconsole:err -vsyslog:info -vfile:dbg &
    sleep 22

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0 -- set bridge br0 datapath_type=netdev


    n_rxq=8
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10  add-port br0 dpdk_0 \
		-- set Interface dpdk_0 type=dpdk options:dpdk-devargs=0000:05:00.0 options:n_rxq=$n_rxq
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10  add-port br0 dpdk_1 \
		-- set Interface dpdk_1 type=dpdk options:dpdk-devargs=0000:05:00.1 options:n_rxq=$n_rxq
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10  add-port br0 dpdk_2 \
		-- set Interface dpdk_2 type=dpdk options:dpdk-devargs=0000:05:00.2 options:n_rxq=$n_rxq
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10  add-port br0 dpdk_3 \
		-- set Interface dpdk_3 type=dpdk options:dpdk-devargs=0000:05:00.3 options:n_rxq=$n_rxq

    #n_rxq=8
    #sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10  add-port br0 dpdk_0 \
		#-- set Interface dpdk_0 type=dpdk options:dpdk-devargs=0000:05:00.0 options:n_rxq=$n_rxq \
        #ingress_sched:port_prio=0
    #sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10  add-port br0 dpdk_1 \
		#-- set Interface dpdk_1 type=dpdk options:dpdk-devargs=0000:05:00.1 options:n_rxq=$n_rxq \
        #ingress_sched:port_prio=0
    #sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10  add-port br0 dpdk_2 \
		#-- set Interface dpdk_2 type=dpdk options:dpdk-devargs=0000:05:00.2 options:n_rxq=$n_rxq \
        #ingress_sched:port_prio=0
    #sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10  add-port br0 dpdk_3 \
		#-- set Interface dpdk_3 type=dpdk options:dpdk-devargs=0000:05:00.3 options:n_rxq=$n_rxq \
        #ingress_sched:port_prio=0

    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=2,action=output:1
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=1,action=output:2
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=3,action=output:4
    sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 idle_timeout=0,in_port=4,action=output:3

    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."
	return

    PF_OF_PORT=7
    MAC_BASE=00:00:00:00:00

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 dpdk_pf \
		-- set Interface dpdk_pf type=dpdk ofport_request=$PF_OF_PORT \
		options:dpdk-devargs=$PF_BDF

    for vf in {0..3}
    do
        IFNAME=dpdk_vf_${vf}
        VF_OF_PORT=$((10+$vf))
        VF_MAC=$MAC_BASE:$(printf "%02d" $vf)

        sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $IFNAME \
		    -- set Interface $IFNAME type=dpdk \
            ofport_request=$VF_OF_PORT \
            mac=$VF_MAC \
		    options:dpdk-devargs=${VF_NICS_BD}.${vf}
    done

    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0

    for vf in {0..3}
    do
        VF_OF_PORT=$((10+$vf))
        VF_MAC=$MAC_BASE:$(printf "%02d" $vf)

        sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 \
            idle_timeout=0,in_port=$VF_OF_PORT,action=output:$PF_OF_PORT

        sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 \
            idle_timeout=0,in_port=$PF_OF_PORT,dl_dst=$VF_MAC,action=output:$VF_OF_PORT
    done

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
