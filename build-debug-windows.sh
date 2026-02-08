#!/usr/bin/env bash
# Debug build script for local Windows development (MSYS2/MinGW-w64)
# NOT used by GitHub Actions - for local debugging only
#
# Prerequisites:
#   1. Install MSYS2: https://www.msys2.org/
#   2. Open MSYS2 MinGW 64-bit terminal
#   3. Install dependencies:
#      pacman -S mingw-w64-x86_64-toolchain mingw-w64-x86_64-yasm mingw-w64-x86_64-nasm subversion make
#
# Usage:
#   ./build-debug-windows.sh
#
# Then debug with VS Code using the provided launch.json configuration

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)

source common.sh

ARCH=x86_64
host=x86_64-w64-mingw32

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-audio-$ARCH-win-debug
BUILD_DIR=$BASE_DIR/build_win_debug

# Clean previous debug build
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

echo "=== Debug Build for Windows x86_64 ==="
echo "Output: $OUTPUT_DIR"
echo "Build:  $BUILD_DIR"

extract_ffmpeg $BUILD_DIR

cd $BUILD_DIR

PREFIX=$BASE_DIR/$OUTPUT_DIR

# Debug-specific flags
DEBUG_CFLAGS="-g3 -O0 -fno-omit-frame-pointer"
DEBUG_LDFLAGS="-g"

FFMPEG_CONFIGURE_FLAGS+=(
    --prefix=$PREFIX
    --extra-cflags="$DEBUG_CFLAGS -static -static-libgcc -static-libstdc++ -I$PREFIX/include"
    --extra-ldflags="$DEBUG_LDFLAGS -static -static-libgcc -static-libstdc++ -L$PREFIX/lib"
    --target-os=mingw32
    --arch=$ARCH
    --disable-stripping
    --enable-debug=3
    --disable-optimizations
)

# Build lame with debug info
echo "=== Building LAME (debug) ==="
do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame lame_svn
cd lame_svn
CFLAGS="$DEBUG_CFLAGS -Wno-incompatible-pointer-types" ./configure --disable-decoder --prefix=$PREFIX --enable-static --disable-shared --disable-frontend --host=$host
make -j$(nproc)
make install
cd ..
echo "LAME built with debug symbols"

# Build zlib with debug info
echo "=== Building zlib (debug) ==="
extract_zlib
cd zlib-1.2.11
make -f win32/Makefile.gcc CFLAGS="$DEBUG_CFLAGS" BINARY_PATH=$PREFIX/bin INCLUDE_PATH=$PREFIX/include LIBRARY_PATH=$PREFIX/lib SHARED_MODE=0 install
cd ..
echo "zlib built with debug symbols"

# Build ffmpeg with debug info
echo "=== Building FFmpeg (debug) ==="
echo "Configure flags: ${FFMPEG_CONFIGURE_FLAGS[@]}"

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}"
make -j$(nproc)
make install

echo ""
echo "=== Debug build complete ==="
echo "Binaries with debug symbols at: $PREFIX/bin/"
echo ""
echo "To debug in VS Code:"
echo "  1. Open VS Code in this folder"
echo "  2. Set breakpoints in the patched source (e.g., libavformat/movenc.c)"
echo "  3. Press F5 to start debugging"
echo ""
ls -la $PREFIX/bin/
