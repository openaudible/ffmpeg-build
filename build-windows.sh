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


# build libopus
  extract_opus
  cd opus-$OPUS_VERSION
    echo "Compiling libopus: prefix $PREFIX"
    # opus enables ARM asm + runtime CPU detection by default, but it has no
    # CPU-detection backend for the mingw/UCRT arm64 target and fails to build
    # (celt/arm/armcpu.c). Disable RTCD so it uses the compile-time feature set.
    OPUS_EXTRA=()
    if [ "$ARCH" = "aarch64" ]; then OPUS_EXTRA+=(--disable-rtcd); fi
    CC="${CROSS_PREFIX}gcc" ./configure --host=$host --prefix=$PREFIX --enable-static --disable-shared --disable-doc --disable-extra-programs "${OPUS_EXTRA[@]}"
    make -j8
    make install
  cd ..
echo "compiled libopus... "

# ffmpeg locates libopus via pkg-config. Because --cross-prefix is set, FFmpeg's
# configure looks for "${cross_prefix}pkg-config" (e.g. x86_64-w64-mingw32-pkg-config),
# which doesn't exist, and silently falls back to "false" -> "opus not found".
# Point it at the host pkg-config and at our prefix's .pc files.
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
FFMPEG_CONFIGURE_FLAGS+=(--pkg-config=pkg-config --pkg-config-flags=--static)

if [ "$ARCH" = "aarch64" ]; then
  COMPAT_FLOOR="min_os=windows10,arm64,ucrt,static"
else
  COMPAT_FLOOR="min_os=windows7,x86_64,msvcrt,static"
fi
add_compat_env "$COMPAT_FLOOR"


echo "configure ffmpeg: ${FFMPEG_CONFIGURE_FLAGS[@]}"


./configure "${FFMPEG_CONFIGURE_FLAGS[@]}"
make -j8
make install

chown $(stat -c '%u:%g' $BASE_DIR) -R $BASE_DIR/$OUTPUT_DIR

report_compatibility windows "$PREFIX/bin/ffmpeg.exe" "$COMPAT_FLOOR"
