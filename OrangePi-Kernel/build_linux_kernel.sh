#!/bin/bash

# =====================================================
# After build uImage and lib are in build directory
# =====================================================

if [ "${1}" = "" ]; then
    echo "Source directory not specified."
    echo "USAGE: build_linux_kernel.sh [zero | clean]"
    exit 0
fi

export PATH="$PWD/brandy/gcc-linaro/bin":"$PATH"
cross_comp="arm-linux-gnueabi"

# ##############
# Prepare rootfs
# ##############

cd build
rm rootfs-lobo.img.gz  2>&1

# create new rootfs cpio
cd rootfs-test1
mkdir run  2>&1
mkdir -p conf/conf.d 2>&1
find . | cpio --quiet -o -H newc > ../rootfs-lobo.img
cd ..
gzip rootfs-lobo.img
cd ..
#=========================================================
cd linux-3.4
LINKERNEL_DIR=`pwd`

# build rootfs
rm -rf output/*  2>&1
mkdir -p output/lib  2>&1
cp ../build/rootfs-lobo.img.gz output/rootfs.cpio.gz

#==================================================================================
# ############
# Build kernel
# ############

# #################################
# change some board dependant files
cp ../build/sun8iw7p1smp_android_defconfig arch/arm/configs/sun8iw7p1smp_linux_defconfig

# ###########################
if [ "${1}" = "clean" ]; then
    make ARCH=arm CROSS_COMPILE=${cross_comp}- mrproper  2>&1
fi
sleep 1

if [ "${1}" = "zero" ]; then
    echo "Building kernel for OPI-Zero ..."
    echo "  Configuring ..."
    make ARCH=arm CROSS_COMPILE=${cross_comp}- sun8iw7p1smp_linux_defconfig > ../kbuild_zero.log 2>&1
    if [ $? -ne 0 ]; then
        echo "  Error: KERNEL NOT BUILT."
        exit 1
    fi
    sleep 1

# #############################################################################
# build kernel (use -jN, where N is number of cores you can spare for building)
    echo "  Building kernel & modules ..."
    make -j8 ARCH=arm CROSS_COMPILE=${cross_comp}- uImage modules >> ../kbuild_zero.log 2>&1
    if [ $? -ne 0 ] || [ ! -f arch/arm/boot/uImage ]; then
        echo "  Error: KERNEL NOT BUILT."
        exit 1
    fi
    sleep 1
# ########################
# export modules to output
    echo "  Exporting modules ..."
    rm -rf output/lib/*
    make ARCH=arm CROSS_COMPILE=${cross_comp}- INSTALL_MOD_PATH=output modules_install >> ../kbuild_zero.log 2>&1
    if [ $? -ne 0 ] || [ ! -f arch/arm/boot/uImage ]; then
        echo "  Error."
    fi
    echo "  Exporting firmware ..."
    make ARCH=arm CROSS_COMPILE=${cross_comp}- INSTALL_MOD_PATH=output firmware_install >> ../kbuild_zero.log 2>&1
    if [ $? -ne 0 ] || [ ! -f arch/arm/boot/uImage ]; then
        echo "  Error."
    fi
    sleep 1

    # #####################
    # Copy uImage to output
    cp arch/arm/boot/uImage output/uImage
    cd $LINKERNEL_DIR
    cp arch/arm/boot/uImage ../build/uImage
    [ ! -d ../build/lib ] && mkdir ../build/lib
    rm -rf ../build/lib/*
    cp -R output/lib/* ../build/lib

	rm -rf ../../OrangePi-BuildLinux/orange/lib/* 
	cp -rf ../build/lib/* ../../OrangePi-BuildLinux/orange/lib/
    cp -rf ../build/uImage ../../OrangePi-BuildLinux/orange/ 
    cp -rf ../build/uboot/u-boot-sunxi-with-spl.bin ../../OrangePi-BuildLinux/orange/
    cp -rf ../build/uboot/boot.scr ../../OrangePi-BuildLinux/orange/
fi
#==================================================================================

if [ "${1}" = "clean" ]; then
    echo "Cleaning..."
    make ARCH=arm CROSS_COMPILE=${cross_comp}- mrproper  2>&1
    if [ $? -ne 0 ]; then
        echo "  Error."
    fi
    rm -rf ../build/lib/*  2>&1
    rm -f ../build/uImage*  2>&1
    rm -f ../kbuild*  2>&1
    rmdir ../build/lib  2>&1
    rm ../build/rootfs-lobo.img.gz  2>&1
    rm -rf output/*  2>&1
	rm -rf ../../OrangePi-BuildLinux/orange/lib/* 
fi

echo "***OK***"
