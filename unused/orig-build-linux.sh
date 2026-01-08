#!/usr/bin/env bash

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)

source common.sh


case $ARCH in
    x86_64)
        ;;
    i686)
        FFMPEG_CONFIGURE_FLAGS+=(--cc="gcc -m32")
        ;;
    arm64)
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=aarch64-linux-gnu-
            --target-os=linux
            --arch=aarch64
        )
        ;;
    arm*)
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=arm-linux-gnueabihf-
            --target-os=linux
            --arch=arm
        )
        case $ARCH in
            armv7-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv7-a
                )
                ;;
            armv8-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv8-a
                )
                ;;
            armhf-rpi2)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a7
                    --extra-cflags='-fPIC -mcpu=cortex-a7 -mfloat-abi=hard -mfpu=neon-vfpv4 -mvectorize-with-neon-quad'
                )
                ;;
            armhf-rpi3)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a53
                    --extra-cflags='-fPIC -mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mvectorize-with-neon-quad'
                )
                ;;
        esac
        ;;
    *)
        echo "Unknown architecture: $ARCH"
        exit 1
        ;;
esac

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-audio-$ARCH-linux-gnu

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT
extract_ffmpeg $BUILD_DIR

cd $BUILD_DIR


# Build lame
PREFIX=$BASE_DIR/$OUTPUT_DIR
FFMPEG_CONFIGURE_FLAGS+=(--prefix=$PREFIX)



do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame lame_svn
  cd lame_svn
    echo "Compiling lame: prefix $PREFIX"
    CFLAGS="-lm" ./configure --enable-nasm --disable-decoder --prefix=$PREFIX --enable-static --disable-shared --disable-frontend
    make -j8
    make install
  cd ..
echo "compiled LAME... " 


 # build zlib.  this is only working on x86_64

  extract_zlib
  cd zlib-1.2.11
  ./configure --prefix="$PREFIX"
  make
  make install
  cd ..



FFMPEG_CONFIGURE_FLAGS+=(--extra-cflags="-I$PREFIX/include")
FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="-L$PREFIX/lib")

echo "configure ffmpeg: ${FFMPEG_CONFIGURE_FLAGS[@]}"


./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)

make
echo "make complete"
make install
echo "make install complete!"

chown $(stat -c '%u:%g' $BASE_DIR) -R $BASE_DIR/$OUTPUT_DIR


find . $BASE_DIR/$OUTPUT_DIR | grep bin


