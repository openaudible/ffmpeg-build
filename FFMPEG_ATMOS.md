# FFmpeg Dolby Atmos Decoding

This guide covers FFmpeg command-line usage for decoding Dolby Atmos audio formats and building FFmpeg with AC-4 support.

## Supported Atmos Formats

| Format | FFmpeg Codec ID | Official Support | Notes |
|--------|----------------|------------------|-------|
| **E-AC-3** (Dolby Digital Plus Atmos) | `eac3` | ✅ Yes | Built into FFmpeg |
| **AC-4** (Dolby AC-4 Immersive Stereo) | `ac4` | ❌ No | Requires community patch |
| **TrueHD+Atmos** | `truehd` | ✅ Yes | MLP/TrueHD decoder |

## Checking Codec Support

Verify which Atmos codecs your FFmpeg build supports:

```bash
# Check for E-AC-3 decoder (should be present in all builds)
ffmpeg -decoders | grep eac3

# Check for AC-4 decoder (requires patched build)
ffmpeg -decoders | grep ac4

# Check for TrueHD decoder
ffmpeg -decoders | grep truehd
```

Expected output:
```
 A....D eac3                 ATSC A/52 E-AC-3
 A....D ac4                  AC-4 (only if patched)
 A....D truehd               TrueHD
```

## FFmpeg Command Line Examples

### E-AC-3 (Dolby Digital Plus Atmos) Decoding

**Basic conversion to WAV (preserves all channels):**
```bash
ffmpeg -i input.eac3 output.wav
```

**Explicit PCM format (24-bit, 48kHz):**
```bash
ffmpeg -i input.eac3 -acodec pcm_s24le -ar 48000 output.wav
```

**Downmix to stereo:**
```bash
ffmpeg -i input.eac3 -ac 2 output.wav
```

**Extract from MP4/M4B container:**
```bash
ffmpeg -i audiobook.m4b -vn -acodec copy output.eac3
ffmpeg -i output.eac3 -acodec pcm_s16le output.wav
```

**Convert E-AC-3 to AAC (lossy):**
```bash
ffmpeg -i input.eac3 -c:a aac -b:a 192k output.m4a
```

**Convert E-AC-3 to MP3:**
```bash
ffmpeg -i input.eac3 -c:a libmp3lame -q:a 2 output.mp3
```

### AC-4 (Dolby AC-4) Decoding

**Prerequisites:** FFmpeg built with AC-4 patch (see Build Instructions below)

**Basic conversion to WAV:**
```bash
ffmpeg -i input.ac4 output.wav
```

**Extract from MP4/M4B container:**
```bash
ffmpeg -i audiobook.m4b -vn -acodec copy output.ac4
ffmpeg -i output.ac4 -acodec pcm_s16le output.wav
```

**Downmix to stereo:**
```bash
ffmpeg -i input.ac4 -ac 2 output.wav
```

**Note:** AC-4 to MP3 conversion may fail with standard tools. Use AAXClean.Codecs or convert to WAV first.

### TrueHD+Atmos Decoding

**Extract from MKV/MP4:**
```bash
ffmpeg -i input.mkv -map 0:a:0 -c:a copy output.thd
ffmpeg -i output.thd -acodec pcm_s24le output.wav
```

**Direct conversion:**
```bash
ffmpeg -i input.thd output.wav
```

### Advanced Options

**Specify output channel layout:**
```bash
# 5.1 surround
ffmpeg -i input.eac3 -ac 6 output.wav

# Stereo
ffmpeg -i input.eac3 -ac 2 output.wav

# 7.1 surround
ffmpeg -i input.eac3 -ac 8 output.wav
```

**Different PCM bit depths:**
```bash
# 16-bit (CD quality)
ffmpeg -i input.eac3 -acodec pcm_s16le output.wav

# 24-bit (high quality)
ffmpeg -i input.eac3 -acodec pcm_s24le output.wav

# 32-bit float
ffmpeg -i input.eac3 -acodec pcm_f32le output.wav
```

**Sample rate conversion:**
```bash
# Convert to 44.1kHz (CD quality)
ffmpeg -i input.eac3 -ar 44100 output.wav

# Convert to 48kHz (standard)
ffmpeg -i input.eac3 -ar 48000 output.wav

# Convert to 96kHz (high-res)
ffmpeg -i input.eac3 -ar 96000 output.wav
```

## Building FFmpeg with AC-4 Support

AC-4 support requires applying a community patch to FFmpeg source code.

### Quick Build Script

Create `build_ffmpeg_with_ac4.sh`:

```bash
#!/bin/bash
set -e

FFMPEG_VERSION="7.1"
PATCH_URL="https://raw.githubusercontent.com/funnymanva/ffmpeg-with-ac4/main/ffmpeg_ac4.patch"
BUILD_DIR="$HOME/ffmpeg-ac4-build"

echo "Building FFmpeg ${FFMPEG_VERSION} with AC-4 support"

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download FFmpeg source
if [ ! -d "ffmpeg-${FFMPEG_VERSION}" ]; then
    echo "Downloading FFmpeg ${FFMPEG_VERSION}..."
    wget "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
    tar -xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
fi

cd "ffmpeg-${FFMPEG_VERSION}"

# Download and apply AC-4 patch
if [ ! -f ".ac4_patched" ]; then
    echo "Downloading AC-4 patch..."
    wget -O ac4_patch.patch "$PATCH_URL"

    echo "Applying AC-4 patch..."
    patch -p1 < ac4_patch.patch

    touch .ac4_patched
fi

# Configure FFmpeg with AC-4 support
echo "Configuring FFmpeg..."
./configure \
    --prefix="$BUILD_DIR/install" \
    --enable-gpl \
    --enable-nonfree \
    --enable-libfdk-aac \
    --enable-libmp3lame \
    --enable-decoder=eac3 \
    --enable-decoder=ac4 \
    --enable-decoder=truehd \
    --enable-encoder=aac \
    --enable-encoder=libfdk_aac \
    --enable-encoder=libmp3lame

# Build FFmpeg
echo "Building FFmpeg (this may take a while)..."
make -j$(nproc)

# Install to local directory
echo "Installing FFmpeg..."
make install

echo ""
echo "================================================"
echo "FFmpeg built successfully with AC-4 support!"
echo "================================================"
echo "Binary location: $BUILD_DIR/install/bin/ffmpeg"
echo ""
echo "To use this build:"
echo "  $BUILD_DIR/install/bin/ffmpeg -version"
echo ""
echo "To verify AC-4 support:"
echo "  $BUILD_DIR/install/bin/ffmpeg -decoders | grep ac4"
echo ""
echo "Add to PATH (add to ~/.bashrc or ~/.zshrc):"
echo "  export PATH=\"$BUILD_DIR/install/bin:\$PATH\""
```

Make executable and run:
```bash
chmod +x build_ffmpeg_with_ac4.sh
./build_ffmpeg_with_ac4.sh
```

### Manual Build Steps

**1. Install build dependencies:**

Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y build-essential yasm nasm \
    libfdk-aac-dev libmp3lame-dev pkg-config \
    wget tar patch
```

Fedora/RHEL:
```bash
sudo dnf install -y gcc make yasm nasm \
    fdk-aac-devel lame-devel pkgconfig \
    wget tar patch
```

macOS:
```bash
brew install yasm nasm fdk-aac lame pkg-config
```

**2. Download FFmpeg:**
```bash
wget https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz
tar -xf ffmpeg-7.1.tar.xz
cd ffmpeg-7.1
```

**3. Download and apply AC-4 patch:**
```bash
wget -O ac4.patch https://raw.githubusercontent.com/funnymanva/ffmpeg-with-ac4/main/ffmpeg_ac4.patch
patch -p1 < ac4.patch
```

**4. Configure with AC-4 enabled:**
```bash
./configure \
    --enable-gpl \
    --enable-nonfree \
    --enable-libfdk-aac \
    --enable-libmp3lame \
    --enable-decoder=eac3 \
    --enable-decoder=ac4 \
    --enable-decoder=truehd
```

**5. Build and install:**
```bash
make -j$(nproc)
sudo make install
```

**6. Verify installation:**
```bash
ffmpeg -version
ffmpeg -decoders | grep -E "(eac3|ac4|truehd)"
```

### Alternative: Use Pre-built AC-4 FFmpeg

Some projects provide pre-built FFmpeg with AC-4:
- **Kodi builds:** https://github.com/xbmc/FFmpeg (with AC-4 patches)
- **Community builds:** Check https://github.com/funnymanva/ffmpeg-with-ac4/releases

## Integration with AAXClean.Codecs

The AAXClean.Codecs native library uses FFmpeg internally. To use your custom AC-4-enabled FFmpeg build:

**Option 1: System-wide replacement**
```bash
# Replace system FFmpeg with AC-4 build
sudo cp ~/ffmpeg-ac4-build/install/bin/ffmpeg /usr/local/bin/ffmpeg
```

**Option 2: Rebuild AAXClean native library**
```bash
cd AAXClean.Codecs/src/AAXCleanNative

# Edit build_aaxclean_libs.sh to use your patched FFmpeg
# Modify line ~100 to add AC-4 decoder:
# --enable-decoder=ac4

./build_aaxclean_libs.sh
```

## Atmos Metadata and Object Audio

**Important Limitations:**

When decoding Atmos to PCM/WAV with FFmpeg:
- ❌ **Object-based audio metadata is lost** - Atmos spatial positioning data is discarded
- ❌ **Rendered to fixed channel layout** - 5.1, 7.1, or stereo only
- ❌ **Cannot reconstruct Atmos from decoded PCM** - Encoding back to Atmos is not possible

**E-AC-3 Atmos:**
- Contains base 5.1 or 7.1 audio + Atmos metadata objects
- FFmpeg decodes the base audio stream only
- Atmos-capable devices can decode the full spatial audio

**AC-4 Immersive Stereo:**
- Binaural audio optimized for headphones
- Decodes to stereo PCM
- Spatial positioning is baked into the stereo signal

**TrueHD Atmos:**
- Lossless codec with Atmos metadata
- Decodes to 7.1 or 5.1 PCM
- Requires Dolby Reference Player for full Atmos decode

## Troubleshooting

### "Unknown decoder 'ac4'"
Your FFmpeg build doesn't include AC-4 support. Rebuild with the patch (see above).

### "Could not find codec parameters"
The input file may be corrupted or use an unsupported container. Try:
```bash
ffmpeg -i input.m4b -c:a copy -f ac4 output.ac4
```

### Channels are wrong/jumbled
Specify explicit channel layout:
```bash
ffmpeg -i input.eac3 -channel_layout 5.1 output.wav
```

### AC-4 to MP3 fails
AC-4 has limited transcoding support. Convert to WAV first:
```bash
ffmpeg -i input.ac4 temp.wav
ffmpeg -i temp.wav -c:a libmp3lame output.mp3
```

Or use AAXClean.Codecs which has native AC-4 handling.

## References

- **FFmpeg Documentation:** https://ffmpeg.org/documentation.html
- **AC-4 Patch Repository:** https://github.com/funnymanva/ffmpeg-with-ac4
- **FFmpeg Codec List:** https://ffmpeg.org/ffmpeg-codecs.html
- **AAXClean.Codecs:** https://github.com/Mbucari/AAXClean.Codecs
- **Dolby AC-4 Whitepaper:** https://professional.dolby.com/tv/dolby-ac-4/

## License Notes

- **FFmpeg:** LGPL v2.1+ (or GPL v2+ if using GPL components)
- **AC-4 Decoder Patch:** LGPL v2.1+ (Copyright Paul B Mahol, 2019)
- **FDK-AAC:** Permissive license (marked as "nonfree" in FFmpeg)
- **LAME:** LGPL v2.0+

When distributing FFmpeg builds with AC-4:
- Include license files (COPYING.LGPLv2.1, LICENSE.md)
- Provide attribution to patch authors
- Note that FDK-AAC is "nonfree" if included
