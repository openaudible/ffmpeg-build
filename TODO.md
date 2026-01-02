# Dolby Atmos Support Implementation Plan

## Executive Summary
Add Dolby Atmos codec support (E-AC-3, AC-4, TrueHD) to OpenAudible's FFmpeg build while preserving existing metadata tag patches.

## Current State Analysis

### Current FFmpeg Build
- **Version**: 5.1.2
- **Build Script**: `build-linux.sh`
- **Existing Patch**: `patch.diff` + `patch.sh`
  - Modifies `libavformat/movenc.c` (line 4049, 4083-4086)
  - Adds custom metadata tags for Audible-specific fields:
    - release_date, narrated_by, publisher, json64, ASIN
    - product_id, series_name, series_sequence, series_link
    - WWW, title_short, language
    - Generic `atom:xxxx` metadata support
- **Current Decoders**: mp3, aac, pcm_s16le, png, mjpeg
- **Missing**: eac3, ac4, truehd decoders

### Required Atmos Codec Support

| Codec | FFmpeg ID | Built-in? | Action Required |
|-------|-----------|-----------|-----------------|
| E-AC-3 (Dolby Digital Plus Atmos) | eac3 | ✅ Yes | Add to configure flags |
| AC-4 (Dolby AC-4 Immersive) | ac4 | ❌ No | Apply community patch |
| TrueHD+Atmos | truehd | ✅ Yes | Add to configure flags |

### AC-4 Patch Details
- **Source**: https://github.com/funnymanva/ffmpeg-with-ac4
- **Target FFmpeg Version**: 6.1
- **Patch File**: `ffmpeg_ac4.patch`
- **Files Modified**:
  1. `libavcodec/Makefile` - Add ac4dec.o build target
  2. `libavcodec/ac4dec.c` - New 5892-line decoder implementation
  3. `libavcodec/ac4dec_data.h` - New decoder data structures
  4. `libavcodec/allcodecs.c` - Register AC-4 decoder
  5. `libavcodec/kbdwin.h` - Additional windowing functions
- **License**: LGPL v2.1+ (Copyright Paul B Mahol, 2019)

## License Verification ✅

All components are **LGPL v2.1+ licensed** - NO GPL or commercial restrictions:

| Component | File(s) | License | Copyright |
|-----------|---------|---------|-----------|
| **AC-3/E-AC-3 Decoder** | ac3dec_float.c, ac3dec_fixed.c | LGPL v2.1+ | Google Summer of Code 2006-2007, Multiple contributors |
| **AC-4 Decoder** | ac4dec.c (patched) | LGPL v2.1+ | (c) 2019 Paul B Mahol |
| **TrueHD Decoder** | mlpdec.c | LGPL v2.1+ | (c) 2007-2008 Ian Caulfield |
| **AC-3/E-AC-3 Demuxer** | ac3dec.c (format) | LGPL v2.1+ | (c) 2007 Justin Ruggles |
| **TrueHD Demuxer** | mlpdec.c (format) | LGPL v2.1+ | (c) 2001-2015 Multiple contributors |
| **AC-3/E-AC-3 Parser** | ac3_parser.c | LGPL v2.1+ | (c) 2003 Fabrice Bellard, Michael Niedermayer |
| **PCM Codecs** | pcm.c (s24le, f32le) | LGPL v2.1+ | (c) 2001 Fabrice Bellard |

**Result**: ✅ All components compatible with OpenAudible's LGPL FFmpeg build. No GPL or proprietary codecs required.

## Implementation Strategy

### Option A: Upgrade to FFmpeg 6.1 (RECOMMENDED)
**Pros**:
- AC-4 patch is designed for 6.1
- More recent version with bug fixes
- Better long-term maintainability
- E-AC-3 and TrueHD decoders are built-in

**Cons**:
- Need to verify existing metadata patch compatibility
- More significant version jump (5.1.2 → 6.1)

**Risk Assessment**: MEDIUM
- Main risk: movenc.c changes between 5.1.2 and 6.1
- Mitigation: Test patch application, adapt if needed

### Option B: Port AC-4 Patch to FFmpeg 5.1.2
**Pros**:
- No FFmpeg version change
- Existing metadata patch guaranteed to work

**Cons**:
- Significant manual porting effort
- AC-4 decoder may have dependencies on 6.1 APIs
- Staying on older FFmpeg version

**Risk Assessment**: HIGH
- Complex 6000-line decoder may depend on 6.1 features
- Not recommended unless Option A fails

## Recommended Implementation Plan

### Phase 1: Preparation and Testing
1. **Download FFmpeg 6.1 source**
   ```bash
   curl -L -O https://ffmpeg.org/releases/ffmpeg-6.1.tar.xz
   ```

2. **Test existing patch against FFmpeg 6.1**
   - Extract FFmpeg 6.1
   - Locate `libavformat/movenc.c` in 6.1
   - Attempt to apply `patch.diff`
   - If failed, manually identify equivalent code sections
   - Create updated patch: `patch-6.1.diff`

3. **Copy AC-4 patch to project**
   ```bash
   cp /tmp/ffmpeg-with-ac4/ffmpeg_ac4.patch ./patch-ac4.diff
   ```

### Phase 2: Update Build System
4. **Update `common.sh`**
   - Change `FFMPEG_VERSION=5.1.2` → `FFMPEG_VERSION=6.1`
   - Change `FFMPEG_TARBALL=ffmpeg-$FFMPEG_VERSION.tar.bz2` → `FFMPEG_TARBALL=ffmpeg-$FFMPEG_VERSION.tar.xz`
   - Update `FFMPEG_TARBALL_URL`

5. **Update `patch.sh`**
   - Apply updated metadata patch: `patch libavformat/movenc.c < patch-6.1.diff`
   - Apply AC-4 patch: `patch -p1 < ../patch-ac4.diff`

6. **Update `common.sh` FFMPEG_CONFIGURE_FLAGS**
   Add these decoder/demuxer/parser entries:
   ```bash
   # Atmos codec support
   --enable-decoder=eac3
   --enable-decoder=ac4
   --enable-decoder=truehd
   --enable-decoder=ac3
   --enable-demuxer=eac3
   --enable-demuxer=ac3
   --enable-demuxer=truehd
   --enable-parser=eac3
   --enable-parser=ac3

   # Additional PCM formats for Atmos output
   --enable-encoder=pcm_s24le
   --enable-decoder=pcm_s24le
   --enable-encoder=pcm_f32le
   --enable-decoder=pcm_f32le
   ```

### Phase 3: Build and Test
7. **Initial build attempt**
   ```bash
   ./build-linux.sh
   ```

8. **Handle build errors iteratively**
   - Review error output
   - Fix issues (missing dependencies, configure flags, patch conflicts)
   - Rebuild
   - Repeat until successful

9. **Verify codec support**
   ```bash
   ./artifacts/ffmpeg-6.1-audio-x86_64-linux-gnu/bin/ffmpeg -decoders | grep -E "(eac3|ac4|truehd)"
   ```
   Expected output:
   ```
   A....D eac3                 ATSC A/52 E-AC-3
   A....D ac4                  AC-4
   A....D truehd               TrueHD
   ```

10. **Test existing functionality**
    - Verify mp3, aac decoding still works
    - Test metadata tag preservation with sample files
    - Ensure no regressions in current OpenAudible workflow

### Phase 4: Testing New Codecs
11. **User creates test files** (after successful build)
    - Test E-AC-3 decoding
    - Test AC-4 decoding
    - Test TrueHD decoding
    - Verify metadata preservation in Atmos files

## File Changes Summary

### Files to Modify
1. `common.sh` - FFmpeg version, URL, configure flags
2. `patch.sh` - Apply both patches
3. `patch.diff` - Update for FFmpeg 6.1 (if needed)

### Files to Add
1. `patch-ac4.diff` - AC-4 decoder patch from funnymanva/ffmpeg-with-ac4

### Build Artifacts
- Output: `artifacts/ffmpeg-6.1-audio-x86_64-linux-gnu/bin/ffmpeg`
- Size increase: ~200-300KB for AC-4 decoder

## Rollback Plan
If FFmpeg 6.1 upgrade fails:
1. Revert `common.sh` to version 5.1.2
2. Add only E-AC-3 and TrueHD decoders (built-in to 5.1.2)
3. Skip AC-4 support temporarily
4. Document AC-4 as future enhancement

## Success Criteria
- ✅ FFmpeg builds successfully with `build-linux.sh`
- ✅ All three Atmos decoders present: eac3, ac4, truehd
- ✅ Existing metadata patches still applied correctly
- ✅ OpenAudible metadata tags preserved in output files
- ✅ No regressions in existing mp3/aac functionality

## Timeline
- **Phase 1**: 1-2 hours (patch testing)
- **Phase 2**: 30 minutes (build system updates)
- **Phase 3**: 1-3 hours (iterative builds, debugging)
- **Phase 4**: User-driven (codec testing)

**Total Estimated Effort**: 3-6 hours

## References
- AC-4 Patch: https://github.com/funnymanva/ffmpeg-with-ac4
- FFmpeg 6.1 Release: https://ffmpeg.org/releases/ffmpeg-6.1.tar.xz
- Atmos Documentation: `FFMPEG_ATMOS.md`
- Current Build Script: `build-linux.sh`
