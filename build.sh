#!/bin/bash

start_time=$(date +%s)

rm -rf out
cd ../../
MAINPATH=$PWD
KERNEL_DIR=$MAINPATH/kernel
KERNEL_PATH=$KERNEL_DIR/kernel_xiaomi_sm8250

CLANG_DIR=$KERNEL_DIR/clang

check_and_wget() {
    local dir=$1

    if [ ! -d "$dir" ]; then
        echo "Foler $dir not found downloading $repo."
        mkdir $dir
        cd $dir
        wget $(curl -s https://raw.githubusercontent.com/ZyCromerZ/Clang/refs/heads/main/Clang-main-link.txt) -O clang.tar.gz
        tar -zxvf clang.tar.gz
        rm -rf clang.tar.gz
        cd ../kernel_xiaomi_sm8250
    fi
}

check_and_wget $CLANG_DIR

PATH=$CLANG_DIR/bin:$PATH
export PATH
export ARCH=arm64

WAIFU_DIR="$KERNEL_DIR/Waifu"

if [ ! -d "$WAIFU_DIR" ]; then
    mkdir -p "$WAIFU_DIR"
    
    if [ ! -d "$WAIFU_DIR/Anykernel" ]; then
        git clone https://github.com/y82t2z/Anykernel.git "$WAIFU_DIR/Anykernel"
        
        mv "$WAIFU_DIR/Anykernel/"* "$WAIFU_DIR/"
        
        rm -rf "$WAIFU_DIR/Anykernel"
    fi
else
    if [ -d "$WAIFU_DIR/.git" ]; then
        rm -rf "$WAIFU_DIR/.git"
    fi
fi

export IMGPATH="$WAIFU_DIR/Image"
export DTBPATH="$WAIFU_DIR/dtb"
export DTBOPATH="$WAIFU_DIR/dtbo.img"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"
export KBUILD_BUILD_USER="y82t2z"
export KBUILD_BUILD_HOST="NekoLabs"
export DEVICE="alioth"

BUILD_DATE=$(date '+%Y-%m-%d_%H-%M-%S')

cd $KERNEL_PATH

output_dir=out

make O="$output_dir" kernel-alioth_defconfig

    make -j $(nproc) \
                O="$output_dir" \
                CC="ccache clang" \
                HOSTCC=gcc \
                LD=ld.lld \
                AS=llvm-as \
                AR=llvm-ar \
                NM=llvm-nm \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip \
                LLVM=1 \
                LLVM_IAS=1 \
                V=$VERBOSE 2>&1 | tee build.log
                

find $DTS -name '*.dtb' -exec cat {} + > $DTBPATH
find $DTS -name 'Image' -exec cat {} + > $IMGPATH
find $DTS -name 'dtbo.img' -exec cat {} + > $DTBOPATH

end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

export CHATID="-1002357202394"
export TGTOKEN="7266800533:AAE3IH2ih8UGmBXv4ynDdT-o3O1xii-xG0c"

if grep -q -E "Error 2" build.log; then
    cd "$KERNEL_PATH"
    echo "Error: Build completed with errors"

    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendMessage \
    -d chat_id="$CHATID" \
    -d text="Compilation error!"

    curl -s -X POST "https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=$CHATID" \
    -F document=@"./build.log"

else
    echo "Total execution time: $elapsed_time seconds"
    # Move to MagicTime directory and create archive
    cd "$WAIFU_DIR"
    7z a -mx9 Waifu-$DEVICE-$BUILD_DATE.zip * -x!*.zip
    
    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendMessage \
    -d chat_id="$CHATID" \
    -d text="Compilation completed successfully! Execution time: $elapsed_time seconds"

    curl -s -X POST "https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=$CHATID" \
    -F document=@"./Waifu-$DEVICE-$BUILD_DATE.zip" \"

fi