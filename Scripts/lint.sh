#!/usr/bin/env bash
set -euo pipefail

# Ensure Homebrew paths are in PATH for Xcode/non-login shells
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

mint run realm/SwiftLint@0.59.1 swiftlint \
  --quiet \
  --config .swiftlint.yml