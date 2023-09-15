OpenAudible FFmpeg builds
===============================

This fork creates ffmpeg/ffprobe binaries used for OpenAudible, an audibobook management desktop application. 

These binaries only include the codecs, filters, and muxers that are needed for OpenAudible (mp3/m4b/m4a and cover artwork). 

We add a small patch to allow additional metadata in m4a/m4b tags.  

We produce binaries for Linux (x86_64), Mac (arm64 and x86_64), and Windows (x86_64).

Thank you to AcousticID for their ffmpeg-build github actions. Incredible to build 4 static binaries for ffmpeg in under 6 minutes. 

Building is done using GitHub Actions. You can find the built binaries on the releases page.

Supported platforms:

  - Linux
      * `x86\_64-linux-gnu`
  - Windows
      * `x86\_64-w64-mingw32`
  - macOS
      * `x86_64-apple-macos10.9` (macOS Mavericks and newer on Intel CPU)
      * `arm64-apple-macos11` (macOS Big Sur and newer on Apple M1 CPU)

      To build universal mac binary, this needs to be done manually (for now) on an arm mac: 
```
    mkdir -p mac
    lipo -create ./mac_x86_64/ffmpeg ./mac_arm64/ffmpeg -output ./mac/ffmpeg
    lipo -create ./mac_x86_64/ffprobe ./mac_arm64/ffprobe -output ./mac/ffprobe
```
