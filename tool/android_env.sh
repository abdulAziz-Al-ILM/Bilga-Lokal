#!/usr/bin/env bash
# Source this file from the project root before using Flutter/Android CLI.
# Existing SDK and JDK installations are reused; nothing is downloaded here.
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME:-}/bin/java" ]]; then
  bilga_java_binary="$(command -v java)" || return 1
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$bilga_java_binary")")")"
  export JAVA_HOME
  unset bilga_java_binary
fi
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
