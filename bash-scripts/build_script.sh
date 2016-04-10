#!/bin/bash -x

# Directories #
OVS_DIR=/home/sugeshch/repo/ovs_dpdk/ovs_dpdk
DPDK_DIR=/home/sugeshch/repo/dpdk_master
QEMU_DIR=/home/sugeshch/repo/ovs_dpdk/qemu

if [ "$#" -ne 1 ]; then
	echo "invalid option, please provide all|ovs|qemu|dpdk|dpdk_ivshm|vanila|vanila_prefix|clean"
	exit 0
fi

key="$1"

function clean_repo {
    echo "Cleaning DPDK..."
    cd $DPDK_DIR && \
    make uninstall
    cd $OVS_DIR && \
    make clean
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
    make distclean && \
	./boot.sh && \
	./configure --with-linux=/lib/modules/`uname -r`/build && \
	if [ $? -ne 0 ]; then
		echo "Cannot compile, configure failed.."
		return
	fi
	make -j 20
	echo "Vanila OVS build completed"
}

function build_vanila_ovs_prefix {
    echo "Now building Vanila OVS with prefix /usr and /var"
    cd $OVS_DIR && \
    make distclean && \
    ./boot.sh && \
    ./configure --prefix=/usr --localstatedir=/var \
	--with-linux=/lib/modules/`uname -r`/build && \
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return
    fi
    make -j 20
    echo "Vanila OVS build with prefix completed"
}

function build_ovs_default {
    cd $OVS_DIR
	make -j 20 CFLAGS="-Ofast -march=native"
    echo "OVS build completed...."
}

function build_ovs_gcc {
    target="x86_64-native-linuxapp-gcc"
    echo "Now Building OVS...."
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure CFLAGS="-g" --with-dpdk=$DPDK_DIR/$target/
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return
    fi
    make -j 20 CFLAGS="-Ofast -march=native"
    echo "OVS build completed...."
}

function build_ovs {
    target="x86_64-native-linuxapp-gcc"
    echo "Now Building OVS...."
    cd $OVS_DIR && \
    ./boot.sh && \
    ./configure --with-dpdk=$DPDK_DIR/$target/
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return
    fi
    make -j 20 CFLAGS="-Ofast -march=native"
    echo "OVS build completed...."
}

function build_qemu {
	#Build Qemu, please build with 2.2 qemu version as it has userspace vhost
	echo "Now Building QEMU...."
	cd $QEMU_DIR && \
	./configure --target-list=x86_64-softmmu --enable-kvm &&\
    if [ $? -ne 0 ]; then
        echo "Cannot compile, configure failed.."
        return
    fi
	make -j 20
	echo "QEMU build completed...."
}

case $key in
    dpdk)
    build_dpdk
    ;;
	dpdk_ivshm)
	build_dpdk_ivshm
	;;
	ovs)
	build_ovs
	;;
	qemu)
	build_qemu
	;;
	vanila)
	build_vanila_ovs
	;;
	vanila_prefix)
	build_vanila_ovs_prefix
	;;
	all)
	build_dpdk
	build_ovs
	build_qemu
	;;
    clean)
    clean_repo
    ;;
	*)
	echo "invalid option, please provide all|ovs|qemu|dpdk|vanila|vanila_prefix ..."
	exit 0
	;;
esac

