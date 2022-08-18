; This is the installer of e6 os. This program is expected to be loaded and executed directly by efi.
; The resulting efi application is copied unto a FAT16 esp filesystem on an El-torito compliant image or cd

Bits 64
DEFAULT REL

START:
PE:
HEADER_START:
STANDARD_HEADER:
    .DOS_SIGNATURE              db 'MZ'                                                             ; The DOS signature. This is apparently compulsory
    
    ; 58 more bytes of DOS Headers should normally follow which are useless for this program. So rather than
    ; fill these with zeros, we'll fill it in with somethings that might be more useful.
        .E6_STARTUP_MESSAGE     db __utf16__ `E6 Installer CD\r\n\r\n\0`
        .E6_HEX_DIGITS          db '0123456789ABCDEF'
                                times 60-($-STANDARD_HEADER) db 0                                   ; Should be DOS Headers.
    .SIGNATURE_POINTER          dd .PE_SIGNATURE - START                                            ; Pointer to the PE Signature
    .PE_SIGNATURE               db 'PE', 0x00, 0x00                                                 ; This is the pe signature. The characters 'PE' followed by 2 null bytes
    .MACHINE_TYPE               dw 0x8664                                                           ; Targetting the x64 machine
    .NUMBER_OF_SECTIONS         dw 2                                                                ; Number of sections. Indicates size of section table that immediately follows the headers
    .CREATED_DATE_TIME          dd 1657582794                                                       ; Number of seconds since 1970 since when the file was created
    .SYMBOL_TABLE_POINTER       dd 0x00                                                             ; Pointer to the symbol table. There should be no symbol table in an image so this is 0
    .NUMBER_OF_SYMBOLS          dd 0x00                                                             ; Because there are no symbol tables in an image
    .OPTIONAL_HEADER_SIZE       dw OPTIONAL_HEADER_STOP - OPTIONAL_HEADER_START                     ; Size of the optional header
    .CHARACTERISTICS            dw 0b0010111000100010                                               ; These are the attributes of the file

OPTIONAL_HEADER_START:
    .MAGIC_NUMBER               dw 0x020B                       ; PE32+ (i.e. pe64) magic number
    .MAJOR_LINKER_VERSION       db 0                            ; I'm sure this isn't needed. So set to 0
    .MINOR_LINKER_VERSION       db 0                            ; This too
    .SIZE_OF_CODE               dd END - START                  ; The size of the code section
    .INITIALIZED_DATA_SIZE      dd END - START                  ; Size of initialized data section
    .UNINITIALIZED_DATA_SIZE    dd 0x00                         ; Size of uninitialized data section
    .ENTRY_POINT_ADDRESS        dd EntryPoint - START           ; Address of entry point relative to image base when the image is loaded in memory
    .BASE_OF_CODE_ADDRESS       dd START                        ; Relative address of base of code
    .IMAGE_BASE                 dq 0x400000                     ; Where in memory we would prefer the image to be loaded at
    .SECTION_ALIGNMENT          dd 0x1000                       ; Alignment in bytes of sections when they are loaded in memory. Align to page boundry (4kb)
    .FILE_ALIGNMENT             dd 0x1000                       ; Alignment of sections in the file. Also align to 4kb 
    .MAJOR_OS_VERSION           dw 0x00                         ; I'm not sure UEFI requires these and the following 'version woo'
    .MINOR_OS_VERSION           dw 0x00                         ; More of these version thingies are to follow. Again, not sure UEFI needs them
    .MAJOR_IMAGE_VERSION        dw 0x00                         ; Major version of the image
    .MINOR_IMAGE_VERSION        dw 0x00                         ; Minor version of the image
    .MAJOR_SUBSYSTEM_VERSION    dw 0x00                         ; 
    .MINOR_SUBSYSTEM_VERSION    dw 0x00                         ;
    .WIN32_VERSION_VALUE        dd 0x00                         ; Reserved, must be 0
    .IMAGE_SIZE                 dd END - START                  ; The size in bytes of the image when loaded in memory including all headers
    .HEADERS_SIZE               dd HEADER_END - HEADER_START    ; Size of all the headers
    .CHECKSUM                   dd 0x00                         ; Hoping this doesn't break the application
    .SUBSYSTEM                  dw 10                           ; The subsystem. In this case we're making a UEFI application.
    .DLL_CHARACTERISTICS        dw 0b000011110010000            ; I honestly don't know what to put here
    .STACK_RESERVE_SIZE         dq 0x200000                     ; Reserve 2MB for the stack... I guess...
    .STACK_COMMIT_SIZE          dq 0x1000                       ; Commit 4kb of the stack
    .HEAP_RESERVE_SIZE          dq 0x200000                     ; Reserve 2MB for the heap... I think... :D
    .HEAP_COMMIT_SIZE           dq 0x1000                       ; Commit 4kb of heap
    .LOADER_FLAGS               dd 0x00                         ; Reserved, must be zero
    .NUMBER_OF_RVA_AND_SIZES    dd 0x10                         ; Number of entries in the data directory


    DATA_DIRECTORIES:
    ; The next 40 bytes represent the first 5 entries of the data directory which are of no use to us. Again,
    ; rather than have 40 bytes worth of nothing but zeros, we'll like to put something useful in here.

            EFI_IMAGE_HANDLE    dq 0x00                                         ; EFI will give use this in rcx
            EFI_SYSTEM_TABLE    dq 0x00                                         ; And this in rdx

            EntryPoint:
                ; First order of business is to store the values that were passed to us by EFI
                mov [EFI_IMAGE_HANDLE], rcx
                mov [EFI_SYSTEM_TABLE], rdx

				; Clear the screen
                add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL                        ; Locate SIMPLE_TEXT_OUTPUT_PROTOCOL
                jmp ContinueEntryPoint                                          ; Jump over the RELOC data directory entry below and continue. Still trying to clear the screen
                    times 40 - ($ - DATA_DIRECTORIES) db 0                      ; This is here so nasm would squeal in case we go past 40 bytes
        
        ; --- RELOC is the only Data Directory entry that we really need. ---
        RELOC:
            .address            dd END - START                              ; Address of relocation table
            .size               dd 0                                        ; Size of relocation table
        ; --------------------------------------------------------------------

            ; 10 more data directory entries are supposed to follow. However, because we don't need those data directory
            ; entries, their space here will be used for something a little more useful.
            ContinueEntryPoint:
                mov rcx, [rdx]                                                  ; The only parameter ClearScreen() needs
                mov r15, [rdx]                                                  ; Save pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL in a non-volatile register
                mov rdx, [rdx]
                add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_ClearScreen            ; Point rdx to the pointer to the ClearScreen function
                mov rbx, [rdx]                                                  ; Load the pointer to the function in preparation for the call
                sub rsp, 32                                                     ; Shadow space on the stack
                call rbx

				; Print e6 installer's message above.
                mov rbx, r15
                mov rcx, r15
                add rbx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString
                mov rbx, [rbx]
                lea rdx, [STANDARD_HEADER.E6_STARTUP_MESSAGE]
                call rbx

                ; Detect storage devices/partitions/volumes on the system

                ; Return to EFI
                add rsp, 32
                mov rax, EFI_SUCCESS

                ret

            times 80 - ($ - ContinueEntryPoint) db 0

OPTIONAL_HEADER_STOP:

SECTION_HEADERS:
    SECTION_ALL:
        .name                       db ".all", 0x00, 0x00, 0x00, 0x00
        .virtual_size               dd END - START
        .virtual_address            dd 0x00
        .size_of_raw_data           dd END - START
        .pointer_to_raw_data        dd START
        .pointer_to_relocations     dd 0                                    ; Set to 0 for executable images
        .pointer_to_line_numbers    dd 0                                    ; There are no COFF line numbers
        .number_of_relocations      dw 0                                    ; Set to 0 for executable images
        .number_of_line_numbers     dw 0                                    ; Should be 0 for images
        .characteristics            dd 0xF0000020                           ; Read, write, executable, shared because this contains both code and data

    SECTION_RELOC:
        .name                       db ".reloc", 0x00, 0x00
        .virtual_size               dd 0
        .virtual_address            dd END - START
        .size_of_raw_data           dd 0
        .pointer_to_raw_data        dd END - START
        .pointer_to_relocations     dd 0
        .pointer_to_line_numbers    dd 0
        .number_of_relocations      dw 0
        .number_of_line_numbers     dw 0
        .characteristics            dd 0xC2000040

CODE:

    ; Prints out the value of RAX in hexadecimal
    ; In RAX the number to print
    PrintRaxHex:

        ; Before anything, preserve the following registers on the stack
        push rax
        push rbx
        push rcx
        push rdi

        mov rdx, rax
        lea rdi, [DATA.rax_print_buffer]
        lea rbx, [STANDARD_HEADER.E6_HEX_DIGITS]        ; So we can do xlatb
        
        mov rcx, 16
        
        .loop:
            rol rdx, 4
            mov rax, rdx
            and rax, 0x0F
            xlatb
            stosw
            dec rcx
            cmp rcx, 0
            je .done
            jmp .loop
        .done:
            ; Print the buffer we just set up
            mov rbx, r15
            mov rcx, r15
            add rbx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString
            mov rbx, [rbx]
            lea rdx, [DATA.rax_print_hex_prefix]
            call rbx

            ; Restore registers that were preserved
            pop rdi
            pop rcx
            pop rbx
            pop rax

            ret

    ; Prints out the value at memory location in hexadecimal (prints 16 bytes)
    ; In RSI, Pointer to the byte string to print
    PrintMemHex:

    ; Prints 
    PrintMemASCII:
CODE_END:

DATA:
    ; These define a buffer for when we want to print the value in rax in hexadecimal
    .rax_print_hex_prefix: db __utf16__ '0x' 
    .rax_print_buffer: times 16 dw 0                ; Enough to hold 8 bytes at 2 characters per byte
    .rax_print_buffer_null_terminator: dw 0         ; EFI requires this to print a string

    ; 

DATA_END:

; times 4096-($-PE)   db 0
HEADER_END:

END:

; Define the needed EFI constants and offsets here.
EFI_SUCCESS                                         equ 0

EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL                     equ 64                    
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_Reset               equ 0
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString        equ 8
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_ClearScreen         equ 48

EFI_BOOTSERVICES                                    equ 96

EFI_LOCATE_SEARCH_TYPE_AllHandles                   equ 0
EFI_LOCATE_SEARCH_TYPE_ByRegisterNotify             equ 1
EFI_LOCATE_SEARCH_TYPE_ByProtocol                   equ 2