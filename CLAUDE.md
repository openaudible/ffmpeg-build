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

## Local Development

**Use `build-linux.sh` (or platform-specific scripts) for local builds**, not `build.sh` which triggers GitHub Actions.

The build process:
- Creates temporary `build.XXXXXXXX/` directories for compilation
- Automatically cleans up on successful completion
- If interrupted (Ctrl+C), temporary directories may remain - clean up with: `rm -rf build.*`
- Outputs binaries to `artifacts/ffmpeg-8.0-audio-<platform>/bin/`
- Custom source files (like `fftools/ffmpeg_probe.c`) are automatically copied during build

### Debug Builds with Incremental Compilation

For faster development iteration, use `debug.sh`:

```bash
# First build: extracts sources, applies patches, compiles everything
./debug.sh

# Edit source files in build-debug-x86_64/
vim build-debug-x86_64/fftools/ffmpeg_probe.c

# Incremental build: only recompiles changed files (much faster!)
./debug.sh

# Force clean rebuild
rm -rf build-debug-*
./debug.sh
```

**How it works:**
- Uses fixed directory: `build-debug-${ARCH}` (not deleted after build)
- First run: full extraction, patching, and compilation
- Subsequent runs: skips extraction, make rebuilds only changed files
- Output: debug symbols enabled, optimizations disabled, binary not stripped
- Clean up: `./clean.sh` removes all build directories

**Typical workflow:**
1. Run `./debug.sh` once to create build environment
2. Edit sources directly in `build-debug-x86_64/`
3. Re-run `./debug.sh` for fast incremental compilation
4. Debug binary appears in `artifacts/ffmpeg-6.1-audio-x86_64-linux-gnu/bin/`

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

Three patches modify the upstream FFmpeg 8.0 source:

1. **patch-probe.diff** - Adds `-probe` flag to ffmpeg
   - Embeds ffprobe functionality directly into ffmpeg
   - Outputs JSON format matching ffprobe's default behavior
   - Reduces distribution size by eliminating separate ffprobe binary

2. **patch.diff** - Audiobook metadata extensions + ftyp brand override
   - Adds custom M4A/M4B tags for audiobook-specific metadata
   - Supports: narrator, publisher, ASIN, series info, release date
   - Enables arbitrary metadata via `atom:XXXX` prefix
   - Essential for OpenAudible's audiobook management features
   - Overrides the `ftyp` box for audio-only m4a/m4b output (`MODE_IPOD`):
     emits `major_brand=isom`, `minor_version=512`,
     `compatible_brands=iso2 mp41 M4A M4B ` instead of FFmpeg's hardcoded
     `M4A ` brand. The `M4B` brand signals a bookmarkable audiobook to players
     (e.g. foobar2000). Scoped to audio only — video (`M4V`), `.mov`/`.mp4`,
     and any `-brand` CLI override keep FFmpeg's stock behavior.
   - Note: ftyp brands cannot be set via `-metadata`; they are fixed by the
     muxer mode and the `-brand` option, which is why this patch is required.

3. **patch-ac4.diff** - AC-4 audio decoder
   - Adds support for AC-4 (Dolby AC-4) audio codec
   - Used in some audiobook formats
   - This is a backport of an out-of-tree decoder; upstream FFmpeg 8 only ships
     the AC-4 *container* (raw muxer/demuxer), not a decoder. The decoder source
     was ported to the FFmpeg 8 codec API: `avctx->channels` →
     `ch_layout.nb_channels`, `frame->key_frame` → `AV_FRAME_FLAG_KEY`,
     `avpriv_kbd_window_init` → `ff_kbd_window_init`, an explicit
     `libavutil/mem.h` include, and a local `VLC_INIT_STATIC` shim (the macro
     was removed in FFmpeg 7 but its primitives — `ff_vlc_init_sparse`,
     `VLCElem`, `VLC_INIT_USE_STATIC` — remain). When bumping FFmpeg again,
     re-check these against the new codec API.

## Build Configuration

- Minimal codec set: encode/decode mp3 (libmp3lame), aac, ac3, opus (libopus),
  pcm; decode-only eac3, truehd, ac4. Opus is carried in ogg/opus or mp4/m4b.
- External libraries (libmp3lame, libopus, zlib) are built statically from
  source by each `build-*.sh` script before FFmpeg is configured. libopus is
  located via pkg-config (`PKG_CONFIG_PATH` + `--pkg-config-flags=--static`).
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

## Platform Compatibility (run on the widest range of systems)

These binaries ship inside OpenAudible and must run on machines far older than
the GitHub Actions runners that build them. The danger: **CI runners are
upgraded over time** (e.g. `ubuntu-latest` rolls forward to newer releases with
a newer glibc, macOS runners get newer SDKs). If a binary is allowed to link
against whatever the runner happens to provide, it picks up newer symbol
versions (e.g. `GLIBC_2.34`) and **fails to start on older end-user systems**
with errors like `version 'GLIBC_2.34' not found`. Every platform below is built
to pin its compatibility floor *independently of the runner*.

### Linux — musl, fully static (zero glibc dependency)

This is the most important and most fragile case. Linux binaries are built
**inside Docker** (`Dockerfile`, `FROM ubuntu:22.04`) and compiled with
**musl** (`musl-gcc`, installed via `musl-tools`) and `--extra-ldflags=-static`,
not glibc. See `build-linux.sh` (`MUSL_CC="musl-gcc"`).

Why this matters: a musl-static binary contains **no glibc symbol-version
requirements at all**, so it runs on any Linux regardless of the distro or glibc
version — old CentOS, new Ubuntu, Alpine, etc. The runner's and even the Docker
base image's glibc become irrelevant because nothing links glibc.

This is enforced, not assumed: the `Dockerfile` fails the build if any `GLIBC`
string appears in the output binary (`strings ... | grep -q GLIBC` → error).
**Do not remove that check, and do not switch Linux off musl** (e.g. to a plain
glibc static/dynamic build on the runner) — that silently reintroduces a glibc
floor tied to whatever runner built it.

- Because the real toolchain lives in Docker, the `runner:` choice in
  `build.yml` (e.g. `ubuntu-22.04` for x86_64, `ubuntu-24.04-arm` for arm64)
  only needs Docker — it does **not** set the compatibility floor.
- Local note: `build-linux.sh` requires `musl-gcc`; without `musl-tools`
  installed, build in Docker instead (`docker build --build-arg ARCH=x86_64 .`).

**How the Linux build is wired (Docker vs Actions vs a GitHub container):**
The `package-linux` job runs *on* a GitHub Actions runner and that runner
**invokes `docker build`** itself (see `build.yml`: `docker build ... .` then
`docker create`/`docker cp` to pull the binaries out). It is **not** a GitHub
"`container:`" job (the workflow has no `container:` key) — Actions only supplies
the host + Docker; the Dockerfile (`ubuntu:22.04` + musl) is the real build
environment. arm64 builds run on a **native arm64 runner** (`ubuntu-24.04-arm`)
that docker-builds the arm64 image — there is no QEMU/cross emulation.
By contrast, **Windows and macOS do not use Docker**: Windows is cross-compiled
directly on an `ubuntu-22.04` runner (MinGW/llvm-mingw), and macOS builds run
directly on `macos-latest`.

### Windows — static MinGW / UCRT (no runtime DLLs)

Cross-compiled on Linux (`build-windows.sh`), linked with
`-static -static-libgcc -static-libstdc++` so there is no dependency on
mingw runtime DLLs the user won't have.

- **x86_64**: `mingw-w64` (msvcrt) — runs broadly on Windows 7+.
- **arm64**: `llvm-mingw` targeting **UCRT** — runs on Windows 10/11 on ARM
  (the earliest realistic floor for Windows-on-ARM).

The compatibility floor is set by the toolchain/CRT, not the runner, so the
`ubuntu-22.04` build host can move without affecting Windows compatibility.

### macOS — pinned deployment target + universal binary

Each arch is built with an explicit minimum-OS `-target` (`build-macos.sh`,
driven by `TARGET`), then `lipo`-merged into one universal binary:

- **Intel**: `x86_64-apple-macos10.9` (floor: macOS 10.9)
- **Apple Silicon**: `arm64-apple-macos11` (floor: macOS 11, earliest for arm64)

The deployment target — not the `macos-latest` runner's SDK — sets the minimum
supported macOS. Building on a newer SDK is fine as long as it still supports
those targets; if Apple drops support for the 10.9 SDK, the Intel floor must be
raised here deliberately rather than left to drift.

### Summary of the compatibility floor per platform

| Platform        | Mechanism                          | Floor / runs on                |
|-----------------|------------------------------------|--------------------------------|
| Linux x86_64    | musl + `-static` (Docker)          | any Linux (no glibc dep)       |
| Linux arm64     | musl + `-static` (Docker)          | any Linux (no glibc dep)       |
| Windows x86_64  | mingw-w64, static libgcc/stdc++    | Windows 7+                     |
| Windows arm64   | llvm-mingw UCRT, static            | Windows 10/11 (ARM)            |
| macOS Intel     | `-target ...macos10.9`             | macOS 10.9+                    |
| macOS ARM       | `-target ...macos11`               | macOS 11+                      |

### Compatibility reporting (so you don't have to test on every OS)

Testing on a matrix of old/new Linux/Windows/macOS is painful, so each binary
**declares the floor it was built for**, two ways:

1. **Self-reported at runtime.** The floor string is embedded in the binary via
   `--env=OACOMPAT=...` (FFmpeg records every configure arg in its configuration
   string), so any copy of the binary can be interrogated without a test machine:

   ```bash
   ffmpeg -version | tr ' ' '\n' | grep OACOMPAT
   # e.g. OACOMPAT=min_os=linux-any,musl-static,no-glibc,arch=x86_64
   #      OACOMPAT=min_os=windows7,x86_64,msvcrt,static
   #      OACOMPAT=min_os=macos10.9,arch=x86_64
   ```

   Note: the floor string must use only shell-safe characters (no parentheses).
   FFmpeg's `configure` runs `eval "export OACOMPAT=..."` on the `--env` value,
   so a `(` in the string aborts configure with a syntax error. Keep the
   comma/`=`-delimited form above.

2. **Reported and verified at build time.** Each `build-*.sh` calls
   `report_compatibility` (in `common.sh`) after install, printing the target
   floor plus host-side checks: Linux confirms `no GLIBC` + static `file` type,
   macOS prints `lipo -info` and the Mach-O `minos`, Windows lists imported DLLs
   (should be system-only — no `libgcc`/`libstdc++`/`libwinpthread`). CI echoes
   the same `OACOMPAT` in the Linux smoke test and the universal-macOS report.

When raising or lowering a floor, change it in **one place** per platform (the
`COMPAT_FLOOR` / `add_compat_env` call in that `build-*.sh`) and the actual
toolchain knob that enforces it (musl for Linux, `-target ...macosX` for macOS,
the MinGW/UCRT toolchain for Windows). Keep the declared string and the real
floor in sync.

### Building all platforms

The full multi-platform matrix runs **only in CI** (`.github/workflows/build.yml`):
push to `main`, open a PR, or trigger `workflow_dispatch`. Tagging `v*` also
publishes a GitHub Release. Locally you can reproduce any single platform with
the matching `build-*.sh` (use Docker for Linux to get musl), but the universal
macOS binary and the assembled release tarballs are produced by the workflow.

## Configuration

Modify `common.sh` to adjust:
- FFmpeg version
- Enabled codecs/formats
- Build flags
- Output paths

## Notes

- Binaries are stripped and statically linked
- macOS builds universal binaries using github actions, running locally require Xcode command-line tools
- Windows cross-compilation uses MinGW-w64 (x86_64) / llvm-mingw UCRT (arm64)
- Linux builds use Docker + musl for a zero-glibc-dependency static binary
- See **Platform Compatibility** above for how each platform pins its minimum
  supported OS independently of the (upgradable) CI runners
