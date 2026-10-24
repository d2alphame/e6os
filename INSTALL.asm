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


; A struc that will be useful for efi pointers, functions, variables, etc
struc efi 
    .IMAGE_HANDLE                 resq 1                     ; Image handle will be passed to us in RCX
    .SYSTEM_TABLE                 resq 1                     ; System table will be passed to us in RDX
    .BOOT_SERVICES_TABLE          resq 1                     ; The boot services table.
    .SIMPLE_TEXT_OUTPUT_PROTOCOL  resq 1                     ; The simple text output protocol
    .ClearScreen                  resq 1                     ; Pointer to the clear screen function
    .OutputString                 resq 1                     ; Pointer to the output string function
    .LocateHandleBuffer           resq 1                     ; For the LocateHandleBuffer function will be needed to enumerate storage devices and others
    .HandleProtocol               resq 1                     ; For HandleProtocol
endstruc

    
START:
HEADER_START:
STANDARD_HEADER:
    .DOS_SIGNATURE:              db "MZ"                                                             ; DOS Signature. This is required

        align 8
        .EFI_BLOCK_IO_PROTOCOL_GUID:
            dd 0x964E5B21
            dw 0x6459
            dw 0x11D2
            db 0x8E, 0x39, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B

        ; A DOS stub should normally be here but uefi doesn't need it, so this will be filled
        ; with something a bit more useful.
        .pre_start:
            ; We begin by extracting all the information that we need and storing them.
            ; Begin by preserving the following 2 registers
            push rbx
            push rbp

            lea rbp, [BSS.EFI]                                       ; We're going to store the efi image handle
            mov [rbp + efi.IMAGE_HANDLE], rcx                        ; Store the efi image handle
            mov [rbp + efi.SYSTEM_TABLE], rdx                                       ; Store the system table

            ; Point to the simple text output protocol and also save it
            add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL 
            mov rdx, [rdx]
            push rdx                                                  ; Preserve Simple Text Output Protocol on the stack
            mov [rbp + efi.SIMPLE_TEXT_OUTPUT_PROTOCOL], rdx          ; Store the Simple Text Output Protocol

            jmp DATA_DIRECTORIES.pre_start_continue                   ; Jump to the rest of the pre-start code

        times 60 - ($ - STANDARD_HEADER) db 0                                                        ; Pad the DOS stub up to 60 bytes
    
    .SIGNATURE_POINTER:          dd .PE_SIGNATURE - START                                            ; Points at the PE Signature
    .PE_SIGNATURE:               db 'PE', 0x00, 0x00                                                 ; This is the pe signature. The characters 'PE' followed by 2 null bytes
    .MACHINE_TYPE:               dw 0x8664                                                           ; Targetting the x64 machine
    .NUMBER_OF_SECTIONS:         dw 2                                                                ; Number of sections. Indicates size of section table that immediately follows the headers
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
    .UNINITIALIZED_DATA_SIZE:    dd BSS_END - BSS                ; Size of uninitialized data section
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
    
    .IMAGE_SIZE:                 dd 0x3000                       ; The size in bytes of the image when loaded in memory including all headers
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
    
    ; The Loader flags field would normally be here, but since UEFI ignores it.
    .CONSEC_ZEROS:                    db 1                            ; We use this to detect leading zeros when printing in decimal
        times 4 - ($ - .CONSEC_ZEROS) db 0x00
    
    ;.LOADER_FLAGS:                   dd 0x00                         ; Reserved, must be zero
    
    .NUMBER_OF_RVA_AND_SIZES:         dd 0x10                         ; Number of entries in the data directory

    ; The Data directories would normally follow but UEFI does not use them. This gives us another 128 bytes we can use here.
    DATA_DIRECTORIES:
        .HEX_DIGITS:              db '0123456789ABCDEF'            ; The hex digits for when we want to print hexadecimal numbers
            times 32 - ($ - DATA_DIRECTORIES) db 0                 ; Pad up to the Security Data Directory entry

        .SECURITY:
            times 8 db 0                                            ; Pad with zeros for now. We'll use proper values when we're ready for secure boot
        .BASE_RELOC:
            times 8 db 0                                            ; Putting this here to ensure it's zeros

        .pre_start_continue:
            ; Store the pointer to clear screen
            mov rax, [rdx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_ClearScreen]
            mov [rbp + efi.ClearScreen], rax

            ; Store the pointer to Output string
            mov rax, [rdx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString]
            mov [rbp + efi.OutputString], rax
            mov rcx, rdx                                            ; First parameter to output string is the simple text output protocol
            
            ; Get ready to call OutputString
            mov rbx, [rdx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString]

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

        times 128 - ($ - DATA_DIRECTORIES) db 0                       ; Pad up the data directory entries up to 128 bytes

    ; DATA_DIRECTORIES:    times 16 dq 0

OPTIONAL_HEADER_END:

SECTION_HEADERS:
    SECTION_ALL:
        CODE_SECTION_HEADER:
            .name                       db ".code", 0x00, 0x00, 0x00
            .virtual_size               dd END - CODE
            .virtual_address            dd CODE - START
            .size_of_raw_data           dd END - CODE
            .pointer_to_raw_data        dd CODE - START
            .pointer_to_relocations     dd 0                                    ; Set to 0 for executable images
            .pointer_to_line_numbers    dd 0                                    ; There are no COFF line numbers
            .number_of_relocations      dw 0                                    ; Set to 0 for executable images
            .number_of_line_numbers     dw 0                                    ; Should be 0 for images
            .characteristics            dd 0x60000060                           ; Need to read up more on this
        
        BSS_SECTION_HEADER:
            .name                       db ".bss", 0x00, 0x00, 0x00, 0x00
            .virtual_size               dd BSS_END - BSS
            .virtual_address            dd BSS - START
            .size_of_raw_data           dd 0
            .pointer_to_raw_data        dd 0
            .pointer_to_relocations     dd 0
            .pointer_to_line_numbers    dd 0
            .number_of_relocations      dw 0
            .number_of_line_numbers     dw 0
            .characteristics            dd 0xC0000080
    
    EXTRAS:
        .powers_of_10:
            dq 10_000_000_000_000_000_000
            dq 1_000_000_000_000_000_000
            dq 100_000_000_000_000_000
            dq 10_000_000_000_000_000
            dq 1_000_000_000_000_000
            dq 100_000_000_000_000
            dq 10_000_000_000_000
            dq 1_000_000_000_000
            dq 100_000_000_000
            dq 10_000_000_000
            dq 1_000_000_000
            dq 100_000_000
            dq 10_000_000
            dq 1_000_000
            dq 100_000
            dq 10_000
            dq 1_000
            dq 100
            dq 10
            dq 1
        count_powers_of_10 equ ($ - .powers_of_10) >> 3

        .test_string: db __utf16__ `This is a test\0`      ; String for doing tests during development.

    times 4096 - ($ - START)            db 0
HEADER_END:



CODE:
EntryPoint:
    call STANDARD_HEADER.pre_start

    xor rax, rax
    not rax
    mov rcx, 8
    mov rdx, 21
    call e6_uefi_print_fraction
    jmp $

    ; Get the pointer to the boot services table. We start by grabbing the systems table. From the systems table we can
    ; get the boot services table.
    lea rbx, [BSS.EFI + efi.SYSTEM_TABLE]
    mov rbx, [rbx]
    add rbx, EFI_BOOT_SERVICES_TABLE
    mov rbx, [rbx]                        ; Now we're pointing to the boot services table.

    ; Store the pointer to the boot services table in memory
    lea rdi, [BSS.EFI + efi.BOOT_SERVICES_TABLE]
    mov [rdi], rbx

    ; Go grab LocateHandleBuffer and also store it.
    add rbx, EFI_BOOT_SERVICES_TABLE_LocateHandleBuffer
    mov rbx, [rbx]                        ; Get the pointer to LocateHandleBuffer
    lea rdi, [BSS.EFI + efi.LocateHandleBuffer]
    mov [rdi], rbx

    ; Next call LocateHandleBuffer
    mov rcx, 2                                               ; First parameter is search type. 2 => Search by Protocol
    lea rdx, [STANDARD_HEADER.EFI_BLOCK_IO_PROTOCOL_GUID]    ; Second parameter is GUID of the protocol. In this case the GUID of Block IO Protocol
    xor r8, r8                                               ; Third parameter is search key. This is null for searcy by protocol
    lea r9, [BSS.handle_count]                               ; Fourth parameter is where LocateHandleBuffer will store the number of handles that match the protocol
    sub rsp, 48                                              ; Make room for the fifth parameter and shadow space
    lea rdi, [BSS.handle_buffer]                             ; The fifth parameter which will be on the stack
    mov [rsp + 32], rdi                                      ; Put that fifth parameter on the stack
    call rbx
    add rsp, 48                  ; Remember to restore the stack

    ; RAX Should be 0 on success 
    test rax, rax
    jnz .error_locate_handle_buffer

    ; Go grab HandleProtocol. HandleProtocol will later be called on all the handles LocateHandleBuffer returned
    lea rbx, [BSS.EFI + efi.BOOT_SERVICES_TABLE]
    mov rbx, [rbx]
    mov rbx, [rbx + EFI_BOOT_SERVICES_TABLE_HandleProtocol]  ; Get the pointer to HandleProtocol
    lea rdi, [BSS.EFI + efi.HandleProtocol]
    mov [rdi], rbx                                           ; Store HandleProtocol

    ; Need to loop through the handles and call HandleProtocol on each handle. Get the number of handles into RCX.
    lea rcx, [BSS.handle_count]
    mov rcx, [rcx]
    
    ; Get the pointer to the handle buffer into RSI
    lea rsi, [BSS.handle_buffer]
    mov rsi, [rsi]

    ; Point RDI the storage devices array. This is required as the third parameter when calling HandleProtocol for each
    ; handle. Also, it is assumed that there's no more than 8 storage devices on the system :-)
    lea rdi, [BSS.storage_devices]

    .loop_handles:
        mov r15, rcx            ; Save RCX in R15

        ; First parameter should be the handle. Work out getting it into RCX
        lodsq
        mov rcx, rax
        lea rdx, [STANDARD_HEADER.EFI_BLOCK_IO_PROTOCOL_GUID]    ; Second parameter is the pointer to the Protocol GUID.
        mov r8, rdi             ; Third parameter is pointer memory buffer that HandleProtocol should fill in

        sub rsp, 32             ; Make shadow space on the stack
        call rbx                ; Call HandleProtocol
        add rsp, 32             ; Restore the stack

        add rdi, 32             ; Point to the next buffer for the next handle's interface
        mov rcx, r15            ; Restore RCX
    loop .loop_handles


    lea rsi, [DATA.sample_string]
    call e6_uefi_print_uefi_string
    mov rax, 0xB16A55CAFEBABE
    call e6_uefi_print_rax_hex
    lea rbx, [START]
    call e6_uefi_dump_memory
    mov rax, 0x00
    jmp .cleanup


    ; Error occurred calling LocateHandleBuffer
    .error_locate_handle_buffer:
        ; TODO: Fill this up later

    .cleanup:

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
    pushfq

    cld

    ; Align the stack. RBP is preserved by UEFI, so it survives the call.
    push rbp                        ; Preserve RBP
    mov rbp, rsp
    and rsp, -16                    ; RSP is now 16-byte aligned

    lea rbx, [BSS.EFI + efi.OutputString]    ; We're getting ready to call OutputString.
    mov rbx, [rbx]

    ; First parameter to OutputString is the pointer to the Simple Text Output Protocol.
    lea rcx, [BSS.EFI + efi.SIMPLE_TEXT_OUTPUT_PROTOCOL]
    mov rcx, [rcx]
    mov rdx, rsi                    ; RSI points to the string to print which is the second parameter to OutputString.
    sub rsp, 32                     ; Shadow space
    call rbx

    mov rsp, rbp                    ; Undo the shadow space and alignment in both at once.
    pop rbp
    
    ; Restore the registers we preserved.
    popfq
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
e6_uefi_print_rax_hex:

    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    pushfq

    cld

    ; Align the stack
    push rbp                                     ; Preserve RBP
    mov rbp, rsp
    and rsp, -16                                 ; RSP is now 16-byte aligned
    sub rsp, 32                                  ; Shadow space (keeps 16-byte alignment)

    mov rdx, rax                                 ; Preserve the rax value in rdx
    
    ; First store the string '0x' at the destination memory address. That's the hexadecimal prefix
    xor rax, rax
    lea rdi, [BSS.rax_hex_string]
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

    ; Add the terminating null byte
    xor rax, rax
    stosw

    lea rsi, [BSS.rax_hex_string]
    call e6_uefi_print_uefi_string

    mov rsp, rbp                                  ; Undo the shadow space and alignment both at once.
    pop rbp

    popfq
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret



; Prints the content of the RAX register in decimal
; In RAX: Value to print
e6_uefi_print_rax_dec:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    pushfq

    cld         ; Clear the direction flag

    ; Clear off the buffer with 0s
    mov rcx, 42
    lea rsi, [BSS.rax_dec_string]
    mov rdi, rsi
    mov rdx, rax                    ; Preserve RAX in RDX
    xor rax, rax
    rep stosb

    ; Ensure consecutive zeros is set to 1
    lea r9, [OPTIONAL_HEADER_START.CONSEC_ZEROS]
    mov byte [r9], 0x01

    mov rax, rdx                    ; Restore RAX from RDX
    mov rdi, rsi                    ; The 'rep stosb' instruction destroyed RDI, so reload it from RSI

    mov rcx, count_powers_of_10     ; We will be dividing by all the powers of 10 in a loop. This is the count for that loop
    lea rsi, [EXTRAS.powers_of_10]
    lea rdi, [BSS.rax_dec_string]
    lea rbx, [DATA_DIRECTORIES.HEX_DIGITS]

    ; If the number is less than 10, then it's a 1 digit number. Just print that and return.
    ; we just do this real quick
    cmp rax, 9
    ja .loop_divide
    xlatb
    mov rsi, rdi     ; A trick. Point at the string we're going to print before affecting the pointer value
    stosw
    call e6_uefi_print_uefi_string
    jmp .cleanup

    .loop_divide:
        xor rdx, rdx
        xchg r8, rax                ; Because 'lodsq' below would affect rax which contains the number to print
        lodsq
        xchg rax, r8                ; Perfectly setting up the number to print and the power of 10 to divide by
        div r8                      ; Divide RDX:RAX by R8

        ; After the division above, we get the quotient in RAX, and the remainder in RDX
        cmp rax, 0x00               ; Check if the quotient is 0
        jnz .non_zero               ; Just continue if it's not 0
        cmp byte [r9], 0x1          ; Check if we still have consecutive leading zeros
        jne .non_zero

        ; Loop if we still have consecutive leading zeros
        mov rax, rdx                ; Load the remainder into RAX, and loop to continue dividing
        loop .loop_divide

        .non_zero:
            mov byte [r9], 0x00     ; Now consecutive zeros is now false
            xlatb                   ; Look up what character to print
            and rax, 255            ; Ensure upper bits are cleared
            stosw

        mov rax, rdx                ; Load in the remainder
    loop .loop_divide               ; Continue with dividing the remainder
    
    ; Print the decimal representation
    lea rsi, [BSS.rax_dec_string]
    call e6_uefi_print_uefi_string

    .cleanup:
        popfq
        pop r9
        pop r8
        pop rdi
        pop rsi
        pop rdx
        pop rcx
        pop rbx
    pop rax

    ret



; Prints out a fractional number
; In RAX: The number
; In RDX: The power of 10 to divide it by
; In RCX: Number of digits after the decimal point to print
; 
; For example: if RAX = 9876, and RDX = 2, then it will print
;   the result 9876 / (10^2) = 9876/100 = 98.76
;   If RCX was set to say, 1. The result would be 1 digit after the decimal point (98.7)
;   If RCX was set to, for example, 4, the result would now be 98.7600
;   If RCX is 0, it would only print out the integer part of the division.

e6_uefi_print_fraction:

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    pushfq

    cld

    mov r8, rax                             ; Preserve RAX in R8
    lea r11, [BSS.rax_fraction_string]      ; Load up the addy of the print buffer into R11. Whenever we need it, we fetch it from the register.
    lea rbx, [DATA_DIRECTORIES.HEX_DIGITS]
    mov r10, rcx                            ; Preserve RCX in R10
    xor r12, r12
    xor r13, r13                            ; Set this to 1, if the integer has already been printed

    ; Clear off the print buffer with nulls
    mov rdi, r11                            ; Ao tii ko'fa s'ile, ifa tin' se
    mov rcx, 64
    xor rax, rax
    rep stosb

    ; If RCX is greater than 30 then clip it at 30.
    mov rcx, r10                            ; Restore RCX from R10
    cmp rcx, 30
    jna .continue
    mov rcx, 30

    .continue:
    ; Check if RDX is greater than 19 just continue as normal if it's less
    cmp rdx, 19
    jna .not_too_large                      ; RDX is less than or equal to 19
    xor rax, rax                            ; If RDX is greater than 19, then the integer of the result is always 0 
    mov rdi, r11
    xlatb
    and rax, 255
    stosw
    ; Print that lone zero in the integer
    mov rsi, r11
    call e6_uefi_print_uefi_string
    mov r13, 1                             ; Meaning the integer has been printed


    lea rsi, [EXTRAS.test_string]
    call e6_uefi_print_uefi_string
    jmp $


    mov r12, rdx
    sub r12, 20                            ; Figure out the number of zeros just after the decimal point before dividing by 10^19
    mov rdx, 19                            ; Clip RDX to the maximum power of 10 we can handle

    .not_too_large:
    mov r9, 19                             ; We have to do this dance because we can't do reverse subtraction. See the instruction that follows.
    sub r9, rdx                            ; Now we have the index of the power of 10 to divide by stored in R9

    ; This part can be skipped if the integer part has been printed already
    cmp r13, 0
    jnz .integer_already_printed

    ; Point RSI at the power of 10 to start dividing with. We have a powers of 10 table
    lea rsi, [EXTRAS.powers_of_10]
    lea rsi, [rsi + r9 * 8]
    lodsq
    mov r9, rax                     ; Loaded the power of 10 to divide by
    mov rax, r8                     ; Reload the number that was passed to us from R8 where we saved it earlier
    xor rdx, rdx                    ; Necessary for the division that follows
    div r9                          ; Integer part in RAX, remainder in RDX
    call e6_uefi_print_rax_dec      ; Go print the integer part first
    
    .integer_already_printed:

    ; If R10 is 0, then it means the user doesn't want the fractional part at all. Remember the original value of RCX
    ; (which the user passed) is preserved in R10.
    cmp r10, 0
    jz .cleanup

    ; Next write the "." into the buffer. We're printing a fraction after all
    mov al, "."
    mov rdi, r11                       ; Restore RDI
    stosw

    ; Restore RCX from R10
    mov rcx, r10
    .loop_digits:

        ; If r12 is 0, then we're done printing padding zeros i.e. the zeros immediately after the decimal point
        cmp r12, 0
        jz .continue_divide

        xor rax, rax
        xlatb
        stosb
        dec r12
        loop .loop_digits
        jrcxz .loop_digits_end

        .continue_divide:
        
        ; Just before looping, check if the last loaded power of 10 we loaded is 1, then the only reason we're still in 
        ; this loop is because there's need to pad with more zeros (as specified by the parameter passed in RCX). So
        ; keep dividing by 1 till padded with enough zeros
        cmp r9, 1
        jne .loop_continue
        sub rsi, 8                     ; Move rsi, backward to the 1, we loaded last.
        
        .loop_continue:
        lodsq                          ; Load the next power of 10 to divide by. RSI already points to it. 
        mov r9, rax                    ; Store it in r8
        mov rax, rdx                   ; Load the remainder from rdx into rax
        xor rdx, rdx                   ; Ensure rdx is 0
        div r9                         ; Do the division
        xlatb                          ; Read in the character to print
        and rax, 255
        stosw

    loop .loop_digits
    .loop_digits_end:

    mov rsi, r11                      ; Remember R11 already points to the fraction's string to print. Simply put it in RSI
    call e6_uefi_print_uefi_string

    .cleanup:
        popfq
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rdi
        pop rsi
        pop rdx
        pop rcx
        pop rbx
        pop rax

        ret



; Prints the content of a block of 256 bytes of memory.
; In RBX: Pointer to memory address to dump.
e6_uefi_dump_memory:

    ; As usual, preserve the necessary registers
    push rax
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    push rsi
    push rdi
    pushfq

    cld                                        ; Ensure the direction flag is clear

    mov rsi, rbx

    ; First ensure the specified memory address is aligned on a 256 byte boundary
    mov rax, rsi
    and rax, 0xFF
    jnz .unaligned

    lea rbx, [DATA_DIRECTORIES.HEX_DIGITS]

    ; Print the header
    push rsi                                   ; Preserve rsi on the stack as the follwoing lines of code affect it.
    lea rsi, [DATA.memory_dump_header]
    call e6_uefi_print_uefi_string
    pop rsi

    ; We'll be printing 16 lines of 16 bytes each. Each line begins with the memory address of that line.
    ; What follows will be done in a loop.
    mov rcx, 16                                 ; We'll be processing 16 lines.
    lea r9, [BSS.memory_dump_line_buffer]
    
    .process_bytes:
        push rcx                                ; Preserve RCX on the stack
        mov rdi, r9

        ; After zeroing out, print the address.
        xor rax, rax 
        mov rcx, 16                             ; There are 16 nibbles in an 8-byte address
        .loop_address_nibbles:
            rol rsi, 4
            mov rax, rsi
            and rax, 0x0F
            xlatb
            stosw
            loop .loop_address_nibbles

        mov rcx, 16                             ; Count for loop to print actual bytes.
        ; Each of the 16 bytes to print is a space followed by 2 hexadecimal characters.
        .loop_bytes:
            mov al, ' '
            stosw
            lodsb                               ; Read a byte into al.
            mov rdx, rax                        ; Preserve the byte in rdx.
            shr rax, 4                          ; Get the upper nibble.
            and rax, 15
            xlatb
            stosw
            mov rax, rdx                        ; Restore rax from rdx.
            and rax, 15                         ; Get the lower nibble.
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

        ; Go print the buffer. Remember to preserve RSI first and then restore.
        push rsi
        mov rsi, r9
        call e6_uefi_print_uefi_string
        pop rsi

        pop rcx
        loop .process_bytes

        popfq
        clc
        jmp .cleanup
    
    .unaligned:
        popfq
        stc

    .cleanup:
        pop rdi
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



DATA:
    .memory_dump_header:              db __utf16__ `\r\n                  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F\r\n\0`   
    .sample_string:                   db __utf16__ `Yes Lordy!\r\n\0`
    
    times 4096 - ($ - CODE)           db 0x00                    ; Pad up to 4kb

END:



; `section .bss` is for unintialized data. 'nobits' is used to tell nasm to just use this section for address
; calculations. This section will not appear in the compiled binary executable file.  
section .bss nobits
BSS:
    .EFI:                             resb efi_size         ; For the efi struc
    .handle_count:                    resq 1                ; Needed when trying to fetch handles
    .handle_buffer:                   resq 1                ; Also needed when trying to get handles
    .storage_devices:                 resb 32 * 8           ; Make room for 8 devices
    .rax_hex_string:                  resb 38
    .rax_dec_string:                  resb 42

    ; At 2 bytes per character (utf16) this leaves room for 32 characters. We use 1 character for the "." and 1
    ; for null (UEFI strings are null terminated), we still 30 characters left for the decimal digits. I'm not sure I
    ; know anyone who would find that level of precision useful.

    .rax_fraction_string:             resb 64


    ; This is for buffering a line of memory before printing.
    ; 1. Each line begins with the address which is 8 bytes. Each byte is represented by 2 characters, and each
    ;    character occupies 2 bytes in utf16. For the address, this makes 8 x 2 x 2 = 32
    ; 2. Each byte is represented by a space character and 2 hexadecimal characters. This makes 3 characters per byte.
    ;    at 16 bytes per line and 2 bytes per character (utf16) that makes 3 x 16 x 2 = 96
    ; 3. \r, \n, and null characters (uefi strings are null terminated) at 2 bytes per character (utf16), this adds
    ;    an additional 3 x 2 = 6.
    ; 4. Total amount of memory for each line of memory dump = 32 + 96 + 6 = 134 bytes.

    .memory_dump_line_buffer:          resb 134

BSS_END:

%include "eficonstants.asm"
%include "e6constants.asm"