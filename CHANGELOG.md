# Changelog
All notable changes to this project will be documented in this file.

## [Unreleased]
### Changed
- Upgraded FFmpeg to 8.0. Audiobook metadata/ftyp, embedded `-probe`, and the
  AC-4 decoder patches were ported to the FFmpeg 8 codec/fftools APIs.
- Pinned LAME to SVN r6835. The checkout tracked trunk, so no two releases were
  guaranteed to contain the same mp3 encoder.
- Bumped zlib 1.2.11 (2017) to 1.3.1, picking up CVE-2018-25032 and
  CVE-2022-37434. zlib is statically linked into every binary and is reachable
  from untrusted input via the png decoder (cover art) and compressed `moov`
  atoms.

### Fixed
- AAX/AAXC demuxing no longer AES-"decrypts" unencrypted non-audio tracks
  (`patch-aax.diff`). Titles with a QuickTime chapter-image track (mjpeg timed
  thumbnails) previously failed with `Decode error rate 1 exceeds maximum`
  after the audio had fully converted.
- `OACOMPAT`/compatibility-floor strings no longer contain parentheses, which
  aborted FFmpeg's `configure` (`eval "export OACOMPAT=..."`) on every platform.

## [4.2.2-5] - 2020-02-19
### Changed
- Linux and Windows builds now use the manylinux2010 Docker image defined by the Python community.

### Removed
- Removed i686 and armhf builds.

## [4.2.2-4] - 2020-02-12
### Changed
- Enable PIC in static builds

[Unreleased]: https://github.com/acoustid/ffmpeg-build/compare/v4.2.2-5...HEAD
[4.2.2-5]: https://github.com/acoustid/ffmpeg-build/compare/v4.2.2-4...v4.2.2-5
[4.2.2-4]: https://github.com/acoustid/ffmpeg-build/compare/v4.2.2-3...v4.2.2-4
