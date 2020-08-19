; This is the program loader of e6. It is responsible for loading e6 binaries
; into memory and executing them. The program must contain a header tag within
; its first 65536 bytes (64kb). The header tag must be 8-byte aligned. Note that
; all e6 programs are loaded at memory address 0x200000.
; The following is the header tag which e6 searches for
;
; VALUE			SIZE	NAME			DESCRIPTION
;=========================================================================================
; 'FOR E6OS'	8		Signature		The signature string aligned on 8 byte boundary
; EntryPoint	8		Entry Point		Offset into the image to start executing code from
; Reserved		16		Reserved		Must be zeros. Reserved for future use

BITS 64
org 0x200000

mov rax, 'FOR E6OS'							; The signature value to find
mov rdi, 0x200000							; Start address to begin search from
mov rcx, 0x2000								; This is the number of string quads to search

begin:
repnz scasq									; Search for the e6 signature
jnz .not_found								; If zero flag is set here then the signature was not found

; Prepare to get the entry point
mov rsi, rdi
lodsq										; Gets the entry point in rax
mov rbx, rax								; Move it over to rbx
call rbx									; Make the call to the program