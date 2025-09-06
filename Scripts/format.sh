#!/usr/bin/env bash
set -euo pipefail

# Ensure Homebrew paths are in PATH for Xcode/non-login shells
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

mint run nicklockwood/SwiftFormat@0.47.13 swiftformat \
  --config .swiftformat \
  .