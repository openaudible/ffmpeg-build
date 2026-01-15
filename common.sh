#!/usr/bin/env bash
# https://ffmpeg.org/releases/ffmpeg-6.1.tar.xz
FFMPEG_VERSION=6.1
FFMPEG_TARBALL=ffmpeg-$FFMPEG_VERSION.tar.xz
FFMPEG_TARBALL_URL=http://ffmpeg.org/releases/$FFMPEG_TARBALL

do_svn_checkout() {
  repo_url="$1"
  to_dir="$2"
  desired_revision=""
  if [ ! -d $to_dir ]; then
    echo "svn checking out to $to_dir"
    if [[ -z "$desired_revision" ]]; then
      svn checkout -q $repo_url $to_dir.tmp  --non-interactive --trust-server-cert || exit 1
    else
      svn checkout -q -r $desired_revision $repo_url $to_dir.tmp || exit 1
    fi
    mv $to_dir.tmp $to_dir
  else
    cd $to_dir
    echo "not svn Updating $to_dir since usually svn repo's aren't updated frequently enough..."
    # XXX accomodate for desired revision here if I ever uncomment the next line...
    # svn up
    cd ..
  fi
}

extract_zlib()
{
  wget https://github.com/madler/zlib/archive/v1.2.11.tar.gz
  tar -xf v1.2.11.tar.gz
  rm v1.2.11.tar.gz
}

extract_ffmpeg()
{

if [ ! -e $FFMPEG_TARBALL ]
then
	echo "curl get $FFMPEG_TARBALL_URL"
        curl -s -L -O $FFMPEG_TARBALL_URL
fi

cp patch.* $BUILD_DIR

cd $BUILD_DIR

tar --strip-components=1 -xf $BASE_DIR/$FFMPEG_TARBALL


cp ../patch.* .
echo "running patch:"
./patch.sh

#  Apply patch(s)

}

# add the env at the top as a comment about what version and patches were applied
# and are printed when ffmpeg/ffprobe starts (with the rest of the configure flags)
DATE=`date '+%Y%m%d'`
echo "Compile date: $DATE"
BINFO="ffmpeg_vers_$FFMPEG_VERSION,compiled_$DATE,builder_github.com/openaudible/ffmpeg-build"


FFMPEG_CONFIGURE_FLAGS=(
--env=OAINFO="$BINFO"
--disable-everything
--disable-shared
--enable-static
--enable-pic
--disable-xlib
--disable-sdl2
--disable-libxcb
--disable-libxcb-shm
--disable-libxcb-xfixes
--disable-libxcb-shape
--disable-appkit
--disable-avfoundation
--disable-coreimage
--disable-metal
--disable-vulkan
--disable-audiotoolbox
--disable-videotoolbox
--enable-swscale
--enable-libmp3lame
--enable-zlib
--enable-protocol=file
--enable-protocol=pipe
--enable-protocol=concat
--enable-protocol=concatf
--enable-parser=aac
--enable-parser=ac3
--enable-parser=eac3
--enable-demuxer=ffmetadata
--enable-demuxer=mjpeg_2000
--enable-demuxer=image2
--enable-demuxer=smjpeg
--enable-demuxer=aac
--enable-demuxer=aa
--enable-demuxer=concat
--enable-demuxer=mov
--enable-demuxer=mp3
--enable-demuxer=apng
--enable-demuxer=mjpeg
--enable-demuxer=ac3
--enable-demuxer=eac3
--enable-demuxer=truehd
--enable-muxer=ffmetadata
--enable-muxer=mp4
--enable-muxer=mov
--enable-muxer=mp3
--enable-muxer=mjpeg
--enable-muxer=mov
--enable-muxer=apng
--enable-muxer=ipod
--enable-muxer=image2
--enable-encoder=libmp3lame
--enable-encoder=aac
--enable-encoder=ac3
--enable-encoder=png
--enable-encoder=mjpeg
--enable-decoder=png
--enable-decoder=mp3
--enable-decoder=aac
--enable-decoder=mjpeg
--enable-decoder=ac3
--enable-decoder=eac3
--enable-decoder=ac4
--enable-decoder=truehd
--enable-filter=scale
--enable-filter=aformat
--enable-filter=anull
--enable-filter=atrim
--enable-filter=atempo
--enable-filter=format
--enable-filter=null
--enable-filter=setpts
--enable-filter=trim
--enable-filter=aresample
--enable-muxer=wav  # Enable wav muxer
--enable-demuxer=pcm_s16le
--enable-decoder=pcm_s16le
--enable-encoder=pcm_s16le
--enable-decoder=pcm_s24le
--enable-encoder=pcm_s24le
--enable-decoder=pcm_f32le
--enable-encoder=pcm_f32le
--enable-demuxer=wav  # Enable wav demuxer
--enable-parser=pcm_s16le  # Enable PCM S16LE parser
--enable-muxer=pcm_s16le
--enable-ffmpeg
--enable-ffprobe
)


