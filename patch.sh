#!/bin/bash
set -e
echo "Installing patches at `pwd`"

echo "Applying metadata patch to movenc.c..."
patch -p1 < patch.diff
echo "✓ Metadata patch applied"

echo "Applying AC-4 decoder patch..."
patch -p1 < ../patch-ac4.diff
echo "✓ AC-4 decoder patch applied"

echo "Applying probe mode patch to ffmpeg.c and Makefile..."
patch -p1 < ../patch-probe.diff
cp ../fftools/ffmpeg_probe.c fftools/ffmpeg_probe.c
echo "✓ Probe mode patch applied"

echo "All patches installed successfully"

