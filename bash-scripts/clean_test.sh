#!/bin/bash -x

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Variables #
HUGE_DIR=/dev/hugepages
. ${SRC_DIR}/std_funcs.sh

set_dpdk_env

function clean {
    #std_clean
    std_stop_ovs
    std_stop_db
    std_stop_vms

    echo "System cleaned for next test run"
}

#The function has to get called only when its in subshell.
if [ "$OVS_RUN_SUBSHELL" == "1" ]; then
    clean
fi

