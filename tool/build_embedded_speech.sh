#!/usr/bin/env bash
# Rebuild the bundled, separate eSpeak NG executable and the shipped data.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

sdk="${BILGA_ANDROID_SDK:-$PWD/.bilga-tools/android}"
ndk="$sdk/ndk/28.2.13676358"
cmake="$sdk/cmake/3.22.1/bin/cmake"
strip="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
export PATH="$(dirname "$cmake"):$PATH"
assets="$PWD/android/app/src/main/assets/embedded-speech"
archive="$assets/espeak-ng-1.52.0-source.tgz"
printf '%s  %s\n' bb4338102ff3b49a81423da8a1a158b420124b055b60fa76cfb4b18677130a23 "$archive" | sha256sum --check

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
tar --strip-components=1 -xzf "$archive" -C "$work/source"
# Upstream otherwise downloads Sonic even when audio time stretching is disabled.
python3 - "$work/source/cmake/deps.cmake" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = path.read_text()
old = 'else()\n  FetchContent_Declare(sonic-git'
assert source.count(old) == 1
path.write_text(source.replace(old, 'elseif(USE_LIBSONIC)\n  FetchContent_Declare(sonic-git'))
PY

options=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
    -DUSE_LIBPCAUDIO=OFF -DUSE_LIBSONIC=OFF -DUSE_MBROLA=OFF -DUSE_SPEECHPLAYER=OFF)
"$cmake" -S "$work/source" -B "$work/host" "${options[@]}"
"$cmake" --build "$work/host" --target data --parallel 4
data="$work/host/espeak-ng-data"
package="$assets/espeak-ng-data"
mkdir -p "$package/lang/"{trk,zle,gmw}
for file in phondata phonindex phontab intonations uz_dict en_dict ru_dict; do
    install -m 0644 "$data/$file" "$package/$file"
done
for voice in trk/uz zle/ru gmw/en gmw/en-US; do
    install -m 0644 "$data/lang/$voice" "$package/lang/$voice"
done
for abi in arm64-v8a armeabi-v7a x86_64; do
    "$cmake" -S "$work/source" -B "$work/$abi" "${options[@]}" \
        -DCMAKE_TOOLCHAIN_FILE="$ndk/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="$abi" -DANDROID_PLATFORM=26 -DANDROID_STL=c++_static \
        '-DCMAKE_EXE_LINKER_FLAGS=-Wl,-z,max-page-size=16384'
    "$cmake" --build "$work/$abi" --target espeak-ng-bin --parallel 4
    destination="$PWD/android/app/src/main/jniLibs/$abi/libbilga_espeak_exec.so"
    install -D -m 0755 "$work/$abi/src/espeak-ng" "$destination"
    "$strip" --strip-all "$destination"
done
