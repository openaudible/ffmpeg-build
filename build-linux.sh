#!/usr/bin/env bash

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)

source common.sh

if [ -z "${ARCH:-}" ]; then
    ARCH="x86_64"
    echo "Default ARCH=$ARCH"
fi


MUSL_CC=""

case $ARCH in
    x86_64)
        HOST_TRIPLET=""
        CROSS_PREFIX=""
        MUSL_CC="musl-gcc"
        FFMPEG_CONFIGURE_FLAGS+=(--cc="$MUSL_CC")
        FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="-static")
        ;;
    i686)
        HOST_TRIPLET=""
        CROSS_PREFIX=""
        FFMPEG_CONFIGURE_FLAGS+=(--cc="gcc -m32")
        ;;
    arm64)
        HOST_TRIPLET=""
        CROSS_PREFIX=""
        MUSL_CC="musl-gcc"
        FFMPEG_CONFIGURE_FLAGS+=(--cc="$MUSL_CC")
        FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="-static")
        ;;
    arm*)
        HOST_TRIPLET="arm-linux-gnueabihf"
        CROSS_PREFIX="arm-linux-gnueabihf-"
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=$CROSS_PREFIX
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

BUILD_CC="${MUSL_CC:-${CROSS_PREFIX}gcc}"

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-audio-$ARCH-linux-gnu

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT
extract_ffmpeg $BUILD_DIR

cd $BUILD_DIR


# Build lame
PREFIX=$BASE_DIR/$OUTPUT_DIR
FFMPEG_CONFIGURE_FLAGS+=(--prefix=$PREFIX)

# Build lame

# Add static linking flags to ffmpeg
FFMPEG_CONFIGURE_FLAGS+=(--disable-shared --enable-static)
FFMPEG_CONFIGURE_FLAGS+=(--extra-cflags="-I$PREFIX/include")
FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="-L$PREFIX/lib")




do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame lame_svn
  cd lame_svn
    echo "Compiling lame: prefix $PREFIX"
    if [ -n "$HOST_TRIPLET" ]; then
        CC="$BUILD_CC" CFLAGS="-lm" ./configure --host=$HOST_TRIPLET --enable-nasm --disable-decoder --prefix=$PREFIX --enable-static --disable-shared --disable-frontend
    else
        CC="$BUILD_CC" CFLAGS="-lm" ./configure --enable-nasm --disable-decoder --prefix=$PREFIX --enable-static --disable-shared --disable-frontend
    fi
    make -j8
    make install
  cd ..
echo "compiled LAME... " 


 # build zlib

  extract_zlib
  cd zlib-1.2.11
  CC="$BUILD_CC" AR="${CROSS_PREFIX}ar" RANLIB="${CROSS_PREFIX}ranlib" ./configure --prefix="$PREFIX"
  make
  make install
  cd ..



FFMPEG_CONFIGURE_FLAGS+=(--extra-cflags="-I$PREFIX/include")
FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="-L$PREFIX/lib")

echo "configure ffmpeg: ${FFMPEG_CONFIGURE_FLAGS[@]}"


./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)
make clean

make -j8

echo "make complete"
make install
echo "make install complete!"

chown $(stat -c '%u:%g' $BASE_DIR) -R $BASE_DIR/$OUTPUT_DIR


find . $BASE_DIR/$OUTPUT_DIR | grep bin


