#!/bin/bash
set -e
echo "Installing patches at `pwd`"

echo "Applying metadata patch to movenc.c..."
patch libavformat/movenc.c < patch.diff
echo "✓ Metadata patch applied"

echo "Applying AC-4 decoder patch..."
patch -p1 < ../patch-ac4.diff
echo "✓ AC-4 decoder patch applied"

echo "All patches installed successfully"

