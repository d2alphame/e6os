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

Bits 64
DEFAULT REL

START:
HEADER_START:
STANDARD_HEADER:
    db "MZ"
    ; This first 60 bytes would normally be the MSDOS header and DOS Stub. However, e6 would like to use these bytes for itself.
    
    times 60 - ($ - START) db 0                                 ; Pad up to 60 bytes. This is useful so NASM can squeal if we go past 60 bytes

    .SIGNATURE_POINTER:          dd .PE_SIGNATURE - START                                            ; Pointer to the PE Signature
    .PE_SIGNATURE:               db 'PE', 0x00, 0x00                                                 ; This is the pe signature. The characters 'PE' followed by 2 null bytes
    .MACHINE_TYPE:               dw 0x8664                                                           ; Targetting the x64 machine
    .NUMBER_OF_SECTIONS:         dw 1                                                                ; Number of sections. Indicates size of section table that immediately follows the headers
    .CREATED_DATE_TIME:          dd 1748399067                                                       ; Number of seconds since 1970 since when the file was created
    .SYMBOL_TABLE_POINTER:       dd 0x00                                                             ; Pointer to the symbol table. There should be no symbol table in an image so this is 0
    .NUMBER_OF_SYMBOLS:          dd 0x00                                                             ; Because there are no symbol tables in an image
    .OPTIONAL_HEADER_SIZE:       dw OPTIONAL_HEADER_END - OPTIONAL_HEADER_START                      ; Size of the optional header
    .CHARACTERISTICS:            dw 0b0010111000100010                                               ; These are the attributes of the file

OPTIONAL_HEADER_START:
    .MAGIC_NUMBER:               dw 0x020B                       ; PE32+ (i.e. pe64) magic number
    .MAJOR_LINKER_VERSION:       db 0                            ; I'm sure this isn't needed. So set to 0
    .MINOR_LINKER_VERSION:       db 0                            ; This too
    .SIZE_OF_CODE:               dd END - START                  ; The size of the code section
    .INITIALIZED_DATA_SIZE:      dd END - START                  ; Size of initialized data section
    .UNINITIALIZED_DATA_SIZE:    dd 0x00                         ; Size of uninitialized data section
    .ENTRY_POINT_ADDRESS:        dd EntryPoint - START           ; Address of entry point relative to image base when the image is loaded in memory
    .BASE_OF_CODE_ADDRESS:       dd START                        ; Relative address of base of code
    .IMAGE_BASE:                 dq 0x10000                      ; Where in memory we would prefer the image to be loaded at
    .SECTION_ALIGNMENT:          dd 0x1000                       ; Alignment in bytes of sections when they are loaded in memory. Align to page boundry (4kb)
    .FILE_ALIGNMENT:             dd 0x1000                       ; Alignment of sections in the file. Also align to 4kb
    .MAJOR_OS_VERSION:           dw 0x00                         ; I'm not sure UEFI requires these and the following 'version woo'
    .MINOR_OS_VERSION:           dw 0x00                         ; More of these version thingies are to follow. Again, not sure UEFI needs them
    .MAJOR_IMAGE_VERSION:        dw 0x00                         ; Major version of the image
    .MINOR_IMAGE_VERSION:        dw 0x00                         ; Minor version of the image
    .MAJOR_SUBSYSTEM_VERSION:    dw 0x00                         ; 
    .MINOR_SUBSYSTEM_VERSION:    dw 0x00                         ;
    .WIN32_VERSION_VALUE:        dd 0x00                         ; Reserved, must be 0
    .IMAGE_SIZE:                 dd END - START                  ; The size in bytes of the image when loaded in memory including all headers
    .HEADERS_SIZE:               dd HEADER_END - HEADER_START    ; Size of all the headers
    .CHECKSUM:                   dd 0x00                         ; Hoping this doesn't break the application
    .SUBSYSTEM:                  dw 10                           ; The subsystem. In this case we're making a UEFI application.
    .DLL_CHARACTERISTICS:        dw 0b000011110010000            ; I honestly don't know what to put here
    .STACK_RESERVE_SIZE:         dq 0x200000                     ; Reserve 2MB for the stack... I guess...
    .STACK_COMMIT_SIZE:          dq 0x1000                       ; Commit 4kb of the stack
    .HEAP_RESERVE_SIZE:          dq 0x200000                     ; Reserve 2MB for the heap... I think... :D
    .HEAP_COMMIT_SIZE:           dq 0x1000                       ; Commit 4kb of heap
    .LOADER_FLAGS:               dd 0x00                         ; Reserved, must be zero
    .NUMBER_OF_RVA_AND_SIZES:    dd 0x00                         ; Number of entries in the data directory

OPTIONAL_HEADER_END:

SECTION_HEADERS:
    SECTION_ALL:
        .name                       db ".all", 0x00, 0x00, 0x00, 0x00
        .virtual_size               dd END - START
        .virtual_address            dd START
        .size_of_raw_data           dd END - START
        .pointer_to_raw_data        dd START
        .pointer_to_relocations     dd 0                                    ; Set to 0 for executable images
        .pointer_to_line_numbers    dd 0                                    ; There are no COFF line numbers
        .number_of_relocations      dw 0                                    ; Set to 0 for executable images
        .number_of_line_numbers     dw 0                                    ; Should be 0 for images
        .characteristics            dd 0x70000060                           ; Need to read up more on this

CODE:
EntryPoint:
    mov [EFI_IMAGE_HANDLE], rcx
    mov [EFI_SYSTEM_TABLE], rdx

    ; Point to the EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
    add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
    mov rdx, [rdx]

    mov rcx, rdx

    add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString
    mov rax, [rdx]
    lea rdx, [hello_message]

    sub rsp, 40
    call rax

    add rsp, 40
    xor rax, rax
    ret


align 16
DATA:
    EFI_IMAGE_HANDLE    dq 0x00                                             ; EFI will give us this in rcx
    EFI_SYSTEM_TABLE    dq 0x00                                             ; And this in rdx
    
    hello_message db __utf16__ `Hello_world\0`                              ; EFI strings are UTF16 and null-terminated


align 4096
HEADER_END:
END:

EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL                 equ 64
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString    equ 8