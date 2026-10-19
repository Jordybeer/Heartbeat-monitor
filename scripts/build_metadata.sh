#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/artifacts
{
  echo "Heartbeat unsigned device build"
  echo "Commit: ${GITHUB_SHA:-local}"
  echo "Run: ${GITHUB_RUN_ID:-local}"
  echo "Built: $(date -u +%FT%TZ)"
  xcodebuild -version
  echo "iOS SDK: $(xcrun --sdk iphoneos --show-sdk-version)"
  echo "Requires iOS 26.0 or newer. Sign with SideStore before installing."
} > build/artifacts/BUILD.txt
