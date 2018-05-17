#!/bin/bash -x

# Variables #
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/banner.sh
. ${SRC_DIR}/std_funcs.sh

SOCK_DIR=/usr/local/var/run/openvswitch
HUGE_DIR=/dev/hugepages
MEM=4096M

function core_id_to_mask {
	core_id=$1
    return $[2**($core_id)]
}

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
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="$HUGE_DIR"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="$PMD_CPU_MASK"
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:emc-insert-inv-prob=0          #x => insert 1 per x times, 1 => always. Special 0 => never.
    sudo $OVS_DIR/utilities/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra="-w 0000:05:00.0 --file-prefix=ovs_"

    sudo -E $OVS_DIR/vswitchd/ovs-vswitchd --pidfile unix:/usr/local/var/run/openvswitch/db.sock --log-file -vconsole:err -vsyslog:info -vfile:dbg &
    sleep 22

    #read -n 1 -s -r -p "Press any key to continue"
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 del-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-br br0
    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 set Bridge br0 datapath_type=netdev
    sudo $OVS_DIR/utilities/ovs-ofctl del-flows br0
    #sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 action=NORMAL

    sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 dpdkphy1 \
        -- set Interface dpdkphy1 type=dpdk options:dpdk-devargs=0000:05:00.0 \
        ofport_request=10

	num_vhu_ports=10
    VHOST_NIC=dpdkvhu
	for i in $(seq 1 $num_vhu_ports); do
		id=$(printf "%02d" $i)
		idhex=$(printf "%02X" $i)
		ofport_request=$[20 + $i]
		vhost_ifname=${VHOST_NIC}_$id
        sudo $OVS_DIR/utilities/ovs-vsctl --timeout 10 add-port br0 $vhost_ifname \
        	-- set Interface $vhost_ifname type=dpdkvhostuser options:vhost-server-path="${SOCK_DIR}/$vhost_ifname" \
			ofport_request=$ofport_request
        sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 dl_dst=FE:B1:77:00:00:$idhex,in_port=10,action=output:$ofport_request
        sudo $OVS_DIR/utilities/ovs-ofctl add-flow br0 in_port=$ofport_request,action=output:10
	done

    sudo $OVS_DIR/utilities/ovs-ofctl dump-flows br0
    sudo $OVS_DIR/utilities/ovs-ofctl dump-ports br0
    sudo $OVS_DIR/utilities/ovs-vsctl show
    echo "Finished setting up the bridge, ports and flows..."

	sleep 1

	first_testpmd_core=4
	master_lcore=3
    echo "Starting containers..."
	for i in $(seq 1 $num_vhu_ports); do
		id=$(printf "%02d" $i)
		name=testpmd_$id
		core_mask=$(printf "0x%X" $[2**($first_testpmd_core - 1 + $i) + 2**($master_lcore) ])
    	echo "$name"
		docker run -i -t -d --rm --name $name                      \
           -v /usr/local/var/run/openvswitch/:/var/run/            \
           -v /dev/hugepages/:/dev/hugepages                       \
           -v /opt/billy/ovscont:/opt/billy/ovscont                \
           ubuntu                                                  \
           /opt/billy/ovscont/dpdk/install/bin/testpmd             \
           -c $core_mask -n 1          							   \
           --master-lcore $master_lcore --no-pci                   \
           --vdev=virtio_user0,path=/var/run/dpdkvhu_$id           \
           --socket-mem=1024,1024 --file-prefix=container_${id}_ --   \
           --disable-hw-vlan --port-topology=chained               \
           --forward-mode=macswap -i --auto-start
	done

	read -n 1 -s -r -p "Press any key stop all the containers..."

	#kill all the containers
	for i in $(docker ps -a  --format="{{.Names}}" | grep testpmd); do docker kill $i ; done
}

function kill_switch {
    echo "Stopping OvS"
    std_stop_ovs
    std_stop_db
	return

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

