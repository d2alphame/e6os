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
            ; We begin by extracting all the information that we need and storing them.
            ; Begin by preserving the following 2 registers
            push rbx
            push rbp

            lea rbp, [DATA.EFI_IMAGE_HANDLE]                         ; We're going to store the efi image handle
            mov [rbp], rcx                                           ; Store the efi image handle
            mov [rbp + 8], rdx                                       ; Store the system table

            ; Point to the simple text output protocol and also save it
            add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL 
            mov rdx, [rdx]
            push rdx                                                  ; Preserve Simple Text Output Protocol on the stack
            mov [rbp + 16], rdx                                       ; Store the Simple Text Output Protocol

            ; Store the pointer to clear screen
            mov rax, [rdx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_ClearScreen]
            mov [rbp + 24], rax

            ; Store the pointer to Output string
            mov rax, [rdx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString]
            mov [rbp + 32], rax

            mov rcx, rdx                                              ; First parameter to output string is the simple text output protocol

            ; Get ready to call OutputString
            mov rbx, [rdx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString]

            jmp DATA_DIRECTORIES.pre_start_continue                   ; Jump to the rest of the pre-start code

        times 60 - ($ - STANDARD_HEADER) db 0                                                        ; Pad the DOS stub up to 60 bytes
    
    .SIGNATURE_POINTER:          dd .PE_SIGNATURE - START                                            ; Points at the PE Signature
    .PE_SIGNATURE:               db 'PE', 0x00, 0x00                                                 ; This is the pe signature. The characters 'PE' followed by 2 null bytes
    .MACHINE_TYPE:               dw 0x8664                                                           ; Targetting the x64 machine
    .NUMBER_OF_SECTIONS:         dw 1                                                                ; Number of sections. Indicates size of section table that immediately follows the headers
    .CREATED_DATE_TIME:          dd 1748399067                                                       ; Number of seconds since 1970 since when the file was created
    .SYMBOL_TABLE_POINTER:       dd 0x00                                                             ; Pointer to the symbol table. There should be no symbol table in an image so this is 0
    .NUMBER_OF_SYMBOLS:          dd 0x00                                                             ; Because there are no symbol tables in an image
    .OPTIONAL_HEADER_SIZE:       dw OPTIONAL_HEADER_END - OPTIONAL_HEADER_START                      ; Size of the optional header
    .CHARACTERISTICS:            dw 0b0010111000100011                                               ; These are the attributes of the file

OPTIONAL_HEADER_START:
    .MAGIC_NUMBER:               dw 0x020B                        ; PE32+ (i.e. pe64) magic number

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
    ; to hold the first part of the installer's boot message instead.
    .BOOT_MESSAGE:                     db __utf16__ `E6OS 1.\0`    ; EFI strings are UTF16 and null-terminated
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
        times 32 - ($ - .BOOT_MESSAGE_CONT) db 0                       ; Padd with zeros up to 32 bytes

    ; .STACK_RESERVE_SIZE:         dq 0x200000                     ; Reserve 2MB for the stack... I guess...
    ; .STACK_COMMIT_SIZE:          dq 0x1000                       ; Commit 4kb of the stack
    ; .HEAP_RESERVE_SIZE:          dq 0x200000                     ; Reserve 2MB for the heap... I think... :D
    ; .HEAP_COMMIT_SIZE:           dq 0x1000                       ; Commit 4kb of heap
    
    ; The Loader flags field would normally be here, but since UEFI ignores it, we use it to store the hexadecimal prefix '0x'
    ; This would be useful for when we want to print out hexadecimal numbers
    .HEX_PREFIX:                   db __utf16__ `0x`
    
    ;.LOADER_FLAGS:                dd 0x00                         ; Reserved, must be zero
    
    .NUMBER_OF_RVA_AND_SIZES:      dd 0x10                         ; Number of entries in the data directory

    ; The Data directories would normally follow but UEFI does not use them. This gives us another 128 bytes we can use here.
    DATA_DIRECTORIES:
        .HEX_DIGITS:              db '0123456789ABCDEF'            ; The hex digits for when we want to print hexadecimal numbers
            times 32 - ($ - DATA_DIRECTORIES) db 0                 ; Pad up to the Security Data Directory entry

        .SECURITY:
            times 8 db 0                                            ; Pad with zeros for now. We'll use proper values when we're ready for secure boot
        .BASE_RELOC:
            times 8 db 0                                            ; Putting this here to ensure it's zeros

        .pre_start_continue:
            lea rdx, [OPTIONAL_HEADER_START.BOOT_MESSAGE]           ; Print the first part of the installer's boot message
            sub rsp, 32
            call rbx
            add rsp, 32
            pop rcx

            lea rdx, [OPTIONAL_HEADER_START.BOOT_MESSAGE_CONT]       ; Print the second part of the installer's boot message
            sub rsp, 32
            call rbx
            add rsp, 32

            ; Restore the 2 registers we preserved earlier
            pop rbp
            pop rbx

            ret

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
    lea rsi, [START]
    call e6_uefi_dump_memory
    ; mov rax, 0xB16A55CAFEBABE
    ; call e6_uefi_print_rax
    ; mov rax, 0x00
    ret

; Prints a UEFI string. UEFI strings are utf16 and null-terminated.
; In RSI: Pointer to the string. It uses UEFI's OutputString function.
e6_uefi_print_uefi_string:
    
    ; Preserve the following registers. This includes registers we use and registers EFI might clobber.
    push rax
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    push rsi

    ; Align the stack. RBP is preserved by UEFI, so it survives the call.
    push rbp                        ; Preserve RBP
    mov rbp, rsp
    and rsp, -16                    ; RSP is now 16-byte aligned
    sub rsp, 32                     ; Shadow space (keeps 16-byte alignment)

    lea rbx, [DATA.OutputString]    ; We're getting ready to call OutputString.
    mov rbx, [rbx]

    ; First parameter to OutputString is the pointer to the Simple Text Output Protocol.
    lea rcx, [DATA.EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL]
    mov rcx, [rcx]
    mov rdx, rsi                    ; RSI points to the string to print which is the second parameter to OutputString.
    sub rsp, 32                     ; Shadow space
    call rbx

    mov rsp, rbp                    ; Undo the shadow space and alignment in both at once.
    pop rbp
    
    ; Restore the registers we preserved.
    pop rsi
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret


; Prints the content of the RAX register (in hexadecimal).
; In RAX: Value to print
e6_uefi_print_rax:

    ; Align the stack
    push rbp                                     ; Preserve RBP
    mov rbp, rsp
    and rsp, -16                                 ; RSP is now 16-byte aligned
    sub rsp, 32                                  ; Shadow space (keeps 16-byte alignment)

    mov rdx, rax                                 ; Preserve the rax value in rdx
    
    ; First store the string '0x' at the destination memory address. That's the hexadecimal prefix
    xor rax, rax
    lea rdi, [DATA.rax_hex_string]
    mov al, '0'
    stosw
    mov al, 'x'
    stosw

    mov rcx, 0x10                                ; Number of nibbles in a quad word
    lea rbx, [DATA_DIRECTORIES.HEX_DIGITS]
    .loop:
        rol rdx, 0x04
        mov rax, rdx
        and rax, 0x0F
        xlatb
        stosw
        loop .loop

    lea rsi, [DATA.rax_hex_string]
    call e6_uefi_print_uefi_string

    mov rsp, rbp                                  ; Undo the shadow space and alignment both at once.
    pop rbp

    ret


; Prints the content of a block of 256 bytes of memory.
; In RSI: Pointer to memory address to dump.
e6_uefi_dump_memory:

    ; First ensure the specified memory address is aligned on a 256 byte boundary
    mov rax, rsi
    and rax, 0xFF
    jnz .unaligned

    ; Print the headers
    push rsi                            ; Preserve rsi on the stack as the follwoing lines of code affect it.
    lea rsi, [DATA.memory_dump_header]
    call e6_uefi_print_uefi_string
    pop rsi


    ; We'll be printing 16 lines of 16 bytes each. Each line begins with the memory address of that line.
    ; What follows will be done in a loop.
    mov rcx, 16                             ; We'll be processing 16 lines.
    mov r8, rcx                             ; Use this to preserve RCX because the following loop will affect it.
    lea rdi, [DATA.memory_dump_line_buffer]
    mov r9, rdi                             ; Preserve RDI in R9.
    .process_bytes:
        push rcx                            ; Preserve RCX on the stack
        ; Ensure that the memory dump buffer is zeroed out.
        xor rax, rax
        mov rcx, 134
        rep stosb
        mov rdi, r9           ; Restore RDI from R9.
        mov rcx, r8           ; Restore RCX we preserved earlier in R8.

        ; After zeroing out, print the address.
        mov r10, rsi
        xor rax, rax 
        mov rcx, 16
        lea rbx, [DATA_DIRECTORIES.HEX_DIGITS]
        .loop_address_nibbles:
            rol rsi, 4
            mov rax, rsi
            and rax, 0x0F
            xlatb
            stosw
            loop .loop_address_nibbles

        mov rsi, r10          ; Restore RSI.
        mov rcx, 16           ; Count for loop to print actual bytes.
        ; Each of the 16 bytes to print is a space followed by 2 hexadecimal characters.
        .loop_bytes:
            mov al, ' '
            stosw
            lodsb               ; Read a byte into al.
            mov rdx, rax        ; Preserve the byte in rdx.
            shr rax, 4          ; Get the upper nibble.
            and rax, 15
            xlatb
            stosw
            mov rax, rdx        ; Restore rax from rdx.
            and rax, 15         ; Get the lower nibble.
            xlatb
            stosw
            loop .loop_bytes

        ; Add \r and \n and terminate with a null
        mov al, `\r`
        stosw
        mov al, `\n`
        stosw
        xor rax, rax
        stosw

        ; Go print the buffer. Remember to preserve and restore RSI first.
        push rsi
        mov rsi, r9
        call e6_uefi_print_uefi_string
        pop rsi

        pop rcx
        loop .process_bytes

        jmp $

    
    .unaligned:
        jmp $
        stc
        ret


DATA:
align 8
    .EFI_IMAGE_HANDLE                 dq 0                     ; Image handle will be passed to us in RCX
    .EFI_SYSTEM_TABLE                 dq 0                     ; System table will be passed to us in RDX
    .EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL  dq 0                     ; The simple text output protocol
    .ClearScreen                      dq 0                     ; Pointer to the clear screen function
    .OutputString                     dq 0                     ; Pointer to the output string function
    .SomeRandomString                 db __utf16__ `Some random string\r\n\0`
    .memory_dump_header:              db __utf16__ `\r\n                  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F\r\n\0`   
    .rax_hex_string                   resb 38
    
    ; This is for buffering a line of memory before printing.
    ; 1. Each line begins with the address which is 8 bytes. Each byte is represented by 2 characters, and each
    ;    character occupies 2 bytes in utf16. For the address, this makes 8 x 2 x 2 = 32
    ; 2. Each byte is represented by a space character and 2 hexadecimal characters. This makes 3 characters per byte.
    ;    at 16 bytes per line and 2 bytes per character?? (utf16) that makes 3 x 16 x 2 = 96
    ; 3. \r, \n, and null characters (uefi strings are null terminated) at 2 bytes per character (utf16), this adds
    ;    an additional 3 x 2 = 6.
    ; 4. Total amount of memory for each line of memory dump = 32 + 96 + 6 = 134 bytes.
    .memory_dump_line_buffer          resb 134


times 4096 - ($ - START) db 0x00                               ; Pad up to 4kb
END:

%include "eficonstants.asm"
%include "e6constants.asm"
