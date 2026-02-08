# FFmpeg Build System for OpenAudible

Custom FFmpeg builds optimized for audiobook processing. Produces static binaries for multiple platforms via GitHub Actions.

## Quick Start

```bash
# Build for all platforms (requires GitHub Actions)
./build.sh

# Build specific platform locally
./build-linux.sh
./build-macos.sh
./build-windows.sh
```

## Platform Support

- **Linux**: x86_64
- **Windows**: x86_64 and arm64
- **macOS**: Universal binary (Intel + Apple Silicon)

## Key Features

### Built-in Probe Mode

The ffmpeg binary includes embedded ffprobe functionality:

```bash
ffmpeg -probe input.m4b
```

Returns JSON metadata equivalent to `ffprobe -show_format -show_streams -print_format json`. This eliminates the need to ship a separate ffprobe binary, saving ~50% disk space.

### Custom Patches

Three patches modify the upstream FFmpeg 6.1 source:

1. **patch-probe.diff** - Adds `-probe` flag to ffmpeg
   - Embeds ffprobe functionality directly into ffmpeg
   - Outputs JSON format matching ffprobe's default behavior
   - Reduces distribution size by eliminating separate ffprobe binary

2. **patch.diff** - Audiobook metadata extensions
   - Adds custom M4A/M4B tags for audiobook-specific metadata
   - Supports: narrator, publisher, ASIN, series info, release date
   - Enables arbitrary metadata via `atom:XXXX` prefix
   - Essential for OpenAudible's audiobook management features

3. **patch-ac4.diff** - AC-4 audio decoder
   - Adds support for AC-4 (Dolby AC-4) audio codec
   - Used in some audiobook formats

## Build Configuration

- Minimal codec set (mp3, aac, flac, opus, vorbis)
- Static linking for portability
- Optimized for audiobook processing
- No video encoding (decode only for cover art)

## Directory Structure

- `build.sh` - Main build script (orchestrates all platforms)
- `build-*.sh` - Platform-specific build scripts
- `patch.sh` - Applies all patches to FFmpeg source
- `fftools/ffmpeg_probe.c` - Probe mode implementation
- `actions.sh` - GitHub Actions automation

## GitHub Actions

Automated builds triggered by:
- Pushing to `main` branch
- Manual workflow dispatch
- Schedule (if configured)

Built artifacts are published to GitHub Releases.

## Configuration

Modify `common.sh` to adjust:
- FFmpeg version
- Enabled codecs/formats
- Build flags
- Output paths

## Notes

- Binaries are stripped and statically linked
- macOS builds require Xcode command-line tools
- Windows cross-compilation uses MinGW-w64
- Linux builds use Docker for consistent environment
