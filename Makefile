# The Makefile

# Pad up the installer up to 32768 bytes
INSTALLER_PADDING_UP = 32768

# Pad up the boot sector up to 512 bytes
BOOT_SECTOR_PADDING_UP = 512

# Pad up the boot sector up to 4096 bytes
BOOT_SECTOR_PADDING_UP_4K = 4096

# Main directory for building
TEMPORARY_DIR = /tmp/e6os

# Temporary directory for building 
TEMP_BUILD_DIR = $(TEMPORARY_DIR)/build

# Temporary directory for building the e6 installer
INSTALLER_TEMP_DIR = $(TEMP_BUILD_DIR)/installer

# Temporary file for the e6 installer
INSTALLER_TEMP_FILE = $(INSTALLER_TEMP_DIR)/e6installer.asm

# This target builds the e6 installer iso image
iso: e6iso.asm 
	nasm -f bin -o e6.iso e6iso.asm

# This target builds the e6 installer
installer: e6installer.asm
	mkdir -p /tmp/e6-build
	nasm -f bin -o e6installer.bin e6installer.asm

