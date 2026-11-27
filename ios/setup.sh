#!/bin/bash
# Builds the Xcode project for Lull and opens it.  Run:  bash setup.sh
set -e
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1 || [ ! -d "/Applications/Xcode.app" ]; then
  echo "Xcode isn't installed yet. Get it from the Mac App Store, open it once, then run this again."
  exit 1
fi

XG="$(command -v xcodegen || true)"
if [ -z "$XG" ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing XcodeGen with Homebrew…"; brew install xcodegen; XG="$(command -v xcodegen)"
  else
    echo "Downloading XcodeGen…"
    curl -sL https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip -o /tmp/xcodegen.zip
    rm -rf /tmp/xcodegen && unzip -q -o /tmp/xcodegen.zip -d /tmp/xcodegen
    XG="/tmp/xcodegen/xcodegen/bin/xcodegen"
  fi
fi

"$XG" generate
open Lull.xcodeproj
echo "Done. In Xcode: pick your team under Signing & Capabilities (both targets), plug in your iPhone, press ▶."
