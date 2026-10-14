#!/usr/bin/env bash
set -euo pipefail
cd "${BUILD_ROOT:-/home/catmeow/src/nylon-windows-ci-image}"

mkdir -p build
xorriso -as mkisofs -J -R -o build/unattend.iso unattend
qemu-img create -f qcow2 build/winserver2025.qcow2 64G
install -m 600 "$OVMF_VARS" build/OVMF_VARS.fd

qemu-system-x86_64 \
  -enable-kvm -cpu host -m 4G -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file=build/OVMF_VARS.fd \
  -device virtio-scsi-pci,id=scsi0 \
  -drive if=none,id=os,file=build/winserver2025.qcow2,format=qcow2 \
  -device scsi-hd,drive=os,bus=scsi0.0 \
  -device ich9-ahci,id=sata \
  -drive if=none,id=install,file="$INSTALL_ISO",format=raw,media=cdrom,readonly=on \
  -device ide-cd,drive=install,bus=sata.0 \
  -drive if=none,id=unattend,file=build/unattend.iso,format=raw,media=cdrom,readonly=on \
  -device ide-cd,drive=unattend,bus=sata.1 \
  -drive if=none,id=virtio,file="$VIRTIO_ISO",format=raw,media=cdrom,readonly=on \
  -device ide-cd,drive=virtio,bus=sata.2 \
  -boot once=d -nic user,model=virtio-net-pci \
  -vnc 127.0.0.1:0 -monitor none -serial stdio \
  | tee build/serial.log

# The pipeline waits for QEMU to exit after the guest shuts down.
grep -q OOBE_COMPLETE build/serial.log

zstd -T0 -f --rm build/winserver2025.qcow2 -o build/nylon-ci-win2025.qcow2.zst
