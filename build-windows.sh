#!/usr/bin/env bash
set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)


source common.sh

: ${ARCH:=x86_64}

if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  host=aarch64-w64-mingw32
  ARCH=aarch64
else
  host=x86_64-w64-mingw32
  ARCH=x86_64
fi

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-audio-$ARCH-win
set -e

BUILD_DIR=$BASE_DIR/build_win_$ARCH
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR


# Automatic delete build dir. Optional
# trap 'rm -rf $BUILD_DIR' EXIT

echo "extract: "
extract_ffmpeg $BUILD_DIR

cd $BUILD_DIR


PREFIX=$BASE_DIR/$OUTPUT_DIR
CROSS_PREFIX="$ARCH-w64-mingw32-"

FFMPEG_CONFIGURE_FLAGS+=(
    --prefix=$PREFIX
    --extra-ldflags=-L$PREFIX/lib
    --target-os=mingw32
    --arch=$ARCH
    --cross-prefix=$CROSS_PREFIX
    --extra-cflags="-static -static-libgcc -static-libstdc++ -I$PREFIX/include"

)
  
# Build lame

do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame lame_svn
  cd lame_svn
    echo "Compiling lame: prefix $PREFIX"
    ./configure --disable-decoder --prefix=$PREFIX --enable-static --disable-shared --host=$host
    make -j8
    make install
  cd ..
echo "compiled LAME... "

# Build zlib

  PREFIXDIR="$PREFIX"
  echo "building zlib prefixdir=$PREFIXDIR CROSSPREFIX=$CROSS_PREFIX"
  extract_zlib
  cd zlib-1.2.11

  if [ "$ARCH" = "aarch64" ]; then
    # Use configure for ARM64 (llvm-mingw compatibility)
    CC="${CROSS_PREFIX}gcc" AR="${CROSS_PREFIX}ar" RANLIB="${CROSS_PREFIX}ranlib" ./configure --prefix=$PREFIXDIR --static
    make -j8
    make install
  else
    # Use win32 Makefile for x86_64
    make -f win32/Makefile.gcc BINARY_PATH=$PREFIXDIR/bin INCLUDE_PATH=$PREFIXDIR/include LIBRARY_PATH=$PREFIXDIR/lib SHARED_MODE=0 PREFIX="$CROSS_PREFIX" install
  fi
  cd ..


echo "configure ffmpeg: ${FFMPEG_CONFIGURE_FLAGS[@]}"


./configure "${FFMPEG_CONFIGURE_FLAGS[@]}"
make -j8
make install

chown $(stat -c '%u:%g' $BASE_DIR) -R $BASE_DIR/$OUTPUT_DIR
