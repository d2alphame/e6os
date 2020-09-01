# e6os
The e6 Operating System is a single-tasking, single-user, multithreading operating system. It is a 64-bits OS, works on a GPT-formatted disk, and boots via UEFI.

## Some things to know about e6
1. All I/O is asynchronous by default
2. Subroutines live and run in their own thread by default
3. All parameters are passed ByVal by default. This means copies are made and passed to the called sub with the original unaffected

On e6 all memory is identity mapped. That is:
	virtual_memory = physical_memory

Paging is setup to 2MB per page and memory is allocated on a page-by-page basis.
This means calling 'malloc' gives a 2MB memory page.

The OS itself lives in the upper 4MB of memory space. That represents the last 2 pages of memory.