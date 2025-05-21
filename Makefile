# The Makefile

# This target builds the e6 installer iso image
iso: e6iso.asm 
	nasm -f bin -o e6.iso e6iso.asm

# This target builds the e6 installer
installer: e6installer.asm
	nasm -f bin -o e6installer.bin e6installer.asm
