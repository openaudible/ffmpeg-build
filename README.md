OpenAudible FFmpeg builds
===============================

This fork creates ffmpeg/ffprobe binaries used for OpenAudible, an audibobook management desktop application. 

These binaries only include the codecs, filters, and muxers that are needed for OpenAudible (mp3/m4b/m4a and cover artwork). 

We add a small patch to allow additional metadata in m4a/m4b tags.  

We produce binaries for Linux (x86_64), Mac (universal binary for arm64 and x86_64), and Windows (x86_64 and arm64).

Thank you to AcousticID for their ffmpeg-build github actions. Incredible to build 4 static binaries for ffmpeg in under 6 minutes. 

Building is done using GitHub Actions. You can find the built binaries on the releases page.

Supported platforms:

  - Linux
      * `x86\_64-linux-gnu`
  - Windows
      * `x86_64-w64-mingw32`
      * `arm64-w64-mingw32`
  - macOS
      * Universal binary (supports both x86_64 and arm64 architectures)
      * Compatible with macOS 10.9+ (Intel) and macOS 11+ (Apple Silicon)
