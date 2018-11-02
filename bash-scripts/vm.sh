#!/usr/bin/env bash

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${SRC_DIR}/../../.ovs-dpdk-script-env
. ${SRC_DIR}/std_funcs.sh

function ifup() {
    set -x
	LOCAL_IP=192.168.8.$[10 + ${VM_ID}]
	ssh -p $SSH_PORT ubuntu@localhost bash -c "'
        sudo ip addr add ${LOCAL_IP}/24 dev eth2
        sudo ip link set dev eth2 up
        echo "Done."
    '"
    set +x
}

function mcast() {
    set -x
	LOCAL_IP=192.168.8.$[10 + ${VM_ID}]
	ssh -p $SSH_PORT ubuntu@localhost bash -c "'
        sudo ip link set eth2 multicast on
        sudo pkill smcrouted
        sudo smcroute -d -f smcroute.conf
        sudo sysctl net.ipv4.icmp_echo_ignore_broadcasts=0
        echo "Done."
    '"
    set +x
}

function join() {
    set -x
	ssh -p $SSH_PORT ubuntu@localhost bash -c "'
        sudo smcroutectl join eth2 225.1.2.3
    '"
    set +x
}

function leave() {
    set -x
	ssh -p $SSH_PORT ubuntu@localhost bash -c "'
        sudo smcroutectl leave eth2 225.1.2.3
    '"
    set +x
}

function ls_() {
    set -x
	ssh -p $SSH_PORT ubuntu@localhost bash -c "'
        sudo ls
    '"
    set +x
}

function usage() {
    echo "Usage: $0 <vm_number> start|if_up|mcast|join|leave"
    echo "   vm_number starts from 0"
}

if [[ $# != 2 || ! ("$1" =~ ^[0-9]+$) ]]; then
    echo "Bad number of params or can't parse <vm_number>"
    usage
    exit 1
fi

VM_ID=$(printf "%d" $1)
VM_ID_HEX=$(printf "%02X" $1)

# Rather than require specification of lots of rarely changing options in calls
# to std_funcs change behaviour by overriding env vars e.g.
# VM_IMAGE=/opt/billy/pri-path-u14.04.fka-vloop.qcow2
# MEM=2G
# VM_NAME=us-vhost-vm_$id
# NUM_CORES=2
# TODO naming convention STD_ARG_VM_MEM ??

# TODO The base ssh port number should really be exported from std_funcs
SSH_PORT=$[2000 + ${VM_ID}]
# TODO naming convention STD_VM_SSH_BASE_PORT ??

case $2 in
    start)
        std_start_vm $VM_ID
        ;;
    ifup|if_up)
        ifup
        ;;
    mcast)
        mcast
        ;;
    join)
        join
        ;;
    leave)
        leave
        ;;
    ls)
        ls_
        ;;
    *)
        echo "'$2' - Bad cmd param"
        usage
        exit 1
        ;;
esac
