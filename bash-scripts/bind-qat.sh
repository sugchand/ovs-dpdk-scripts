#!/bin/bash -x

if [ -z "$DPDK_DIR" ]; then
    echo "The DPDK directory not set, exiting.."
    exit 1
fi

[[ `id -u` -eq 0 ]] || { echo "Must be root to run script"; exit 1; }
echo $OVS_DIR $DPDK_DIR
rmmod qat_dh895xccvf
rmmod qat_dh895xcc
rmmod intel_qat
modprobe intel_qat
modprobe qat_dh895xcc
modprobe qat_dh895xccvf
modprobe uio
rmmod igb_uio.ko
insmod $DPDK_DIR/$DPDK_TARGET/kmod/igb_uio.ko

PF_PCI=$(lspci -d :435 | cut -d ' ' -f1)
echo "The QAT card found at $PF_PCI"
PF_PCI=$(echo $PF_PCI | cut -d ':' -f1)
echo 32 > /sys/bus/pci/drivers/dh895xcc/0000\:${PF_PCI}\:00.0/sriov_numvfs
for device in $(seq 1 4); do for fn in $(seq 0 7); do echo -n 0000:${PF_PCI}:0${device}.${fn} >  /sys/bus/pci/devices/0000\:${PF_PCI}\:0${device}.${fn}/driver/unbind; done; done

echo "8086 0443" > /sys/bus/pci/drivers/igb_uio/new_id
lspci -vvd:443
