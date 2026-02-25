OpenAudible FFmpeg builds
===============================

This fork creates ffmpeg/ffprobe binaries used for OpenAudible, an audibobook management desktop application. 

These binaries only include the codecs, filters, and muxers that are needed for OpenAudible (mp3/m4b/m4a and cover artwork). 

We add a small patch to allow additional metadata in m4a/m4b tags.  

We produce binaries for Linux (x86_64), Mac (universal binary for arm64 and x86_64), and Windows (x86_64 and arm64).

Thank you to AcousticID for their ffmpeg-build github actions. Incredible to build 4 static binaries for ffmpeg in under 6 minutes. 

Building is done using GitHub Actions. You can find the built binaries on the releases page.

## Linux Build Notes

Linux binaries are built using Docker with [musl libc](https://musl.libc.org/) instead of glibc. This produces fully static binaries with no glibc dependency, meaning they run on any Linux distribution regardless of the system's glibc version. Without this, binaries compiled on a modern Ubuntu (glibc 2.35+) would fail on older systems like Ubuntu 20.04 or Debian 10.

- x86_64 builds run on an `ubuntu-22.04` GitHub Actions runner using `musl-gcc` from the `musl-tools` apt package.
- arm64 builds run on an `ubuntu-24.04-arm` (native ARM64) runner, also using `musl-gcc` — no cross-compilation required.

The `Dockerfile` captures the build environment. The workflow builds the image, extracts the binaries with `docker cp`, runs a smoke test (`ffmpeg -version`), then uploads the artifacts.

Supported platforms:

  - Linux
      * `x86_64-linux-gnu`
      * `aarch64-linux-gnu`
  - Windows
      * `x86_64-w64-mingw32`
      * `arm64-w64-mingw32`
  - macOS
      * Universal binary (supports both x86_64 and arm64 architectures)
      * Compatible with macOS 10.9+ (Intel) and macOS 11+ (Apple Silicon)
