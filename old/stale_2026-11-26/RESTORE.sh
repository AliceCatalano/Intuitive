#!/bin/bash
# Moves every file listed in MANIFEST.txt back to its original place (run from anywhere; never overwrites).
cd "$(dirname "$0")"; ROOT=../..
while read -r p; do mkdir -p "$ROOT/$(dirname "$p")"; mv -n "$p" "$ROOT/$p"; done < MANIFEST.txt
