Bits 64
DEFAULT REL

START:
PE:
HEADER_START:
STANDARD_HEADER:
    .DOS_SIGNATURE              db 'MZ'                                                             ; The DOS signature. This is apparently compulsory
    .DOS_HEADERS                times 60-($-STANDARD_HEADER) db 0                                   ; The DOS Headers. Probably not needed by UEFI
    .SIGNATURE_POINTER          dd .PE_SIGNATURE - START                                            ; Pointer to the PE Signature
    .DOS_STUB                   times 64 db 0                                                       ; The DOS stub. Fill with zeros
    .PE_SIGNATURE               db 'PE', 0x00, 0x00                                                 ; This is the pe signature. The characters 'PE' followed by 2 null bytes
    .MACHINE_TYPE               dw 0x8664                                                           ; Targetting the x64 machine
    .NUMBER_OF_SECTIONS         dw 3                                                                ; Number of sections. Indicates size of section table that immediately follows the headers
    .CREATED_DATE_TIME          dd 1657582794                                                       ; Number of seconds since 1970 since when the file was created
    .SYMBOL_TABLE_POINTER       dd 0x00                                                             ; Pointer to the symbol table. There should be no symbol table in an image so this is 0
    .NUMBER_OF_SYMBOLS          dd 0x00                                                             ; Because there are no symbol tables in an image
    .OPTIONAL_HEADER_SIZE       dw OPTIONAL_HEADER_STOP - OPTIONAL_HEADER_START                     ; Size of the optional header
    .CHARACTERISTICS            dw 0b0010111000100010                                               ; These are the attributes of the file

OPTIONAL_HEADER_START:
    .MAGIC_NUMBER               dw 0x020B                       ; PE32+ (i.e. pe64) magic number
    .MAJOR_LINKER_VERSION       db 0                            ; I'm sure this isn't needed. So set to 0
    .MINOR_LINKER_VERSION       db 0                            ; This too
    .SIZE_OF_CODE               dd CODE_END - CODE              ; The size of the code section
    .INITIALIZED_DATA_SIZE      dd DATA_END - DATA              ; Size of initialized data section
    .UNINITIALIZED_DATA_SIZE    dd 0x00                         ; Size of uninitialized data section
    .ENTRY_POINT_ADDRESS        dd EntryPoint - START           ; Address of entry point relative to image base when the image is loaded in memory
    .BASE_OF_CODE_ADDRESS       dd CODE - START                 ; Relative address of base of code
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
        EDATA:
            .address            dd 0                                        ; Address of export table
            .size               dd 0                                        ; Size of export table
        IDATA:
            .address            dd 0                                        ; Address of import table
            .size               dd 0                                        ; Size of import table
        RSRC:
            .address            dd 0                                        ; Address of resource table
            .size               dd 0                                        ; Size of resource table
        PDATA:
            .address            dd 0                                        ; Address of exception table
            .size               dd 0                                        ; Size of exception table
        CERT:
            .address            dd 0                                        ; Address of certificate table
            .size               dd 0                                        ; Size of certificate table
        RELOC:
            .address            dd END - START                              ; Address of relocation table
            .size               dd 0                                        ; Size of relocation table
        DEBUG:
            .address            dd 0                                        ; Address of debug table
            .size               dd 0                                        ; Size of debug table
        ARCHITECTURE:
            .address            dd 0                                        ; Reserved. Must be 0
            .size               dd 0                                        ; Reserved. Must be 0
        GLOBALPTR:
            .address            dd 0                                        ; RVA to be stored in global pointer register
            .size               dd 0                                        ; Must be 0
        TLS:
            .address            dd 0                                        ; Address of TLS table
            .size               dd 0                                        ; Size of TLS table
        LOADCONFIG:
            .address            dd 0                                        ; Address of Load Config table
            .size               dd 0                                        ; Size of Load Config table
        BOUNDIMPORT:
            .address            dd 0                                        ; Address of bound import table
            .size               dd 0                                        ; Size of bound import table
        IAT:
            .address            dd 0                                        ; Address of IAT
            .size               dd 0                                        ; Size of IAT
        DELAYIMPORTDESCRIPTOR:
            .address            dd 0                                        ; Address of delay import descriptor
            .size               dd 0                                        ; Size of delay import descriptor
        CLRRUNTIMEHEADER:
            .address            dd 0                                        ; Address of CLR runtime header
            .size               dd 0                                        ; Size of CLR runtime header
        RESERVED:
            .address            dd 0                                        ; Reserved, must be 0
            .size               dd 0                                        ; Reserved, must be 0

OPTIONAL_HEADER_STOP:

SECTION_HEADERS:
    SECTION_CODE:
        .name                       db ".text", 0x00, 0x00, 0x00
        .virtual_size               dd CODE_END - CODE
        .virtual_address            dd CODE - START
        .size_of_raw_data           dd CODE_END - CODE
        .pointer_to_raw_data        dd CODE - START
        .pointer_to_relocations     dd 0                                    ; Set to 0 for executable images
        .pointer_to_line_numbers    dd 0                                    ; There are no COFF line numbers
        .number_of_relocations      dw 0                                    ; Set to 0 for executable images
        .number_of_line_numbers     dw 0                                    ; Should be 0 for images
        .characteristics            dd 0x70000020                           ; Need to read up more on this

    SECTION_DATA:
        .name                       db ".data", 0x00, 0x00, 0x00
        .virtual_size               dd DATA_END - DATA
        .virtual_address            dd DATA - START
        .size_of_raw_data           dd DATA_END - DATA
        .pointer_to_raw_data        dd DATA - START
        .pointer_to_relocations     dd 0
        .pointer_to_line_numbers    dd 0
        .number_of_relocations      dw 0
        .number_of_line_numbers     dw 0
        .characteristics            dd 0xD0000040

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

times 4096-($-PE)   db 0
HEADER_END:

CODE:
    ; The code begins here with the entry point
    EntryPoint:

        ; First order of business is to store the values that were passed to us by EFI
        mov [EFI_IMAGE_HANDLE], rcx
        mov [EFI_SYSTEM_TABLE], rdx

        ; Locate OutputString of the TEXT_OUTPUT_PROTOCOL
        add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
        mov rcx, [rdx]                                                  ; This is the first parameter to the call
        mov rdx, [rdx]                                                  ; Now rdx points to simple text output protocol
        add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString           ; Now rdx points to output string
        mov rax, [rdx]                                                  ; We'll later do `call rax`

        lea rdx, [hello_message]                                        ; The string to be printed
        sub rsp, 32                                                     ; Shadow space on the stack before the call
        call rax

        add rsp, 32
        mov rax, EFI_SUCCESS

        ret
        align 4096

CODE_END:

; Data begins here
DATA:
    EFI_IMAGE_HANDLE    dq 0x00                                     ; EFI will give use this in rcx
    EFI_SYSTEM_TABLE    dq 0x00                                     ; And this in rdx
    hello_message db __utf16__ `Hello_world\0`                      ; EFI strings are UTF16 and null-terminated

    align 4096
DATA_END:
END:

; Define the needed EFI constants and offsets here.
EFI_SUCCESS                                         equ 0
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL                     equ 64                    
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_Reset               equ 0
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString        equ 8
