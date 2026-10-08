#!/usr/bin/env bash
set -euo pipefail
# Developer-only backup before installing an update. Requires a debug build.
# The tar contains private data without additional encryption. Keep it private.
if [[ $# -ne 1 ]]; then
  echo 'Ishlatish: bash tool/backup_debug_data.sh DEVICE_ID' >&2
  echo 'DEVICE_ID ni adb devices buyrug‘idan oling.' >&2
  exit 1
fi
bilga_backup_dir="$(mktemp -d "${TMPDIR:-/tmp}/bilga-device-backup.XXXXXX")"
bilga_backup_file="$bilga_backup_dir/bilga-databases.tar"
adb -s "$1" shell am force-stop com.ilmmizan.bilga
if ! adb -s "$1" exec-out run-as com.ilmmizan.bilga tar -cf - databases > "$bilga_backup_file"; then
  echo 'Baza zaxiralanmadi. Ilova debug bo‘lishi va kamida bir marta ochilgan bo‘lishi kerak.' >&2
  exit 1
fi
tar -tf "$bilga_backup_file" >/dev/null
printf 'Baza zaxirasi: %s\nUni shaxsiy, doimiy papkaga ko‘chirib qo‘ying.\n' "$bilga_backup_file"
