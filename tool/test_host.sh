#!/usr/bin/env bash
# Serial host checks using the pinned SDK and existing NDK C compiler for PDFium.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if ! command -v clang >/dev/null 2>&1; then
  bilga_clang="$PWD/.bilga-tools/android/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin"
  test -x "$bilga_clang/clang" || { echo 'Install Clang or the pinned Android NDK before running native PDF tests.' >&2; exit 1; }
  export PATH="$bilga_clang:$PATH"
fi
export PUB_CACHE="${PUB_CACHE:-$PWD/.bilga-tools/pub-cache}"
export DART_SUPPRESS_ANALYTICS=true
exec flock --close -n .bilga-tools/build.lock .bilga-tools/flutter/bin/flutter test --no-pub --concurrency=1 "$@"
