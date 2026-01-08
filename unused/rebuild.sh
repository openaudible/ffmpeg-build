#!/usr/bin/env bash

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)


source common.sh

ARCH=x86_64
host=x86_64-w64-mingw32

: ${ARCH?}

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-audio-$ARCH-win
APP_DIR=$BASE_DIR/nas/win_$ARCH
echo "$APP_DIR"


# BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
# TODO: PUT BACK IN trap 'rm -rf $BUILD_DIR' EXIT
BUILD_DIR=$BASE_DIR/build_win_$ARCH



cd $BUILD_DIR
# tar --strip-components=1 -xf $BASE_DIR/$FFMPEG_TARBALL


PREFIX=$BASE_DIR/$OUTPUT_DIR

FFMPEG_CONFIGURE_FLAGS+=(
    --prefix=$PREFIX
    --extra-ldflags=-L$PREFIX/lib
    --target-os=mingw32
    --arch=$ARCH
    --cross-prefix=$ARCH-w64-mingw32-
    --extra-cflags="-static -static-libgcc -static-libstdc++ -I$PREFIX/include"

)


# Build lame


echo "configure ffmpeg: ${FFMPEG_CONFIGURE_FLAGS[@]}"


./configure "${FFMPEG_CONFIGURE_FLAGS[@]}"
make -j8
make install

chown $(stat -c '%u:%g' $BASE_DIR) -R $BASE_DIR/$OUTPUT_DIR
echo "Done. BASE_DIR=$BASE_DIR OUTPUT_DIR=$OUTPUT_DIR pwd=`pwd` copying to nas."
set -e
ls $BUILD_DIR/*exe
cp $BUILD_DIR/*.exe $APP_DIR/

# cp "$OUTPUT_DIR"/bin/ff*exe $APP_DIR


