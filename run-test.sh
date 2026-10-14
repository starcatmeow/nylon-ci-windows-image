#!/usr/bin/env bash
set -euo pipefail
cd /home/catmeow/src/nylon-windows-ci-image

if [[ ! -f build/winserver2025.qcow2 ]]; then
  zstd -d build/nylon-ci-win2025.qcow2.zst -o build/winserver2025.qcow2
fi

qemu-img create -f qcow2 -F qcow2 \
  -b /home/catmeow/src/nylon-windows-ci-image/build/winserver2025.qcow2 \
  build/test-winserver2025.qcow2
install -m 600 build/OVMF_VARS.fd build/test-OVMF_VARS.fd

exec qemu-system-x86_64 \
  -enable-kvm -cpu host -m 4G -smp 4 \
  -nodefaults -display none -monitor none \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file=build/test-OVMF_VARS.fd \
  -device virtio-scsi-pci,id=scsi0 \
  -drive if=none,id=os,file=build/test-winserver2025.qcow2,format=qcow2 \
  -device scsi-hd,drive=os,bus=scsi0.0,bootindex=1 \
  -nic user,model=virtio-net-pci,dhcpstart=10.0.2.100,hostfwd=tcp:127.0.0.1:5985-10.0.2.100:5985
