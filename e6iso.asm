; Copyright (C) 2025 Deji Adegbite
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;
; See the LICENSE file

; Assemble with 
;     nasm -f bin -o e6.iso e6iso.asm
; This assembles into a 700MiB iso 9660 bootable CD image
; Boot up a virtual machine with the resulting image or burn it to a disk and 
; boot a real machine with it.
; See the ISO 9660 specifications and the El torito specification

; How the sectors are mapped
; ==========================
; SECTOR                          DESCRIPTION
; ------                          -----------
; 0 - 15                          32kb Reserved area
; 16                              Primary Volume Descriptor
; 17                              Boot Volume Descriptor
; 18                              Volume Descriptor Set Terminator
; 19                              Boot Catalog
; 20                              EFI System Partition for EFI booting
; ??                              Path Table (LSB)
; ??                              Path Table (MSB)
; ??                              Root Directory

START_ISO:
incbin 'e6installer.bin'
times 32768-($-START_ISO) db 0                    ; ISO 9660 specifies that the 32kb is reserved and may be used for other stuff

; Volume Descriptor Set

; Just one primary volume descriptor will be used here.

; A primary volume descriptor must be present.
PRIMARY_VOLUME_DESCRIPTOR:
    .type                       db 1                                    ; 1 for Primary Volume Descriptor
    .identifier                 db 'CD001'                              ; Identifier. Must always be 'CD001'
    .version                    db 1                                    ; Version number. Always 1
    .unused_field_1             db 0x00
    .system_identifier          db 'E6BOOT                          '   ; System Identifier
    .volume_identifier          db 'E6ISO                           '   ; Volume Identifier
    .unused_field_2             resb 8
    .volume_space_size                                                  ; Number of sectors in both endian that make up the volume
        .vol_space_size_L       dd 0x00057800
        .vol_space_size_B       dd 0x00780500
    .unused_field_3             resb 32
    .volume_set_size                                                    ; Size of the volume set recorded in both endian
        .vol_set_size_L         dw 0x0001
        .vol_set_size_B         dw 0x0100
    .volume_sequence_number                                             ; The sequence number of this volume in its volume set
        .vol_sequence_num_L     dw 0x0001
        .vol_sequence_num_B     dw 0x0100
    .logical_block_size                                                 ; Basically sector size
        .logical_blk_size_L     dw 0x0800
        .logical_blk_size_B     dw 0x0008
    .path_table_size                                                    ; Size in bytes of the path table
        .path_tbl_size_L        dd 0x00000009
        .path_tbl_size_B        dd 0x09000000
    .lba_path_table_l           dd 0x00000013                           ; Sector of little endian path-table
    .lba_optional_path_table_l  dd 0x00                                 ; Not present so set to 0
    .lba_path_table_b           dd 0x14000000                           ; Sector of big endian path-table
    .lba_optional_path_table_b  dd 0x00                                 ; Not present also set to 0
    .root_directory_record                                              ; Record for the root directory
        .length_of_record       db 34                                   ; Length of Directory Record
        .extended_attr_rec_len  db 0x00                                 ; Extended attribute record length
        .lba_of_directory                                               ; First sector of the directory in mixed endian
            .lba_of_dir_L       dd 0x00000015
            .lba_of_dir_B       dd 0x15000000
        .extent_of_directory                                            ; Number of sectors in the directory in both endian
            .extent_of_dir_L    dd 0x00000058
            .extent_of_dir_B    dd 0x58000000
        .recording_date_time    times 7 db 0                            ; Recording date and time. Don't need this so set to 0
        .flags                  db 0b00000010                           ; Flags. Bit 1 identifies it as a directory
        .file_unit_size         db 0                                    ; Don't know what this is for, but I'm making it 0
        .interleave_gap         db 0                                    ; Again, don't know what this means
        .dir_vol_seq_num                                                ; The ordinal number of the volume this dir is on on the vol set
            .dir_vol_seq_num_L  dw 0x0001
            .dir_vol_seq_num_B  dw 0x0100
        .length_of_dir_name     db 1                                    ; For the root directory, this must always be 1
        .name_of_root_dir       db 0x00                                 ; Always 0x00 for the root directory
    .volume_set_identifier      db 'E6ISO'                              ; Identifier for the volume set
        .vol_set_id_padding     times 123 db ' '                        ; Padding for volume set identifier. Pad up to 128 bytes
    .publisher_identifier       times 128 db ' '                        ; Don't need publisher_identifier  so fill with blanks
    .data_preparer              times 128 db ' '                        ; Don't need this either so fill with blanks
    .application_identifier     times 128 db ' '                        ; Same
    .copyright_file_identifier  times 37 db ' '                         ; ...
    .abstract_file_identifier   times 37 db ' '
    .bibliographic_identifier   times 37 db ' '
    .creation_date_time                                                 ; Date and time the volume was created
        .creation_year          db '2022'
        .creation_month         db '05'
        .creation_day           db '19'
        .creation_hour          db '13'
        .creation_minute        db '50'
        .creation_second        db '00'
        .creation_seconds_hdrth db '00'                                 ; Hundredths of a second
        .creation_gmt_offset    db 0x01                                 ; Offset from gmt in number of 15 minutes intervals
    .modificaiton_date_time                                             ; Date and time the volume was last modified
        .mod_year               db '0000'
        .mod_month              db '00'
        .mod_day                db '00'
        .mod_hour               db '00'
        .mod_minute             db '00'
        .mod_second             db '00'
        .mod_seconds_hdrth      db '00'
        .mod_gmt_offset         db 0x00
    .expiration_date_time                                               ; Time and date the volume may be considered obsolete
        .expires_year           db '0000'
        .expires_month          db '00'
        .expires_day            db '00'
        .expires_hour           db '00'
        .expires_minute         db '00'
        .expires_second         db '00'
        .expires_seconds_hdrth  db '00'
        .expires_gmt_offset     db 0x00
    .effective_date_time                                                ; Date and time volume starts taking effect
        .eff_year               db '0000'
        .eff_month              db '00'
        .eff_day                db '00'
        .eff_hour               db '00'
        .eff_minute             db '00'
        .eff_second             db '00'
        .eff_seconds_hdrth      db '00'
        .eff_gmt_offset         db 0x00
    .file_structure_version     db 0x01                                 ; Primary volume descriptor version set to 1
    .reserved_for_future_use_1  db 0x00                                 ; Reserved for future standardization use
    .reserved_for_application   resb 512                                ; Applications can use this as they see fit
    .reserved_for_future_use_2  times 653 db 0x00                       ; Reserved for future standardization use


; Boot volume descriptor goes here immediately after the primary volume descriptor
BOOT_VOLUME_DESCRIPTOR:
    .type                       db 0
    .identifier                 db 'CD001'
    .version                    db 1
    .boot_system_identifier     db 'EL TORITO SPECIFICATION'
        boot_sys_id_padding     times 9 db 0x00
    .unused                     times 32 db 0x00
    .lba_of_boot_catalog        dd 0x13                                ; The boot catalog will be immediately after the volume descriptor set terminator
    .more_unused                times 1973 db 0x00

; A Volume descriptor set terminator
VOLUME_DESCRIPTOR_SET_TERMINATOR:
    .type            db 255                                            ; Making it the volume descriptor set terminator
    .identifier      db 'CD001'
    .version         db 1
    times 2041 db 0                                                    ; Add more paddings to make 2048 bytes for the descriptor

; The boot catalog for el-torito booting
BOOT_CATALOG:
    VALIDATION_ENTRY:                                                   ; This must be the first entry in the boot catalog
        db 0x01                                                         ; Must be 1
        .platform_id            db 0x00                                 ; 0x00 for 80x86. Note 0xEF for EFI
        .reserved               dw 0x00
        .manufacturer           db 'E6 SYSTEMS'                         ; The manufacturer
                                times 14 db 0x00                        ; Remember strings must be padded with 0s to their full lengths
        .checksum               dw 0x00
                                db 0x55
                                db 0xAA
    INITIAL_DEFAULT_ENTRY:
        .boot_indicator         db 0x88                                 ; Bootable. 0x00 for not bootable
        .boot_media_type        db 0x00                                 ; No emulation
        .load_segment           dw 0x800                                ; Segment where the image will be loaded. Make this 0 to default to 0x7C0
        .system_type            db 0xEE                                 ; Must be a copy of byte 5 from the partition table in the boot image
        .unused_1               db 0x00
        .sector_count           dw 0x10                                 ; Number of sectors to load into memory during boot.
        .lba_of_boot_image      dd 0x00                                 ; LBA of boot image. Intending to put the boot image in the 32kb systems area
                                times 20 db 0x00

    ; An Entry for EFI. First a section header and then one or more section entries
    EFI_SECTION_HEADER:
        .header_indicator       db 0x91                                 ; No more section headers. If there's more, use 0x90
        .platform_id            db 0xEF                                 ; For EFI. Set to 0x00 for 80x86
        .section_entries_count  dw 0x01                                 ; Number of section entries following this header. Set to 1
        .id_string              db 'E6 SYSTEMS'
                                times 18 db 0x00
    EFI_SECTION_ENTRY:
        .boot_indicator         db 0x88
        .boot_media_type        db 0x00
        .load_segment           dw 0x00
        .system_type            db 0xEF                                 ; We'll make this an EFI System Partition
        .unsued                 db 0x00
        .sector_count           dw 0x01                                 ; Number of sectors to load into the segment when booting
        .lba_of_boot_image      dd 0x14                                 ; LBA of the boot image intended to be after the boot catalog
        .selection_criteria     db 0x00                                 ; I have no idea what this is supposed to mean
        .vendor_unique_sel_crit times 19 db 0x00                        ; nor this                

PATH_TABLE_L                                                            ; Path table with little endian values starts here
    .length_of_dir_name         db 1
    .extended_attr_rec_len      db 0
    .lba_of_dir                 dd 0x00000015
    .index_of_parent            dw 0x00
    .dir_id                     db 0x00
    times 2039 db 0

PATH_TABLE_B                                                            ; Path table with big endian values starts here
    .length_of_dir_name         db 1
    .extended_attr_rec_len      db 0
    .lba_of_dir                 dd 0x15000000
    .index_of_parent            dw 0x00
    .dir_id                     db 0x00
    times 2039 db 0

ROOT_DIRECTORY_ENTRIES:                                                  ; Entries for the Root directory
    
    ; Entry that points to the current directory, i.e. the directory itself
    SELF_DIR_ENTRY:
        .record_length              db 34
        .extended_attr_rec_len      db 0
        .lba_of_directory
            .lba_L                  dd 0x00000015
            .lba_B                  dd 0x15000000
        .extent_of_directory
            .extent_L               dd 0x000000A2
            .extent_B               dd 0xA2000000
        .recording_date_time        times 7 db 0
        .flags                      db 0b00000011
        .file_unit_size             db 0
        .interleave_gap             db 0
        .dir_vol_seq_num
            .vol_seq_L              dw 0x0001
            .vol_seq_B              dw 0x0100
        .length_of_name             db 0x01
        .name                       db '.' 

    ; Entry that points to the parent directory. But as this is the root directory, it will point back to itself
    PARENT_DIR_ENTRY:
        .record_length              db 36
        .extended_attr_rec_len      db 0
        .lba_of_directory
            .lba_L                  dd 0x00000015
            .lba_B                  dd 0x15000000
        .extent_of_directory
            .extent_L               dd 0x000000A2
            .extent_B               dd 0xA2000000
        .recording_date_time        times 7 db 0
        .flags                      db 0b00000011
        .file_unit_size             db 0
        .interleave_gap             db 0
        .dir_vol_seq_num
            .vol_seq_L              dw 0x0001
            .vol_seq_B              dw 0x0100
        .length_of_name             db 0x02
        .name                       db '..'
        .padding                    db 0 

    SAMPLE_FILE_ENTRY:
        .record_length              db 46
        .extended_attr_rec_len      db 0
        .lba_of_directory
            .lba_L                  dd 0x00000016
            .lba_B                  dd 0x16000000
        .extent_of_directory
            .extent_L               dd 0x00000013
            .extent_B               dd 0x13000000
        .recording_date_time        times 7 db 0
        .flags                      db 0b00000000
        .file_unit_size             db 0
        .interleave_gap             db 0
        .dir_vol_seq_num
            .vol_seq_L              dw 0x0001
            .vol_seq_B              dw 0x0100
        .length_of_name             db 0x0C
        .name                       db 'SAMPLE.TXT;1'
        .padding                    db 0

    ANOTHER_FILE_ENTRY:
        .record_length              db 46
        .extended_attr_rec_len      db 0
        .lba_of_directory
            .lba_L                  dd 0x00000017
            .lba_B                  dd 0x17000000
        .extent_of_directory
            .extent_L               dd 0x00000014
            .extent_B               dd 0x14000000
        .recording_date_time        times 7 db 0
        .flags                      db 0b00000000
        .file_unit_size             db 0
        .interleave_gap             db 0
        .dir_vol_seq_num
            .vol_seq_L              dw 0x0001
            .vol_seq_B              dw 0x0100
        .length_of_name             db 0x0D
        .name                       db 'ANOTHER.TXT;1'
    times 2048-($-ROOT_DIRECTORY_ENTRIES) db 0

SAMPLE_FILE: db 'This is a test file'

align 2048
ANOTHER_FILE: db 'This is another file'
times 734003200-($-START_ISO) db 0                          ; Pad up to make a 700MB ISO image