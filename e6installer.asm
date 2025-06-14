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

mov [BOOT_DEVICE], dl                             ; Before doing anything, save the boot device

; Setup a stack we can work with. With the following setup, we keep our fingers
; crossed and hope we don't overwrite the IVT and the BDA :D
xor ax, ax
mov ss, ax
mov sp, 0x8000
mov bp, sp

; Setup a flat segment with CS=DS=ES
mov ax, INSTALLER_STARTUP_SEGMENT                 ; This is defined in the e6constants.asm file included above
mov ds, ax
mov es, ax

sti                                               ; Set interrupts again

; Show the installer's startup message
mov si, STARTUP_MSG
xor al, al
call print_byte_terminated_string
jmp $

; A bunch of functions that will be useful
; ========================================


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
 

wait_for_key:
  ; Waits for a given key to be pressed


; Dump content of memory in hexadecimal. Dumps 256 bytes of memory
; IN
;   SI: Memory address to dump.
; NOTE: The address is expected to be 256-byte aligned
dump_memory_hex:

    ; Check to ensure the address is 256 byte aligned
    mov dx, si
    and dx, 0x00FF
    cmp dx, 0x00
    je .continue
    stc                             ; Set the carry flag to mean an error occured
    retf

    ; Start on a new line
    .continue:
        mov bx, 0x0007
        mov ah, 0x0E
        mov al, 0x0A
        int 10h
        mov al, 0x0D
        int 10h

    ; Print the headers
    ; First print out intial 8 spaces in the header
    mov cl, 0x04
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
    .newline: db 0x0A, 0x0D     ;;