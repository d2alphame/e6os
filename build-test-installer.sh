# Build the installer
nasm -f bin INSTALL.asm -o INSTALL.EFI

# Use hdiutil to mount the virtual installer usb disk
hdiutil attach -imagekey diskimage-class=CRawDiskImage usb-flash.img

# Copy the binary of the installer - INSTALL.EFI - on to the usb stick
cp ./INSTALL.EFI /Volumes/USBDISK

# Eject the virtual disk
diskutil eject /Volumes/USBDISK

# Launch qemu
qemu-system-x86_64 \
  -machine type=q35,accel=tcg \
  -cpu qemu64 \
  -smp 2 \
  -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/local/share/qemu/edk2-x86_64-code.fd \
  -drive if=pflash,format=raw,file=./nvram-vars.fd \
  -drive if=none,id=usbdisk,format=raw,file=usb-flash.img \
  -device usb-ehci,id=ehci \
  -device usb-storage,bus=ehci.0,drive=usbdisk \
  -usb \
  -boot menu=on \