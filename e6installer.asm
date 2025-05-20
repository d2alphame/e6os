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

START:
mov ah, 0x0E
mov bx, 0x0007
mov al, 'E'
int 10h
jmp $

times 32768-($-START) db 0

