# e6os
The e6 Operating System is a single-tasking, single-user, multithreading operating system. It is a 64-bits OS, works on a GPT-formatted disk, and boots via UEFI.

## Some things to know about e6
1. All I/O is asynchronous by default
2. Subroutines live and run in their own thread by default
3. All parameters are passed ByVal by default. This means copies are made and passed to the called sub with the original unaffected
