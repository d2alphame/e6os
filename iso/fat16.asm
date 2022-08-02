; Assemble with `nasm -f bin -o esp.img fat16.asm`
; This image should be placed on resulting bootable iso image
; It's the FAT16 image that EFI will boot e6 from

Bits 16

SECTOR_0:
    .jump                       jmp BOOTCODE
                                nop                 ; Necessary to pad the jump instruction up to 3 bytes
    .oem                        db 'E6OS2207'
    .bytes_per_sector           dw 2048             ; 2048 as this is meant to be on a cd/iso image
    .sectors_per_cluster        db 1
    .reserved_sector_count      dw 1                ; Number of reserved sectors including the boot sector
    .FAT_count                  db 1                ; Number of FATs. 2 is recommended but I'm choosing 1 here
    .root_entries_count         dw 64               ; Number of entries the root entry can take
    .total_sectors_count        dw 65524            ; Total number of sectors. 65524 is max for FAT16
    .boot_media                 db 0xF0             ; F8 for fixed disk, F0 for removable media such as floppy disks
    .FAT_sector_count           dw 64               ; Number of sectors occupied by 1 FAT
    .sectors_per_track          dw 0                ; Number of sectors per track. Not relevant to us
    .heads_count                dw 0                ; Number of heads on the medium. Not relevant
    .hidden_sectors             dd 0                ; Number of sectors before this FAT partition
    .total_sectors_count_B      dd 0                ; Total number of sectors that make up this filesystem
    

    ; Add these entries for a FAT16 partition
    .drive_number               db 0x00             ; BIOS drive number of the boot device
    .reserved                   db 0x00
    .extended_boot_signature    db 0x29             ; Set to 0x29 if Volume Serial Number and Volume Label are present 
    .volume_id                  dd 0x00             ; Don't really need this. I think. Just combine the current date and time into a single 32-bit value
    .volume_label               db 'E6BOOT     '    ; The volume label
    .filesystem_type            db 'FAT16   '       ; This is actually for informational purposes only

BOOTCODE:
    jmp $

times 510-($-$$) db 0
dw 0xAA55

times 2048-($-$$) db 0                              ; Pad up to a 2KB sector


; Sectors 1 to 64 are reserved for the File Allocation Tables
SECTOR_1:
    dw 0xFFF0                                       ; First entry in the FAT. Media type in low byte 
    dw 0xFFFF                                       ; Second entry. Set bit 15 on clean unmount, set bit 14 on no read/write errors. Set all other bits
    dw 0xFFFF
    dw 0xFFFF

times 131072-($-SECTOR_1) db 0                      ; Set all other entries in the FAT to 0. Meaning they're available for allocation

; The Root Directory immediately follows the File Allocation Tables
ROOT_DIRECTORY:
    
    ; FAT specifies that the root directory does not have the '.' and '..' entries

    ; First entry. We'll make this the /EFI directory
    db 'EFI        '                                ; Name of file/directory. This is /EFI
    db 0x10                                         ; Set bit 4 to make it a directory
    db 0x00                                         ; Reserved, must be 0
    db 0x00                                         ; One tenth of creation time
    dw 0x00                                         ; Creation time 2 seconds granularity
    dw 0x00                                         ; Creation date
    dw 0x00                                         ; Last access date
    dw 0x00                                         ; Upper 16 bits of first sector of directory. This is 0 for FAT16
    dw 0x00                                         ; Last modification time of directory
    dw 0x00                                         ; Last modification date of directory
    dw 2                                            ; Apparently this is supposed to be the first usable clu... I have no idea what this is meant to be
    dd 32                                           ; Size of the directory in bytes

    times 2048 - ($ - ROOT_DIRECTORY) db 0



; This is the /EFI sub-directory
CLUSTER_2:
    ; This first item in this (/EFI) directory points to the directory itself
    db '.          '                                ; Directory Name
    db 0x10                                         ; Only interested in bit 4 for now which when set makes it a directory
    db 0x00                                         ; Reserved. Must be 0
    db 0x00                                         ; Creation time in tenths of a second
    dw 0x00                                         ; Creation time 2 seconds granularity
    dw 0x00                                         ; Creation date
    dw 0x00                                         ; Last access date
    dw 0x00                                         ; Upper 16 bits of first sector of directory. 0 for FAT16 et FAT12
    dw 0x00                                         ; Last modification time
    dw 0x00                                         ; Last modification date
    dw 2                                            ; Lower 16 bits of first sector of directory
    dd 0                                            ; Size of directory in bytes

    ; The second item points to the directory's parent. In this case, the root
    db '..         '                                ; Directory Name
    db 0x10                                         ; Only interested in bit 4 for now which when set makes it a directory
    db 0x00                                         ; Reserved. Must be 0
    db 0x00                                         ; Creation time in tenths of a second
    dw 0x00                                         ; Creation time 2 seconds granularity
    dw 0x00                                         ; Creation date
    dw 0x00                                         ; Last access date
    dw 0x00                                         ; Upper 16 bits of first sector of directory. 0 for FAT16 et FAT12
    dw 0x00                                         ; Last modification time
    dw 0x00                                         ; Last modification date
    dw 1                                            ; Lower 16 bits of first sector of directory
    dd 0                                            ; Size of directory in bytes

    ; Now we point to the /EFI/BOOT directory
    db 'BOOT       '                                ; Directory Name
    db 0x10                                         ; Only interested in bit 4 for now which when set makes it a directory
    db 0x00                                         ; Reserved. Must be 0
    db 0x00                                         ; Creation time in tenths of a second
    dw 0x00                                         ; Creation time 2 seconds granularity
    dw 0x00                                         ; Creation date
    dw 0x00                                         ; Last access date
    dw 0x00                                         ; Upper 16 bits of first sector of directory. 0 for FAT16 et FAT12
    dw 0x00                                         ; Last modification time
    dw 0x00                                         ; Last modification date
    dw 3                                            ; Lower 16 bits of first sector of directory
    dd 0                                            ; Size of directory in bytes

    times 2048 - ($ - CLUSTER_2) db 0

; The /EFI/BOOT directory
CLUSTER_3:
    ; This first item in this (/EFI/BOOT) directory points to the directory itself
    db '.          '                                ; Directory Name
    db 0x10                                         ; Only interested in bit 4 for now which when set makes it a directory
    db 0x00                                         ; Reserved. Must be 0
    db 0x00                                         ; Creation time in tenths of a second
    dw 0x00                                         ; Creation time 2 seconds granularity
    dw 0x00                                         ; Creation date
    dw 0x00                                         ; Last access date
    dw 0x00                                         ; Upper 16 bits of first sector of directory. 0 for FAT16 et FAT12
    dw 0x00                                         ; Last modification time
    dw 0x00                                         ; Last modification date
    dw 3                                            ; Lower 16 bits of first sector of directory
    dd 64                                           ; Size of directory in bytes

    ; The second item points to the directory's parent. In this case, the /EFI directory
    db '..         '                                ; Directory Name
    db 0x10                                         ; Only interested in bit 4 for now which when set makes it a directory
    db 0x00                                         ; Reserved. Must be 0
    db 0x00                                         ; Creation time in tenths of a second
    dw 0x00                                         ; Creation time 2 seconds granularity
    dw 0x00                                         ; Creation date
    dw 0x00                                         ; Last access date
    dw 0x00                                         ; Upper 16 bits of first sector of directory. 0 for FAT16 et FAT12
    dw 0x00                                         ; Last modification time
    dw 0x00                                         ; Last modification date
    dw 2                                            ; Lower 16 bits of first sector of directory
    dd 96                                           ; Size of directory in bytes

    times 2048 - ($ - CLUSTER_3) db 0

times 134217728-($-SECTOR_0)    db 0x0              ; Pad up to make 128 MB