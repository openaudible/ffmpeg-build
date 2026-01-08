# FFmpeg Build Scripts Guide

## GitHub Actions Workflow Scripts

These scripts manage GitHub Actions builds (preferred method):

### trigger-build.sh
Triggers a new GitHub Actions workflow run.

```bash
./trigger-build.sh [branch]
```

- Default branch: `atmos`
- Requires: `gh` CLI authenticated
- Outputs: Run ID and monitoring command

### monitor-build.sh
Real-time monitoring of a GitHub Actions workflow run.

```bash
./monitor-build.sh <run-id>
```

- Shows job status updates every 10 seconds
- Displays completion status and next steps
- Press Ctrl+C to stop monitoring

### download-builds.sh
Downloads compiled ffmpeg/ffprobe binaries from a completed build.

```bash
./download-builds.sh <run-id> [output-dir]
```

- Default output: `downloads/`
- Downloads only the `apps` artifact (binaries only, not full build)
- Organizes by platform: linux_x86_64, win_x86_64, win_arm64, mac_x86_64, mac_arm64

### build-status.sh
Minimal LLM-friendly status output (alerts on failure, shows path on success).

```bash
./build-status.sh [run-id] [--wait]
```

- If no run-id provided, checks most recent run
- `--wait` flag: blocks until build completes
- Exit codes: 0=success, 1=failure, 2=in progress

**Output formats:**
- `SUCCESS: Build #123 completed` + `PATH: downloads/` + `DOWNLOAD: ./download-builds.sh 123`
- `FAILED: Build #123 failed` + `JOBS: package-linux, release` + `URL: ...`
- `RUNNING: Build #123 in progress`

### clean.sh
Removes all build artifacts and downloads.

```bash
./clean.sh
```

Removes:
- `artifacts/`, `builds/`, `bin/`, `downloads/`
- Platform-specific build directories
- Temporary build.XXXXXXXX directories

## Platform Build Scripts

These are called by GitHub Actions (can be run locally):

### build-linux.sh
Builds Linux binaries (x86_64, arm64, etc.)

```bash
ARCH=x86_64 ./build-linux.sh
```

### build-windows.sh
Cross-compiles Windows binaries (x86_64 with mingw-w64, arm64 with llvm-mingw)

```bash
ARCH=x86_64 ./build-windows.sh
ARCH=arm64 ./build-windows.sh
```

### build-macos.sh
Builds macOS binaries (Intel and Apple Silicon)

```bash
TARGET=x86_64-apple-macos10.9 ./build-macos.sh
TARGET=arm64-apple-macos11 ./build-macos.sh
```

## Support Scripts

### common.sh
Shared configuration and functions used by build scripts.

- Defines FFmpeg version, URLs, configure flags
- Contains helper functions for dependency extraction
- **Do not execute directly** - sourced by other scripts

### patch.sh
Applies patches to FFmpeg source.

```bash
./patch.sh
```

- Applies `patch.diff` (OpenAudible metadata tags)
- Applies `patch-ac4.diff` (Dolby AC-4 codec support)
- Called automatically by build scripts

## Legacy/Local Development Scripts

These are **not used** by GitHub Actions and are for local development only:

### rebuild.sh
Local Windows rebuild script (references local `nas/` directory).

### build-lame.sh
Standalone LAME encoder build (now integrated into main build scripts).

### build-linux.docker.sh
Docker-based Linux build (alternative to GitHub Actions).

### orig-build-linux.sh
Backup of original build script.

### topdist.sh
Purpose unclear - appears to be legacy.

### all.sh
Lists FFmpeg configuration options (demuxers, encoders, etc.)

## Typical Workflow

1. **Trigger build:**
   ```bash
   ./trigger-build.sh atmos
   ```

2. **Monitor progress:**
   ```bash
   ./monitor-build.sh 12345678
   ```

3. **Download binaries:**
   ```bash
   ./download-builds.sh 12345678
   ```

4. **Verify downloads:**
   ```bash
   ls -lh downloads/*/
   ```

5. **Clean up:**
   ```bash
   ./clean.sh
   ```

## LLM-Friendly Workflow

For automated systems or LLM integrations:

```bash
# Trigger and wait
RUN_ID=$(./trigger-build.sh atmos | grep "Run ID:" | awk '{print $3}')

# Check status periodically or with --wait
./build-status.sh $RUN_ID --wait

# On success, download
./download-builds.sh $RUN_ID
```

## GitHub Actions Artifacts

The workflow creates these artifacts:

- **Per-platform artifacts** (uploaded by each job):
  - `ffmpeg-linux-x86_64`
  - `ffmpeg-windows-x86_64`, `ffmpeg-windows-arm64`
  - `ffmpeg-x86_64-apple-macos10.9`, `ffmpeg-arm64-apple-macos11`

- **apps artifact** (consolidated by release job):
  - `apps/linux_x86_64/ffmpeg`, `apps/linux_x86_64/ffprobe`
  - `apps/win_x86_64/ffmpeg.exe`, `apps/win_x86_64/ffprobe.exe`
  - `apps/win_arm64/ffmpeg.exe`, `apps/win_arm64/ffprobe.exe`
  - `apps/mac_x86_64/ffmpeg`, `apps/mac_x86_64/ffprobe`
  - `apps/mac_arm64/ffmpeg`, `apps/mac_arm64/ffprobe`

- **Release tarballs** (only on version tags):
  - Published to GitHub Releases when pushing tags like `v6.1`

## Requirements

- `gh` CLI (GitHub CLI) - https://cli.github.com/
- Authenticated: `gh auth login`
- `jq` for JSON parsing
- Standard Unix tools: bash, awk, sed, find
