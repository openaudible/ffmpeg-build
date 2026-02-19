#!/usr/bin/env bash
#
# Debug build script with incremental build support
#
# INCREMENTAL BUILDS:
#   - Uses fixed build directory: build-debug-${ARCH}
#   - Source extraction only happens on first build
#   - Subsequent builds reuse existing sources and compiled objects
#   - Make will only recompile changed files
#
# USAGE:
#   ./debug.sh              # First run: extracts sources, patches, configures, builds
#   ./debug.sh              # Subsequent runs: incremental build (faster)
#   rm -rf build-debug-*    # Force clean build
#   ./clean.sh              # Remove all build directories and artifacts
#
# WORKFLOW:
#   1. Edit source files in build-debug-${ARCH}/
#   2. Run ./debug.sh to rebuild only changed files
#   3. Debug binary appears in artifacts/.../bin/ffprobe
#

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)

source common.sh

ARCH="${ARCH:-x86_64}"

echo "Building FFmpeg with debug symbols (ARCH=$ARCH)..."

case $ARCH in
    x86_64)
        HOST_TRIPLET=""
        CROSS_PREFIX=""
        ;;
    i686)
        HOST_TRIPLET=""
        CROSS_PREFIX=""
        FFMPEG_CONFIGURE_FLAGS+=(--cc="gcc -m32")
        ;;
    *)
        echo "Debug build currently only supports x86_64 and i686"
        exit 1
        ;;
esac

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-audio-$ARCH-linux-gnu

# Check if we need to rebuild dependencies
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Dependencies not found. Running full build first..."
    ./build-linux.sh >/dev/null 2>&1
fi

# Use fixed build directory for incremental builds
BUILD_DIR=$(pwd)/build-debug-$ARCH

# Support incremental builds - only extract if directory doesn't exist
if [ ! -d "$BUILD_DIR" ]; then
    echo "Creating fresh debug build directory: $BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    extract_ffmpeg $BUILD_DIR
else
    echo "Using existing debug build directory: $BUILD_DIR"
    echo "Incremental build: skipping source extraction"
    echo "To force a clean build: rm -rf $BUILD_DIR"
fi

cd $BUILD_DIR

PREFIX=$BASE_DIR/$OUTPUT_DIR
FFMPEG_CONFIGURE_FLAGS+=(--prefix=$PREFIX)

# Add debug symbols
FFMPEG_CONFIGURE_FLAGS+=(--enable-debug=3)
FFMPEG_CONFIGURE_FLAGS+=(--disable-optimizations)
FFMPEG_CONFIGURE_FLAGS+=(--disable-stripping)
FFMPEG_CONFIGURE_FLAGS+=(--extra-cflags="-g -O0")

# Static linking
FFMPEG_CONFIGURE_FLAGS+=(--disable-shared --enable-static)
FFMPEG_CONFIGURE_FLAGS+=(--extra-cflags="-I$PREFIX/include")
FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="-L$PREFIX/lib")

echo "Configuring with debug flags..."

# Configure (redirect output, but show on error)
if ! ./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" >/dev/null 2>&1; then
    echo "❌ Configuration failed!"
    cat ffbuild/config.log
    exit 1
fi

echo "Compiling ffprobe (this may take a few minutes)..."

# Clean and build, only show errors
if ! make clean >/dev/null 2>&1 || ! make -j8 2>&1 | grep -i "error:"; then
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "❌ Build failed!"
        exit 1
    fi
fi

# Install
if ! make install >/dev/null 2>&1; then
    echo "❌ Installation failed!"
    exit 1
fi

echo "✅ Debug build complete: $BASE_DIR/$OUTPUT_DIR/bin/ffprobe"
echo ""
echo "Binary details:"
file "$BASE_DIR/$OUTPUT_DIR/bin/ffprobe" | grep -o "not stripped" && echo "  Debug symbols: present" || echo "  Debug symbols: stripped"
ls -lh "$BASE_DIR/$OUTPUT_DIR/bin/ffprobe" | awk '{print "  Size: " $5}'
