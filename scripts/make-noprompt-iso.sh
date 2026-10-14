#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
  echo "Usage: $0 INPUT.iso OUTPUT.iso" >&2
  exit 2
fi
input=$1
output=$2
[[ ! -e "$output" && ! -L "$output" ]]
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

7zz x -so "$input" efi/microsoft/boot/efisys.bin > "$workdir/efisys.bin"
7zz x -so "$input" efi/microsoft/boot/efisys_noprompt.bin > "$workdir/efisys_noprompt.bin"
size=$(stat -c %s "$workdir/efisys.bin")
[[ "$size" -gt 0 && "$size" -eq "$(stat -c %s "$workdir/efisys_noprompt.bin")" ]]

# Use xorriso for the boot catalog, preserving the original UDF image.
lba=$(xorriso -indev "$input" -report_el_torito plain 2>&1 |
  awk '$1 == "El" && $2 == "Torito" && $3 == "boot" && $4 == "img" && $7 == "UEFI" { print $NF }')
[[ "$lba" =~ ^[0-9]+$ ]]

# Verify the complete existing image; the catalog's load size may be just 512 bytes.
dd if="$input" iflag=skip_bytes,count_bytes skip="$((lba * 2048))" count="$size" status=none |
  cmp - "$workdir/efisys.bin"

cp --reflink=auto -- "$input" "$output"
chmod u+w "$output"
dd if="$workdir/efisys_noprompt.bin" of="$output" bs=2048 seek="$lba" conv=notrunc status=none
