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
;     nasm -f bin -o e6installer.bin e6installer.asm
; This is the first part of the installation program of e6. The assembled binary
; should be no more than 32KiB and should go to the systems area of the 
; installation CD/iso image

%include "e6constants.asm"

START:
cli                                               ; Clear interrupts

; Setup a stack we can work with. This stack is setup somewhere below the loaded installer code
xor ax, ax
mov ss, ax
mov sp, 0x8000
mov bp, sp

; Setup a flat segment with CS=DS=ES
mov ax, INSTALLER_STARTUP_SEGMENT                 ; This is defined in the e6constants.asm file included above
mov ds, ax
mov es, ax

mov [BOOT_DEVICE], dl                             ; Before doing any other thing, save the boot device
sti                                               ; Set interrupts again

; Show the installer's startup message
mov si, STARTUP_MSG
xor al, al
call print_byte_terminated_string

; Wait for the user to press the 'enter' key
mov al, 0x1C                                      ; scancode of the key to wait for
call wait_for_key_scancode
call print_newline
call print_newline
xor al, al
mov si, SELECT_STORAGE_DEVICE_MSG
call print_byte_terminated_string

; Wait for the user to press a key to select fixed disk or removable disk
; int 16h
; jmp $


; Enumerate storage devices. Here look for 15 removable disks and 15 fixed disks
enumerate_storage_devices:
  xor edx, edx
  mov si, DRIVE_INFORMATION_BUFFER
  .loop:
    mov word [DRIVE_INFORMATION_BUFFER.buffer_size], DRIVE_INFORMATION_BUFFER_SIZE
    mov ah, 0x48              ; Function to get drive parameters
    int 13h
    jc .pre_loop              ; Carry flag is set on error
    
    cmp dword [DRIVE_INFORMATION_BUFFER.sector_count], 0
    je .pre_loop

    ; Check the 'removable-media' flag in the result
    xor eax, eax
    mov ax, [DRIVE_INFORMATION_BUFFER.information_flags]
    test ax, 0x04
    jz .removable_media_found

  .fixed_disk_found:
    xor eax, eax
    mov al, [DETECTED_STORAGE_DEVICES.count]
    shr ax, 4
    cmp al, 15          ; We already found 15 fixed disk. So don't bother
    je .pre_loop
    mov di, ax
    add di, DETECTED_STORAGE_DEVICES.fixed_disks
    dec di
    mov [di], dl
    add byte[DETECTED_STORAGE_DEVICES.count], 8

  .removable_media_found:
    xor eax, eax
    mov al, [DETECTED_STORAGE_DEVICES.count]
    and ax, 0x0F
    cmp al, 15          ; We already found 15 removable disks. So don't bother
    je .pre_loop
    mov di, ax
    add di, DETECTED_STORAGE_DEVICES.removable_disks
    dec di
    mov [di], dl
    inc byte [DETECTED_STORAGE_DEVICES.count]
  
  .pre_loop:              ; An error occured
    cmp dl, 0xFF          ; If we've exhausted all possible BIOS drive numbers
    je .done              ; then we're done

    ; If we've found 15 removable media AND 15 fixed disks then stop searching
    cmp byte [DETECTED_STORAGE_DEVICES.count], 0xFF
    je .done

    inc dl                ; Otherwise try the next BIOS drive number
    jmp .loop

  .done:
    
  ; mov si, DETECTED_STORAGE_DEVICES
  ; call dump_memory_hex
  ; jmp $



  ; xor ax, ax
  ; mov ax, cx
  ; call print_eax_hex

; jmp $

; mov si, DRIVE_INFORMATION_BUFFER.bus_type_ascii
; mov ecx, 0x04
; call print_string_ecx_length

; mov ah, 0x48
; mov si, DRIVE_INFORMATION_BUFFER
; mov dl, 0x80
; int 13h
; mov eax, [DRIVE_INFORMATION_BUFFER.sector_count]
; call print_eax_hex
; jmp $ 
; mov eax, [DRIVE_INFORMATION_BUFFER.sector_count]
; call print_eax_hex

jmp $




; ********************************************
; *                                          *
; * A bunch of functions that will be useful *
; *                                          *
; ********************************************


print_newline:
  ; Moves the cursor to the beginning of the next line
  ;---------------------------------------------------
  mov ah, 0x0E
  mov bx, 0x0007
  mov al, 0x0A
  int 10h
  mov al, 0x0D
  int 10h
  ret



print_byte_terminated_string:
  ; Prints a string that is terminated by a given byte
  ; IN:
  ;    DS:SI - Location of string to print
  ;    AL    - The byte that terminates the string
  ;----------------------------------------------------
  push dx
  mov dl, al
  mov ah, 0x0E
  mov bx, 0x0007
  .loop:
    lodsb
    cmp al, dl
    je .done
    int 10h
    jmp .loop
  .done:
    pop dx
    ret



print_string_ecx_length:
  ; Prints a string whose length is specified in ecx
  ; IN:
  ;   DS:SI - Location of the string to print
  ;   ECX   - Length of the string to print
  ;--------------------------------------------------
  mov ah, 0x0E
  mov bx, 0x0007
  .loop:
    lodsb
    int 10h
    loop .loop
  ret



print_eax_hex:
  ; Prints out the content of the eax register in hexadecimal
  ; IN:
  ;    EAX - The value to print
  ; ---------------------------------------------------------
  mov edx, eax                                ; Preserve the eax value in edx
  mov di, EAX_HEX.hexstring
  mov cx, 0x08                                ; Number of nibbles in a double word
  mov bx, HEX_DIGITS
  .loop:
    rol edx, 0x04
    mov eax, edx
    and eax, 0x0F
    xlatb
    stosb
    loop .loop

    ; Print the hexadecimal representation
    mov bx, 0x0007
    mov ah, 0x0E
    mov si, EAX_HEX
    mov cx, 0x0A
    .fetch:
      lodsb
      int 10h
      loop .fetch
    ret



clear_screen:
  ; Clears the screen
  ;---------------------
  mov ah, 0x06                    ; Actually this the function to scroll the screen
  xor al, al                      ; Make AL = 0 to clear the screen
  mov bh, 0x07                    ; Background and Foreground colors. Background is black and foreground is white
  xor ch, ch                      ; CH = 0: start from the first row
  xor cl, cl                      ; CL = 0: start from the first column
  mov dh, 24                      ; Last row in 80x25 text mode
  mov dl, 79                      ; Last column in 80x25 text mode
  int 10h

  ; Reposition the cursor at the beginning of the screen
  mov ah, 0x02                    ; Function to position cursor
  xor bh, bh                      ; Page number 0
  xor dh, dh                      ; DH = 0: First row
  xor dl, dl                      ; DL = 0: First column
  int 10h
  ret

 

wait_for_key_scancode:
  ; Waits for a key to be pressed which has a given scancode
  ; IN:
  ;    AL: Scancode of the key to wait for
  ; OUT:
  ;    AH: Scancode of the key
  ;    AL: ASCII of the key. This would be 0 if there's no ASCII
  ;-----------------------------------------------------------------
    mov dl, al
    .loop:
      mov ah, 0x00                    ; BIOS function to get key
      int 16h                         ; Keyboard interrupt
      cmp ah, dl                      ; Check if it's the key we're waiting for
      jnz .loop                       ; Continue waiting if it's not
    ret



dump_memory_hex:
  ; Dump content of memory in hexadecimal. Dumps 256 bytes of memory
  ; IN
  ;   SI: Memory address to dump.
  ; NOTE: The address is expected to be 256-byte aligned
  ;-----------------------------------------------------------------
    ; Check to ensure the address is 256 byte aligned
    mov dx, si
    and dx, 0x00FF
    cmp dx, 0x00
    je .continue
    stc                             ; Set the carry flag to mean an error occured
    ret

    ; Start on a new line
    .continue:
        mov bx, 0x0007
        mov ah, 0x0E
        mov al, 0x0A
        int 10h
        mov al, 0x0D
        int 10h

    ; Print the headers
    ; First print out intial 4 spaces in the header
    mov cx, 0x04
    mov ah, 0x0E
    mov al, ' '
    .print_initial_spaces:
      int 10h
      loop .print_initial_spaces

    mov cl, 0x10
    push si                         ; Remember to preserve the address of the bytes we want to print
    mov si, HEX_DIGITS

    ; Print 2 spaces followed by hex digit. Still part of the headers
    .header_loop:
        mov al, ' '
        int 10h
        int 10h
        lodsb
        int 10h
        loop .header_loop
    .newline:
        mov al, 0x0A
        int 10h
        mov al, 0x0D
        int 10h
    ; We're done printing the header

    pop si                          ; Retrieve the address of the bytes to print
    mov bx, HEX_DIGITS
    mov di, DUMP_LINE_BUFFER_HEX

    mov cx, 0x10                    ; Number of lines to be printed. Will be used in a loop

    .outer_loop:
        push cx

        ; Main loop that prints a line
        call .buffer_the_address             ; Adds to the buffer the printable representation of the said address
        mov cx, 0x10

        .line_loop:
            mov al, ' '
            stosb
            lodsb
            mov dx, ax
            shr ax, 4
            and ax, 0x0F
            xlatb
            stosb
            mov ax, dx
            and ax, 0x0F
            xlatb
            stosb
            loop .line_loop

            call .print_the_buffer      ; Print buffer

        ; Check if all 16 lines have been printed
        pop cx
        loop .outer_loop                ; Loop to print next line if we're not done
        ret

    .print_the_buffer:
        push si
        push cx
        push bx
        mov cx, 0x36
        mov si, DUMP_LINE_BUFFER_HEX
        mov bx, 0x0007
        mov ah, 0x0E
        .print_loop:
            lodsb
            int 10h
            loop .print_loop
        pop bx
        pop cx
        pop si
        ret

    .buffer_the_address:
        mov bx, HEX_DIGITS
        mov di, DUMP_LINE_BUFFER_HEX
        mov dx, si
        mov cl, 0x04
        .buffer_loop:
            rol dx, 4
            mov ax, dx
            and ax, 0x000F
            xlatb
            stosb
            loop .buffer_loop
        ret



BOOT_DEVICE: db 0x00                            ; The device number of the boot device

STARTUP_MSG:  
  db "E6OS INSTALLATION CD", 0x0A, 0x0D, 0x0A, 0x0D
  db "If you're seeing this, it means your system boots from BIOS.", 0x0A, 0x0D
  db "Press the enter key to continue with the installation of e6os.", 0x00

EAX_HEX:
  .prefix: db "0x"
  .hexstring: dq 0x00

HEX_DIGITS: db "0123456789ABCDEF", 0x00

DUMP_LINE_BUFFER_HEX:
    .address: dd 0x00
    .values: times 6 dq 0x00
    .newline: db 0x0A, 0x0D

STORAGE_DEVICE_SEARCH_MSG:
  db "Searching for storage devices...", 0x0A, 0x0D, 0x0A, 0x0D, 0x00

SELECT_STORAGE_DEVICE_MSG:
  db "Where do you want to install e6os?", 0x0A, 0x0D
  db "Enter 1 to install on a fixed disk", 0x0A, 0x0D
  db "Enter 2 to install on a removable media", 0x0A, 0x0D, 0x00

DETECTED_DEVICES_MSG:
  db "The following storage devices were detected", 0x0A, 0x0D, 0x00

align 256
DETECTED_STORAGE_DEVICES:
  .count: db 0                      ; Bits 0-3 = number of removable disks found. Bits 4-7 = number of fixed disks found
  .removable_disks: times 15 db 0   ; BIOS interrupt numbers for removable disks 0x00 - 0x7F
  .fixed_disks: times 15 db 0       ; BIOS interrupt numbers for fixed disks 0x80 - 0xFF

DRIVE_INFORMATION_BUFFER:
  .buffer_size: dw DRIVE_INFORMATION_BUFFER_SIZE
  .information_flags: dw 0x00
  .cylinders: dd 0x00
  .heads: dd 0x00
  .sectors_per_track: dd 0x00
  .sector_count: dq 0x00
  .bytes_per_sector: dw 0x00
  .dpte_pointer: dd 0x00
  .device_path_info_presence: dw 0x00
  .device_path_info_length: db 0x00
  .reserved_1: db 0x00
  .reserved_2: dw 0x00
  .bus_type_ascii: dd 0x00
  .interface_type_ascii: dq 0x00
  .interface_path: dq 0x00
  .device_path: dq 0x00
  .reserved_3: db 0x00
  .checksum: db 0x00
  .end_buffer: 



DRIVE_INFORMATION_BUFFER_SIZE equ DRIVE_INFORMATION_BUFFER.end_buffer - DRIVE_INFORMATION_BUFFER