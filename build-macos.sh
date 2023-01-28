#!/usr/bin/env bash

set -eu

# TODO: Compile and link LAME using ARCH. Add include/lib paths for LAME to ffmpeg configure flats. Add required LAME to ff

cd $(dirname $0)
BASE_DIR=$(pwd)


# ./build-lame.sh


source common.sh

if [ ! -e $FFMPEG_TARBALL ]
then
	curl -O $FFMPEG_TARBALL_URL
fi

#           - x86_64-apple-macos10.9
#           - arm64-apple-macos11


#: ${TARGET?}

case $TARGET in
    x86_64-*)
        ARCH="x86_64"
	host="x86_64-apple-darwin"
        ;;
    arm64-*)
        ARCH="arm64"
	host="aarch64-apple-darwin"
        ;;
    *)
        echo "Unknown target: $TARGET.  Specifcy TARGET=arm64-apple-macos11 or x86_64-apple-macos10.9"
        exit 1
        ;;
esac

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-audio-$TARGET

# BUILD_DIR=$BASE_DIR/$(mktemp -d workdir.XXXXXXXX)
BUILD_DIR=$BASE_DIR/workdir.$TARGET
rm -rf $BUILD_DIR
mkdir $BUILD_DIR


# TODO: takeout trap 'echo "failed $BUILD_DR " && rm -rf $BUILD_DIR' EXIT

cd $BUILD_DIR
tar --strip-components=1 -xf $BASE_DIR/$FFMPEG_TARBALL
PREFIX=$BASE_DIR/$OUTPUT_DIR
FFMPEG_CONFIGURE_FLAGS+=(
    --cc=/usr/bin/clang
    --prefix=$PREFIX
    --enable-cross-compile
    --target-os=darwin
    --arch=$ARCH
    --extra-ldflags="-target $TARGET -L$PREFIX/lib"
    --extra-cflags="-target $TARGET -I$PREFIX/include"
    --enable-runtime-cpudetect

)



# Build lame
PREFIX=$BASE_DIR/$OUTPUT_DIR


do_svn_checkout https://svn.code.sf.net/p/lame/svn/trunk/lame lame_svn
  cd lame_svn
  LAMEC="--enable-nasm --disable-decoder --enable-frontend --prefix=$PREFIX --enable-static --disable-shared --host=$host --enable-cross-compile --target=$TARGET"
  echo "*** ./configure $LAMEC"

  CFLAGS="-target $TARGET -I$PREFIX/include " ./configure $LAMEC

  make -j8
  make install

  # Here we can test the library file and make sure it is arm64 or x86_64 
  lipo -info $BASE_DIR/$OUTPUT_DIR/lib/libmp3lame.a


  cd ..
echo "compiled LAME...$LAMEC "
echo "pwd=`pwd`"


lipo -info $BASE_DIR/$OUTPUT_DIR/lib/libmp3lame.a

echo "configure ffmpeg: ${FFMPEG_CONFIGURE_FLAGS[@]}"



./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)

perl -pi -e 's{HAVE_MACH_MACH_TIME_H 1}{HAVE_MACH_MACH_TIME_H 0}' config.h

make V=1
make install
find $BASE_DIR/$OUTPUT_DIR 
chown -R $(stat -f '%u:%g' $BASE_DIR) $BASE_DIR/$OUTPUT_DIR
