#!/bin/bash -x

# Directories #

function clean_repo {
    echo "Cleaning DPDK..."
    cd $DPDK_DIR && \
    make uninstall
    cd $OVS_DIR && \
    make clean
    echo "Note:::Uninstalling standard ovs installations too.."
    sudo dpkg -P openvswitch-pki
    sudo dpkg -P openvswitch-ipsec
    sudo dpkg -P openvswitch-switch
    sudo dpkg -P python-openvswitch
    sudo dpkg -P openvswitch-datapath-dkms
    sudo dpkg -P openvswitch-vtep
    sudo dpkg -P openvswitch-dbg
    sudo apt-get remove --auto-remove openvswitch-common
    sudo apt-get purge --auto-remove openvswitch-common
}

function build_dpdk {
    target="x86_64-native-linuxapp-gcc"
    echo "Now Building DPDK...."
    cd $DPDK_DIR && \
    make install -j 20 T=$target \
    CONFIG_RTE_BUILD_COMBINE_LIBS=y CONFIG_RTE_LIBRTE_VHOST=y DESTDIR=install
    echo "DPDK build completed...."
}

function build_dpdk_ivshm {
    echo "Now Building DPDK...."
    target="x86_64-ivshmem-linuxapp-gcc"
    cd $DPDK_DIR && \
    make install -j 20 T=$target CONFIG_RTE_LIBRTE_VHOST=y \
    CONFIG_RTE_BUILD_COMBINE_LIBS=y CONFIG_RTE_LIBRTE_VHOST_USER=y \
    CONFIG_RTE_LIBRTE_IVSHMEM=y DESTDIR=install
    echo "DPDK build completed...."
}

function build_vanila_ovs {
    echo "Now building Vanila OVS"
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure --with-linux=/lib/modules/`uname -r`/build
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20
    ret=$?
    echo "Vanila OVS build completed"
    return $ret
}

function build_vanila_ovs_prefix {
    echo "Now building Vanila OVS with prefix /usr and /var"
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc\
    --with-linux=/lib/modules/`uname -r`/build
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20
    ret=$?
    echo "Vanila OVS build with prefix completed"
    return $ret
}

function build_ovs_default {
    cd $OVS_DIR
    make -j 20 CFLAGS="-Ofast -march=native"
    ret=$?
    echo "OVS build completed...."
    return $ret
}

function build_ovs_gcc {
    target="x86_64-native-linuxapp-gcc"
    echo "Now Building OVS using $DPDK_DIR/$target/"
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure CFLAGS="-g" --with-dpdk=$DPDK_DIR/$target/
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20 CFLAGS="-Ofast -march=native"
    ret=$?
    echo "OVS build completed...."
    return $ret
}

function build_ovs {
    target="x86_64-native-linuxapp-gcc"
    echo "Now Building OVS using $DPDK_DIR/$target/"
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure --with-dpdk=$DPDK_DIR/$target/
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20 CFLAGS="-Ofast -march=native"
    ret=$?
    echo "OVS build completed...."
    return $ret
}

function build_ovs_ivshm {
    target="x86_64-ivshmem-linuxapp-gcc"
    echo "Now Building OVS using $DPDK_DIR/$target/"
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure --with-dpdk=$DPDK_DIR/$target/
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20 CFLAGS="-Ofast -march=native"
    ret=$?
    echo "OVS build completed...."
    return $ret
}

function build_qemu {
    #Build Qemu, please build with 2.2 qemu version as it has userspace vhost
    echo "Now Building QEMU...."
    cd $QEMU_DIR && \
    ./configure --target-list=x86_64-softmmu --enable-kvm
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20
    ret=$?
    echo "QEMU build completed...."
    return $ret
}

function build_check {
    #Build for Linux and DPDK platform, run all the UT, store the reports
    TEST_RESULTS="/tmp/ovs-test.log"
    rm -rf $TEST_RESULTS
    echo "The test report logs stored at $TEST_RESULTS"
    echo "*****Building OVS with Clang*****"
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure CC=clang
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20 2>&1 | tail -10 >> $TEST_RESULTS
    echo "****OVS-CLANG build completed****" >> $TEST_RESULTS 2>&1

    echo "***Now building OVS with linux***"
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure --with-linux=/lib/modules/`uname -r`/build
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20 2>&1 | tail -10 >> $TEST_RESULTS
    echo "***Vanila OVS build completed***" >> $TEST_RESULTS 2>&1

    echo "***Now running UT on OVS+Linux......***" >> $TEST_RESULTS 2>&1
    make check TESTSUITEFLAGS=-j20 2>&1 | tail -30 >> $TEST_RESULTS

    echo "***Now Building OVS using $DPDK_DIR/$DPDK_TARGET/***" \
                                    >> $TEST_RESULTS 2>&1
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure --with-dpdk=$DPDK_DIR/$DPDK_TARGET/
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return 1
    fi
    make -j 20 CFLAGS="-Ofast -march=native" 2>&1 | tail -10 >> $TEST_RESULTS
    echo "***OVS-DPDK build completed....***" >> $TEST_RESULTS 2>&1

    echo "***Now running UT on OVS+DPDK......***" >> $TEST_RESULTS 2>&1
    make check TESTSUITEFLAGS=-j20 2>&1 | tail -30 >> $TEST_RESULTS
}
