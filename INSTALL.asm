; Copyright (C) 2022-2026 Deji Adegbite
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

; This is the source code for the installer of the e6 Operating System. 


Bits 64
DEFAULT REL

START:
HEADER_START:
STANDARD_HEADER:
    .DOS_SIGNATURE:              db "MZ"                                                             ; DOS Signature. This is required
        
        ; A DOS stub should normally be here but uefi doesn't need it, so this will be filled
        ; with something a bit more useful.
        .pre_start: 
            push rbx
            lea rbx, [DATA_DIRECTORIES.EFI_IMAGE_HANDLE]        ; We're going to store the efi image handle
            mov [rbx], rcx                                      ; Store the efi image handle
            add rbx, 8                                          ; Point to the memory address to store the system table
            mov [rbx], rdx                                      ; Store the pointer to the system table

            ; Point to the simple text output protocol
            add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL 
            mov rdx, [rdx]
            push rdx                                            ; Preserve Simple Text Output Protocol on the stack
            mov rcx, rdx                                        ; Killing 2 birds with 1 stone. This happens to be the first parameter for Output String
            add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString   ; Preparing to make a call to OutputString
            mov rbx, [rdx]

            lea rdx, [OPTIONAL_HEADER_START.BOOT_MESSAGE]           ; Print the first part of the installer's boot message
            sub rsp, 32
            call rbx
            add rsp, 32

            ; Print the second part of the installer's boot message and continue from there
            jmp DATA_DIRECTORIES.pre_start_continue                 ; Jump to the rest of the pre-start code

        times 60 - ($ - STANDARD_HEADER) db 0                                                        ; Pad the DOS stub up to 60 bytes
    
    .SIGNATURE_POINTER:          dd .PE_SIGNATURE - START                                            ; Points at the PE Signature
    ; .DOS_ALIGNMENT:            dw 0x00                                                             ; This is just to make the PE below align on a 4-byte boundary
    .PE_SIGNATURE:               db 'PE', 0x00, 0x00                                                 ; This is the pe signature. The characters 'PE' followed by 2 null bytes
    .MACHINE_TYPE:               dw 0x8664                                                           ; Targetting the x64 machine
    .NUMBER_OF_SECTIONS:         dw 1                                                                ; Number of sections. Indicates size of section table that immediately follows the headers
    .CREATED_DATE_TIME:          dd 1748399067                                                       ; Number of seconds since 1970 since when the file was created
    .SYMBOL_TABLE_POINTER:       dd 0x00                                                             ; Pointer to the symbol table. There should be no symbol table in an image so this is 0
    .NUMBER_OF_SYMBOLS:          dd 0x00                                                             ; Because there are no symbol tables in an image
    .OPTIONAL_HEADER_SIZE:       dw OPTIONAL_HEADER_END - OPTIONAL_HEADER_START                      ; Size of the optional header
    .CHARACTERISTICS:            dw 0b0010111000100011                                               ; These are the attributes of the file

OPTIONAL_HEADER_START:
    .MAGIC_NUMBER:               dw 0x020B                       ; PE32+ (i.e. pe64) magic number

    ; The major linker version and the minor linker version would normally follow. Use these to store the major and minor e6os specification version
    ; that this installer targets
    .E6_TARGET_MAJOR_VERSION     db 1
    .E6_TARGET_MINOR_VERSION     db 0

    ; .MAJOR_LINKER_VERSION:       db 0                            ; I'm sure this isn't needed. So set to 0
    ; .MINOR_LINKER_VERSION:       db 0                            ; This too
    .SIZE_OF_CODE:               dd END - CODE                   ; The size of the code section
    .INITIALIZED_DATA_SIZE:      dd END - CODE                   ; Size of initialized data section
    .UNINITIALIZED_DATA_SIZE:    dd 0x00                         ; Size of uninitialized data section
    .ENTRY_POINT_ADDRESS:        dd EntryPoint - START           ; Address of entry point relative to image base when the image is loaded in memory
    .BASE_OF_CODE_ADDRESS:       dd CODE                         ; Relative address of base of code
    .IMAGE_BASE:                 dq 0x400000                     ; Where in memory we would prefer the image to be loaded at
    .SECTION_ALIGNMENT:          dd 0x1000                       ; Alignment in bytes of sections when they are loaded in memory
    .FILE_ALIGNMENT:             dd 0x1000                       ; Alignment of sections in the file

    ; What would normally follow should be MAJOR_OS_VERSION (2 bytes), MINOR_OS_VERSION (2 bytes), MAJOR_IMAGE_VERSION (2 bytes), MINOR_IMAGE_VERSION (2 bytes),
    ; MAJOR_SUBSYSTEM_VERSION (2 bytes), MINOR_SUBSYSTEM_VERSION (2 bytes), and WIN32_VERSION_VALUE (4 bytes). This gives a total of 16 bytes. This will be used
    ; to hold the boot message instead.
    .BOOT_MESSAGE:                     db __utf16__ `E6OS 1.\0`      ; EFI strings are UTF16 and null-terminated
        times 16 - ($ - .BOOT_MESSAGE) db 0                        ; Pad up the boot message to 16 bytes

    ; .MAJOR_OS_VERSION:           dw 0x00                         ; I'm not sure UEFI requires these and the following 'version woo'
    ; .MINOR_OS_VERSION:           dw 0x00                         ; More of these version thingies are to follow. Again, not sure UEFI needs them
    ; .MAJOR_IMAGE_VERSION:        dw 0x00                         ; Major version of the image
    ; .MINOR_IMAGE_VERSION:        dw 0x00                         ; Minor version of the image
    ; .MAJOR_SUBSYSTEM_VERSION:    dw 0x00                         ; 
    ; .MINOR_SUBSYSTEM_VERSION:    dw 0x00                         ;
    ; .WIN32_VERSION_VALUE:        dd 0x00                         ; Reserved, must be 0
    
    .IMAGE_SIZE:                 dd END - START                  ; The size in bytes of the image when loaded in memory including all headers
    .HEADERS_SIZE:               dd HEADER_END - HEADER_START    ; Size of all the headers
    .CHECKSUM:                   dd 0x00                         ; Hoping this doesn't break the application
    .SUBSYSTEM:                  dw 10                           ; The subsystem. In this case we're making a UEFI application.
    .DLL_CHARACTERISTICS:        dw 0b000011110010000            ; I honestly don't know what to put here

    ; UEFI doesn't use the following fields: stack size to reserve, stack size to commit, heap size to reserve, and heap size to commit. At 8 bytes each, this gives
    ; us 32 bytes we can use.
    .BOOT_MESSAGE_CONT:              db __utf16__ `0 INSTALLER\r\n\0`  ; Continuation of the installer boot message
        times 32 - ($ - .BOOT_MESSAGE_CONT) db 0                     ; Padd with zeros up to 32 bytes

    ; .STACK_RESERVE_SIZE:         dq 0x200000                     ; Reserve 2MB for the stack... I guess...
    ; .STACK_COMMIT_SIZE:          dq 0x1000                       ; Commit 4kb of the stack
    ; .HEAP_RESERVE_SIZE:          dq 0x200000                     ; Reserve 2MB for the heap... I think... :D
    ; .HEAP_COMMIT_SIZE:           dq 0x1000                       ; Commit 4kb of heap
    .LOADER_FLAGS:               dd 0x00                         ; Reserved, must be zero
    .NUMBER_OF_RVA_AND_SIZES:    dd 0x10                         ; Number of entries in the data directory

    ; The Data directories would normally follow but UEFI does not use them. This gives us another 128 bytes we can use here.
    DATA_DIRECTORIES:

        .EFI_IMAGE_HANDLE                 dq 0                     ; Image handle will be passed to us in RCX
        .EFI_SYSTEM_TABLE                 dq 0                     ; System table will be passed to us in RDX
        .OutputString                     dq 0                     ; Pointer to the output string function
        .ClearString                      dq 0                     ; Pointer to the clear screen function

        times 32 - ($ - DATA_DIRECTORIES) db 0                     ; Pad up to the Security Data Directory entry

        .SECURITY:
            times 8 db 0                                           ; Pad with zeros for now. We'll use proper values when we're ready for secure boot
        .BASE_RELOC:
            times 8 db 0                                           ; Putting this here to ensure it's zeros

        .pre_start_continue:
            pop rcx
            lea rdx, [OPTIONAL_HEADER_START.BOOT_MESSAGE_CONT]
            sub rsp, 32
            call rbx
            add rsp, 32

            pop rbx
            jmp $

        times 128 - ($ - DATA_DIRECTORIES) db 0                    ; Pad up the data directory entries up to 128 bytes

    ; DATA_DIRECTORIES:    times 16 dq 0

    
OPTIONAL_HEADER_END:

SECTION_HEADERS:
    SECTION_ALL:
        .name                       db ".all", 0x00, 0x00, 0x00, 0x00
        .virtual_size               dd END - CODE
        .virtual_address            dd CODE
        .size_of_raw_data           dd END - CODE
        .pointer_to_raw_data        dd CODE
        .pointer_to_relocations     dd 0                                    ; Set to 0 for executable images
        .pointer_to_line_numbers    dd 0                                    ; There are no COFF line numbers
        .number_of_relocations      dw 0                                    ; Set to 0 for executable images
        .number_of_line_numbers     dw 0                                    ; Should be 0 for images
        .characteristics            dd 0x70000060                           ; Need to read up more on this
HEADER_END:

CODE:
    EntryPoint:
        call STANDARD_HEADER.pre_start
        mov rax, 0x00
        ret


    ; Save the Image handle and the system table pointer as soon as we receive them
;     lea rbx, [START]
;     mov [rbx + IMAGE_HANDLE_OFFSET], rcx
;     mov [rbx + SYSTEM_TABLE_OFFSET], rdx
; 
;     ; Point to the EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
;     add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
;     mov rdx, [rdx]
; 
;     mov rcx, rdx
; 
;     add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString
;     mov rax, [rdx]
;     lea rdx, [OPTIONAL_HEADER_START.BOOT_MESSAGE]    ; The boot message. We're going to print it.
; 
;     sub rsp, 40                 ; Make room on the stack along with the shadow space
;     call rax
;     add rsp, 40                 ; Restore rsp
;     mov rax, EFI_SUCCESS         ; UEFI use rax = 0 for success

    ; jmp $
    ; ret

times 4096 - ($ - START) db 0x00                      ; Pad up to 4kb
; HEADER_END:
END:

%include "eficonstants.asm"
%include "e6constants.asm"
