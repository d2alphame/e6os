; This is the program loader of e6. It is responsible for loading e6 binaries
; into memory and executing them. The program must contain a header tag within
; its first 65536 byte (64kb). The entirety of the header tag must be within
; this range and must be 8-byte aligned. Note that all e6 programs are loaded at
; memory address 0x200000.
; The following is the header tag which e6 searches for
;
; VALUE			SIZE	NAME			DESCRIPTION
;=========================================================================================
; 'FOR E6OS'	8		Signature		The signature string aligned on 8 byte boundary
; EntryPoint	8		Entry Point		Offset into the image to start executing code from
; Reserved		16		Reserved		Reserved for future use

