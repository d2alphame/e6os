INSTALLER_STARTUP_SEGMENT       equ 0x800

; This is relative to where in memory e6 is loaded. This means after successful load, the PE header will be overwritten
IMAGE_HANDLE_OFFSET             equ 0     ; Relative Offset where to store the image handle once received from efi
SYSTEM_TABLE_OFFSET             equ 8 
