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
    
    ; Normally what should follow should be the following fields, but they are of no use to this application.
    ; So the 16 bytes will be used for BLOCK_IO_PROTOCOL_GUID ===============================================
    ; .MAJOR_OS_VERSION           dw 0x00                         ; I'm not sure UEFI requires these and the following 'version woo'
    ; .MINOR_OS_VERSION           dw 0x00                         ; More of these version thingies are to follow. Again, not sure UEFI needs them
    ; .MAJOR_IMAGE_VERSION        dw 0x00                         ; Major version of the image
    ; .MINOR_IMAGE_VERSION        dw 0x00                         ; Minor version of the image
    ; .MAJOR_SUBSYSTEM_VERSION    dw 0x00                         ; 
    ; .MINOR_SUBSYSTEM_VERSION    dw 0x00                         ;
    ; .WIN32_VERSION_VALUE        dd 0x00                         ; Reserved, must be 0
    .BLOCK_IO_PROTOCOL_GUID_DATA1   dd 0x964E5B21
    .BLOCK_IO_PROTOCOL_GUID_DATA2   dw 0x6459
    .BLOCK_IO_PROTOCOL_GUID_DATA3   dw 0x11D2
    .BLOCK_IO_PROTOCOL_GUID_DATA4   db 0x8E, 0x39, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B

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

            EntryPoint:
                ; First order of business is to store the values that were passed to us by EFI
                ; Here I've decided to put them in efi non-volatile registers
                mov r13, rcx
                mov r14, rdx

				; Clear the screen
                add rdx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL                        ; Locate SIMPLE_TEXT_OUTPUT_PROTOCOL
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

                add rbx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString
                mov rbx, [rbx]
                lea rdx, [STANDARD_HEADER.E6_STARTUP_MESSAGE]
                call rbx

                ; Detect storage devices/partitions/volumes on the system. To do this, we'll need the Block io protocol
                call LocateHandleByProtocol                                 ; Call with buffer size of 0. On return, we'll get buffer size actually needed

                ; Now we know the size of the buffer that we need. Next we'll do some setup and allocate enough pages
                ; for the buffer. But first, we need to calculate the number of pages we need for the buffer
                lea r8, [DATA.locate_handle_buffer_size]
                mov r8, [r8]
                mov rax, r8
                and rax, 0xFFF                                                      ; Get the remainder when divided by 4096.
                shr r8, 12                                                          ; Effectively dividing by 4096
                cmp rax, 0                                                          ; If there's a remainder we need to increment the number of pages
                je .continue
                inc r8

                .continue:
                ; Setup parameters. We'd like to call AllocatePages(). The r8 register already contains the number of pages
                mov rcx, EFI_ALLOCATE_TYPE_AllocateAnyPages
                mov rdx, EFI_MEMORY_TYPE_LoaderData
                lea r9, [DATA.base_address_for_locate_handle]

                ; Allocate Memory pages
                mov rbx, r14
                add rbx, EFI_BOOTSERVICES

                jmp ContinueEntryPoint2                 ; Allocate Memory Pages - To Be Continued

            times 80 - ($ - ContinueEntryPoint) db 0    ; To continue, jump over the section headers that follow

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
    ; The entry point continues from here
    ContinueEntryPoint2:
        mov rbx, [rbx]
        add rbx, EFI_BOOTSERVICES_AllocatePages
        mov rbx, [rbx]
        mov r12, r8
        call rbx

        ; Now we have the number of pages we need. Do some preparations before calling LocateHandle() again
        lea r9, [DATA.locate_handle_buffer_size]
        shl r12, 12                                                     ; Multiply by 4096. (Number of bytes per page)
        mov [r9], qword r12
        call LocateHandleByProtocol

        ; Now we've got the handles for a bunch of block io devices
        lea r10, [DATA.locate_handle_buffer_size]
        mov r10, [r10]
        lea rsi, [DATA.base_address_for_locate_handle]
        mov rsi, [rsi]
        shr r10, 3                                                      ; Divide by 8 to get number of handles in the handles array

        .loop_handles:
            cmp r10, 0
            jz .loop_handles_done
            
            ; Call HandleProtocol on each handle
            lodsq
            mov rcx, rax
            lea rdx, OPTIONAL_HEADER_START.BLOCK_IO_PROTOCOL_GUID_DATA1
            lea r8, DATA.BLOCK_IO_PROTOCOL_INTERFACE
            
            dec r10
            jmp .loop_handles
        .loop_handles_done:

        xor rax, rax
        add rsp, 32
        ret

        .error:

    ; Function that calls EFI LocateHandle()
    LocateHandleByProtocol:
        sub rsp, 32

        ; Note that the third parameter which should have been in r8 is missing because searching by protocol does not require it
        mov rcx, EFI_LOCATE_SEARCH_TYPE_ByProtocol                          ; We want to Locate By protocol, specifically block io
        lea rdx, [OPTIONAL_HEADER_START.BLOCK_IO_PROTOCOL_GUID_DATA1]       ; GUID for BLOCK_IO_PROTOCOL.        
        lea r9, [DATA.locate_handle_buffer_size]
        lea rbp, [DATA.base_address_for_locate_handle]
        push rbp                                                            ; Parameter 5 goes on the stack

        ; Having setup the parameters, find LocateHandle() and call it
        mov rbx, r14
        add rbx, EFI_BOOTSERVICES
        mov rbx, [rbx]
        add rbx, EFI_BOOTSERVICES_LocateHandle
        mov rbx, [rbx]
        call rbx
        pop rbp                                                             ; Remember to restore the stack

        add rsp, 32
        ret

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

        push rax
        push rbx
        push rcx
        push rdx
        push rsi
        push rdi

        lea rbx, [STANDARD_HEADER.E6_HEX_DIGITS]
        lea rdi, [DATA.mem_print_buffer]
        mov rcx, 16
        .loop:
            lodsb
            mov rdx, rax
            and rax, 0xF0
            ror rax, 4
            xlatb
            stosw
            mov rax, rdx
            and rax, 0x0F
            xlatb
            stosw
            mov al, ' '         ; don't forget to print the space after each byte
            stosw
            dec rcx
            cmp rcx, 0
            je .done
            jmp .loop
        .done:
            mov rbx, r15
            mov rcx, r15
            add rbx, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_OutputString
            mov rbx, [rbx]
            lea rdx, [DATA.mem_print_buffer]
            call rbx

            pop rdi
            pop rsi
            pop rdx
            pop rcx
            pop rbx
            pop rax

            ret

    ; Prints 
    PrintMemASCII:
CODE_END:

DATA:
    ; These define a buffer for when we want to print the value in rax in hexadecimal
    .rax_print_hex_prefix: db __utf16__ '0x' 
    .rax_print_buffer: times 16 dw 0                ; Enough to hold 8 bytes at 2 characters per byte
    .rax_print_buffer_null_terminator: dw 0         ; EFI requires this to print a string

    .mem_print_buffer: times 98 db 0                ; Buffer for printing memory bytes

    .locate_handle_buffer_size: dq 0x00             ; Buffer size for LocateHandle to use
    .base_address_for_locate_handle: dq 0x1000      ; Base address for buffer to be allocated for LocateHandle

    .detected_harddisks_message: db __utf16__ `Detected Disks\r\n\0`

    .BLOCK_IO_PROTOCOL_INTERFACE: dq 0
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
EFI_BOOTSERVICES_AllocatePages                      equ 40
EFI_BOOTSERVICES_LocateHandle                       equ 176

EFI_LOCATE_SEARCH_TYPE_AllHandles                   equ 0
EFI_LOCATE_SEARCH_TYPE_ByRegisterNotify             equ 1
EFI_LOCATE_SEARCH_TYPE_ByProtocol                   equ 2

EFI_ALLOCATE_TYPE_AllocateAnyPages                  equ 0
EFI_ALLOCATE_TYPE_AllocateMaxAddress                equ 1
EFI_ALLOCATE_TYPE_AllocateAddress                   equ 2
EFI_ALLOCATE_TYPE_MaxAllocateType                   equ 3

EFI_BLOCK_IO_PROTOCOL_Revision                      equ 0
EFI_BLOCK_IO_PROTOCOL_Media                         equ 8
EFI_BLOCK_IO_PROTOCOL_Reset                         equ 16
EFI_BLOCK_IO_PROTOCOL_ReadBlocks                    equ 24
EFI_BLOCK_IO_PROTOCOL_WriteBlocks                   equ 32
EFI_BLOCK_IO_PROTOCOL_FlushBlocks                   equ 40

EFI_BLOCK_IO_MEDIA_MediaId                          equ 0
EFI_BLOCK_IO_MEDIA_RemovableMedia                   equ 4
EFI_BLOCK_IO_MEDIA_MediaPresent                     equ 5
EFI_BLOCK_IO_MEDIA_LogicalPartition                 equ 6
EFI_BLOCK_IO_MEDIA_ReadOnly                         equ 7
EFI_BLOCK_IO_MEDIA_WriteCaching                     equ 8
EFI_BLOCK_IO_MEDIA_BlockSize                        equ 12
EFI_BLOCK_IO_MEDIA_IoAlign                          equ 16
EFI_BLOCK_IO_MEDIA_LastBlock                        equ 24

EFI_MEMORY_TYPE_ReservedMemory                      equ 0
EFI_MEMORY_TYPE_LoaderCode                          equ 1
EFI_MEMORY_TYPE_LoaderData                          equ 2
EFI_MEMORY_TYPE_BootServicesCode                    equ 3
EFI_MEMORY_TYPE_BootServicesData                    equ 4