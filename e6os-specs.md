# e6os Complete Design Documentation

## Table of Contents
1. [Overview](#overview)
2. [Core Architecture](#core-architecture)
3. [Memory Layout](#memory-layout)
4. [Binary Format](#binary-format)
5. [Program Loading](#program-loading)
6. [Calling Convention](#calling-convention)
7. [Protection Mechanisms](#protection-mechanisms)
8. [I/O Model](#io-model)
9. [Threading](#threading)
10. [Filesystem Support](#filesystem-support)
11. [UEFI Boot](#uefi-boot)

---

## Overview

**e6os** is a single-task, single-process, single-user, multithreaded operating system for x86-64 architecture.

### Design Philosophy
- **Simplicity**: Single-task eliminates process management overhead
- **Performance**: 2MiB pages reduce TLB pressure
- **Concurrency**: Multithreading provides parallelism within single task
- **Efficiency**: Asynchronous I/O maximizes CPU utilization
- **Compatibility**: Multi-OS executable format

### Key Characteristics
- **Architecture**: x86-64 (AMD64)
- **Page Size**: 2MiB pages exclusively
- **Boot**: UEFI
- **I/O Model**: All file I/O is asynchronous
- **Threading**: Preemptive with cooperative yield

---

## Core Architecture

### Single-Task Model
- One program loaded at a time at 0x400000
- No process isolation between programs (they run sequentially)
- Simpler scheduler - only thread scheduling within one program
- No context switching between processes

### Multithreading
- **Type**: Preemptive multithreading with cooperative yield
- **Preemptive**: Timer interrupt forces context switches
- **Cooperative**: Threads can voluntarily yield via syscall
- **Thread States**:
  - RUNNABLE (0): Ready to run
  - RUNNING (1): Currently executing
  - IO_BLOCKED (2): Waiting for I/O completion
  - TERMINATED (4): Finished execution

---

## Memory Layout

### Fixed Address Ranges

```
0x000000 - 0x1FFFFF  (2MiB)   OS/Kernel
0x200000 - 0x3FFFFF  (2MiB)   Program Information Block
0x400000 - 0x5FFFFF  (2MiB)   Initial Program Code+Data Page
0x600000+                     Dynamic Allocation Region (Stack/Heap/Additional Pages)
```

### Page Protection

All memory uses 2MiB pages with protection bits:

**OS Memory (0x000000-0x1FFFFF)**:
- U/S = 0 (Supervisor only, Ring 0)
- R/W = 1 (Writable)
- XD = 0 (Executable)

**Info Block (0x200000-0x3FFFFF)**:
- U/S = 1 (User accessible)
- R/W = 0 (Read-only)
- XD = 1 (No execute)

**Program Code+Data (0x400000-0x5FFFFF)**:
- U/S = 1 (User accessible)
- R/W = 1 (Writable)
- XD = 0 (Executable)

**Stack/Heap Pages (0x600000+)**:
- U/S = 1 (User accessible)
- R/W = 1 (Writable)
- XD = 1 (No execute - NX stack protection)

### Register State at Program Entry

```
RBX = Entry point address (0x400000 + entry_point_offset)
RAX = Random number
RDX = ~RAX (bitwise NOT of RAX)
RSP = 0x600000 (stack pointer)
Other registers = undefined
```

**Multi-OS Detection**:
```asm
; Check if running on e6os
test rax, rdx    ; Will be 0 if rax = ~rdx
jz running_on_e6os
```

---

## Program Information Block

Located at 0x200000-0x3FFFFF, provides execution context to programs.

### Structure

**Flags (1 byte)**:
- Bit 0: stdin is file (0=terminal, 1=file)
- Bit 1: stdout is file (0=terminal, 1=file)
- Bit 2: stderr is file (0=terminal, 1=file)
- Bit 3: program name from file (0=command line, 1=file)
- Bit 4: auto-run by OS (0=manual invocation, 1=auto-run)
- Bit 5-7: Reserved

**Strings** (length-prefixed, ASCII):
- stdin filename (Tiny String: 1-byte length prefix)
- stdout filename (Tiny String)
- stderr filename (Tiny String)
- commandline (Small String: 2-byte length prefix) - exact command as typed
- BinPath (Small String) - full path to executable's directory
- Bin (Tiny String) - binary filename as it appears on disk
- WorkingDirectory (Small String) - current directory when launched

**Version Info**:
- OSMajorVersion (1 byte)
- OSMinorVersion (1 byte)
- LoaderMajorVersion (1 byte)
- LoaderMinorVersion (1 byte)

### String Types

**Length-Prefixed Strings**:
- **Tiny String**: 1-byte length (max 255 bytes)
- **Small String**: 2-byte length (max 65535 bytes)
- **Big String**: 4-byte length (max 4GB)
- **Huge String**: 8-byte length

**Terminated Strings**:
- Null-terminated (0x00)
- Custom byte terminator

**Encoding**: All strings are ASCII

---

## Binary Format

### E6BINARY Header

Must be 8-byte aligned and within first 65536 bytes of file.

```
Offset | Size | Field
-------|------|------
+0     | 8B   | Magic: "E6BINARY" (ASCII: 45 36 42 49 4E 41 52 59)
+8     | 4B   | Entry point offset (relative to 0x400000)
+12    | 2B   | Flags
+14    | 10B  | Reserved for future use
+24    | 8B   | XOR checksum of bytes 0-23
-------|------|------
Total: 32 bytes
```

### Flags Field (2 bytes)

- Bit 0: Checksum validation
  - 0 = Skip checksum validation
  - 1 = Validate checksum (abort load if invalid)
- Bit 1-15: Reserved

### Checksum Calculation

XOR checksum of first 24 bytes as three 8-byte values:
```
checksum = bytes[0:7] XOR bytes[8:15] XOR bytes[16:23]
```

Stored checksum at bytes[24:31].

**Verification**: XOR all four 8-byte values (including stored checksum) should equal 0:
```
bytes[0:7] XOR bytes[8:15] XOR bytes[16:23] XOR bytes[24:31] = 0
```

### Entry Point

- **Entry point offset**: Relative to 0x400000
- **Actual entry address**: 0x400000 + entry_point_offset
- Stored in RBX register at program start

---

## Program Loading

### Loader Algorithm

```asm
; Assume file loaded at 0x400000

mov rdi, 0x400000          ; Start of loaded file
mov rax, "E6BINARY"        ; Magic string to find
mov rcx, 8188              ; 65536/8 - 4 qwords to scan
repne scasq                ; Scan for magic string
jnz .error                 ; Not found

sub rdi, 8                 ; Back up to magic location
push rdi                   ; Save header address

mov ebx, dword [rdi+8]     ; Read entry point offset (4 bytes)
lea r8, [rbx + 0x400000]   ; Calculate absolute entry point

mov ax, word [rdi+12]      ; Read flags (2 bytes)
test ax, 1                 ; Check checksum flag
jz .continue               ; Skip if flag clear

; Validate checksum
mov rsi, rdi               ; Point to header start
mov rcx, 4                 ; 4 qwords (32 bytes including checksum)
xor rdx, rdx               ; Accumulator
.loop:
    lodsq                  ; Load qword, increment RSI
    xor rdx, rax           ; XOR into accumulator
    loop .loop
jnz .invalid_checksum      ; RDX should be 0 if valid

.continue:
    rdrand rax             ; Generate random number
    mov rdx, rax           ; Copy to RDX
    not rdx                ; RDX = ~RAX
    mov rbx, r8            ; Entry point in RBX
    mov rsp, 0x600000      ; Set stack pointer
    
    ; Populate info block at 0x200000
    ; ... (populate flags, strings, versions) ...
    
    jmp r8                 ; Jump to entry point
```

### Multi-OS Executable Support

Single binary can run on multiple operating systems:
- E6BINARY header located anywhere in first 64KB
- Can be embedded in PE, ELF, or Mach-O headers
- Program detects e6os via RAX/RDX test at entry

---

## Calling Convention

### e6 Calling Convention (for internal functions)

**Parameter Passing by Type**:
- **RAX**: First number/integer
- **RDX**: Second number/integer
- **RCX**: Counter (loop index, size, count)
- **RSI**: First string (pointer)
- **RDI**: Second string (pointer)
- **RBX**: Buffer/array pointer OR parameter overflow buffer

**Overflow Rule**: If more parameters than available registers for a given type:
- 3+ numbers: All parameters go in buffer pointed to by RBX
- 3+ strings: All parameters go in buffer pointed to by RBX
- 2+ counters: All parameters go in buffer pointed to by RBX

**Callee Responsibilities**:
- Must preserve RBP

**Return Values** (non-error):
- TBD (not yet finalized)

### Error Handling

**Return Convention**:
- **CF (Carry Flag)**: Error indicator
  - Clear (0) = Success
  - Set (1) = Error occurred
- **RAX**: Error code (if CF set)
- **RSI**: Error string pointer (if CF set)

**Example**:
```asm
call some_function
jc .handle_error        ; Jump if carry set

; Success path
; ... use return values ...
jmp .continue

.handle_error:
    ; RAX = error code
    ; RSI = error string
    ; ... handle error ...

.continue:
```

---

## Protection Mechanisms

### Privilege Levels

- **Ring 0 (Kernel)**: OS runs here, full access to all memory
- **Ring 3 (User)**: Programs run here, restricted access

### Separate Stacks

- **User Stack**: At 0x600000+, used when running in Ring 3
- **Kernel Stack**: Separate location, used when running in Ring 0
- CPU automatically switches stacks on privilege level transitions (configured via TSS)

### System Call Interface

**Entry Point**: Single syscall_entry handler in Ring 0

**Flow**:
```
1. User program executes `syscall` instruction
2. CPU automatically:
   - Saves user RIP to RCX
   - Saves user RFLAGS to R11
   - Switches to Ring 0
   - Switches to kernel stack (from TSS)
   - Jumps to syscall_entry (from IA32_LSTAR MSR)
3. OS validates syscall number and parameters
4. OS dispatches to appropriate handler via syscall table
5. Handler executes and returns result
6. OS executes `sysret` instruction
7. CPU returns to Ring 3 and user stack
```

**Syscall Entry Handler**:
```asm
syscall_entry:
    ; Save user registers
    push rcx        ; User return address
    push r11        ; User RFLAGS
    push rbp
    push rbx
    ; ... save others as needed ...
    
    ; Validate syscall number
    cmp rax, MAX_SYSCALL_NUMBER
    jae .invalid_syscall
    
    ; Validate pointer parameters
    ; (check if in valid user memory range)
    
    ; Dispatch to handler
    lea rbx, [syscall_table]
    mov rax, [rbx + rax * 8]
    call rax
    
    ; Handler returns with result in RAX, CF for error
    
.return_to_user:
    ; Restore user registers
    pop rbx
    pop rbp
    pop r11
    pop rcx
    
    sysret         ; Return to Ring 3
```

### Validation

OS validates:
1. **Syscall number**: Within valid range
2. **Pointers**: In user memory (not OS memory 0x000000-0x1FFFFF)
3. **Buffer sizes**: Within reasonable limits
4. **String parameters**: Maximum length, null-terminated
5. **Numeric parameters**: Valid ranges, enum values

### Syscall vs Direct Calls

**Heavy operations use syscalls** (Ring 0):
- File I/O (read blocks, write/flush)
- Memory allocation (request 2MiB pages)
- Thread management (create, destroy, synchronize)
- Device access
- Network operations

**Lightweight operations use userspace libraries** (Ring 3):
- String manipulation (strlen, strcmp, strcpy)
- Memory operations (memcpy, memset, memmove)
- Math functions
- Data structure helpers
- No syscall overhead!

---

## I/O Model

### Asynchronous I/O

**All file I/O is asynchronous** - operations return immediately.

### Async I/O with Optional Blocking

Programs can choose whether to wait for I/O completion:

**Flags**:
- `IO_NOWAIT (0x00)`: Return immediately if not ready
- `IO_BLOCK (0x01)`: Suspend thread/process if not ready

**Syscall Interface**:
```asm
; Read file asynchronously
; Inputs:
;   RSI = filename
;   RDX = buffer
;   RCX = size
;   RDI = flags (IO_BLOCK or IO_NOWAIT)
; Returns:
;   CF clear = completed (data ready in buffer)
;   CF set = in progress, RAX = operation_id
```

### Usage Patterns

**Non-blocking (do other work while waiting)**:
```asm
; Start I/O
mov rax, SYSCALL_READ_ASYNC
lea rsi, [filename]
lea rdx, [buffer]
mov rcx, 4096
mov rdi, IO_NOWAIT       ; Don't block
syscall
jc .io_pending           ; CF set = in progress

; Already done (cached)
call process_data
jmp .continue

.io_pending:
    mov [io_id], rax     ; Save operation ID
    
    ; Do other work
    call calculate_something
    call render_frame
    
    ; Check if done
    mov rax, SYSCALL_POLL_IO
    mov rdx, [io_id]
    mov rdi, IO_NOWAIT
    syscall
    jc .io_pending       ; Still not ready
    
    ; Now ready
    call process_data
    
.continue:
```

**Blocking (simple, wait for completion)**:
```asm
; Read file, block if not ready
mov rax, SYSCALL_READ_ASYNC
lea rsi, [filename]
lea rdx, [buffer]
mov rcx, 4096
mov rdi, IO_BLOCK        ; Willing to wait
syscall

; Returns here when data is ready
; (this thread was suspended if I/O wasn't immediate)
call process_data
```

### Benefits

- **Maximum CPU utilization**: CPU does useful work while waiting for I/O
- **Flexible programming model**: Choose blocking or non-blocking per operation
- **Thread-level concurrency**: I/O-blocked threads don't prevent other threads from running
- **Simple when needed**: Blocking I/O provides synchronous-like simplicity
- **Efficient when needed**: Non-blocking I/O provides maximum performance

### Buffered I/O

Userspace library can provide buffered I/O to reduce syscall overhead:

```asm
; Userspace buffered write
section .bss
    write_buffer: resb 8192
    write_pos: resq 1

section .text

putchar:
    ; Input: AL = byte to write
    push rbx
    mov rbx, [write_pos]
    mov [write_buffer + rbx], al
    inc rbx
    mov [write_pos], rbx
    
    ; Flush if buffer full
    cmp rbx, 8192
    jge flush_write_buffer
    
    pop rbx
    ret

flush_write_buffer:
    ; Make syscall only when buffer is full
    mov rax, SYSCALL_WRITE
    lea rsi, [write_buffer]
    mov rdx, [write_pos]
    syscall
    
    mov qword [write_pos], 0
    ret
```

---

## Threading

### Threading Model

**Preemptive Multithreading**:
- Timer interrupt forces context switches every N milliseconds
- Prevents threads from hogging CPU
- Ensures responsiveness

**Cooperative Yield**:
- Threads can voluntarily yield via `SYSCALL_YIELD`
- Immediate context switch without waiting for timer
- More efficient than spinning or busy-waiting

### Thread States

```
RUNNABLE (0)    - Ready to run
RUNNING (1)     - Currently executing
IO_BLOCKED (2)  - Waiting for I/O (blocking poll)
TERMINATED (4)  - Finished execution
```

### Yield Syscall

```asm
SYSCALL_YIELD:
sys_yield:
    ; Save current thread context
    call save_thread_context
    
    ; Mark thread as runnable
    mov rbx, [current_thread]
    mov byte [thread_state + rbx], RUNNABLE
    
    ; Pick next thread
    call schedule_next_thread
    
    ; Context switch
    call switch_to_thread
    
    ; Returns here when rescheduled
    ret
```

### Usage Examples

**Spinlock with yield**:
```asm
acquire_lock:
    mov al, 1
.spin:
    xchg [lock], al
    test al, al
    jz .acquired
    
    ; Instead of spinning, yield to other threads
    mov rax, SYSCALL_YIELD
    syscall
    
    mov al, 1
    jmp .spin
    
.acquired:
    ret
```

**I/O polling with yield**:
```asm
wait_for_io:
    mov rax, SYSCALL_POLL_IO
    mov rdx, [io_id]
    mov rdi, IO_NOWAIT
    syscall
    jc .not_ready
    ret
    
.not_ready:
    ; Yield instead of busy-waiting
    mov rax, SYSCALL_YIELD
    syscall
    jmp wait_for_io
```

**Event loop**:
```asm
event_loop:
.loop:
    mov rax, SYSCALL_GET_EVENT
    mov rdi, IO_NOWAIT
    syscall
    jc .no_events
    
    call handle_event
    jmp .loop
    
.no_events:
    ; No work, yield to other threads
    mov rax, SYSCALL_YIELD
    syscall
    jmp .loop
```

### Scheduler

**Round-robin scheduling** (simple implementation):

```asm
thread_scheduler:
.next:
    inc [current_thread_index]
    mov rbx, [current_thread_index]
    
    ; Wrap around
    cmp rbx, [num_threads]
    jl .check_runnable
    xor rbx, rbx
    mov [current_thread_index], rbx
    
.check_runnable:
    cmp byte [thread_state + rbx], RUNNABLE
    jne .next
    
    ; Found runnable thread
    call switch_to_thread
    ret
```

**Timer interrupt handler**:
```asm
timer_interrupt:
    ; Save all registers
    push rax
    push rbx
    ; ... (all registers)
    pushfq
    
    ; Decrement current thread's timeslice
    mov rbx, [current_thread]
    dec qword [thread_timeslice + rbx]
    jnz .no_switch
    
    ; Timeslice expired, force context switch
    call schedule_next_thread
    call switch_to_thread
    
.no_switch:
    ; Acknowledge interrupt
    mov al, 0x20
    out 0x20, al
    
    ; Restore registers
    popfq
    ; ... (all registers)
    pop rbx
    pop rax
    
    iretq
```

---

## Filesystem Support

### Supported Filesystems

1. **FAT32** - Primary filesystem
   - UEFI boot partition requirement
   - Simple, well-documented
   - Universal compatibility
   - First filesystem to implement

2. **ext3** - Linux compatibility
   - Journaling for reliability
   - Simpler than ext4
   - Future implementation

3. **CDFS (ISO 9660)** - Optional
   - Standard for optical media
   - May implement later if needed

4. **sixfs** - e6's native read/write filesystem
   - Standard filesystem for everyday use
   - System files, user data, applications
   - Full-featured

5. **vixenfs** - e6's native read-only filesystem
   - Simple distribution/archive format
   - For software packages, OS images, static content
   - Easy to create ("burn" files into image)
   - Easy to implement (read-only = simpler)
   - Can use disk partition or image file

### Implementation Priority

**Phase 1**: FAT32
- Needed immediately for UEFI boot
- Enables early file I/O for development
- Can exchange files with other OSes

**Phase 2**: vixenfs
- Simple to implement (read-only)
- Useful for software distribution

**Phase 3**: sixfs
- Full-featured native filesystem

**Phase 4**: ext3 (optional)
- If Linux compatibility needed

---

## UEFI Boot

### UEFI Executable Format

e6os bootloader uses PE32+ (PE64) format for UEFI compatibility.

### Minimal UEFI PE64 Header

```asm
BITS 64

; DOS Header (minimal, overlapped with PE)
dos_header:
    dw 'MZ'                     ; e_magic
    times 29 dw 0               ; Skip to e_lfanew
    dw 0                        ; Padding
    dd pe_header                ; e_lfanew: offset to PE

; PE Header at offset 0x40
pe_header:
    dd 'PE'                     ; PE signature
    
; COFF Header
    dw 0x8664                   ; Machine: x86-64
    dw 1                        ; NumberOfSections
    dd 0                        ; TimeDateStamp
    dd 0                        ; PointerToSymbolTable
    dd 0                        ; NumberOfSymbols
    dw optional_header_size     ; SizeOfOptionalHeader
    dw 0x0206                   ; Characteristics

; Optional Header (PE32+)
optional_header:
    dw 0x020B                   ; Magic: PE32+
    db 0x02                     ; MajorLinkerVersion
    db 0x14                     ; MinorLinkerVersion
    dd code_size                ; SizeOfCode
    dd 0                        ; SizeOfInitializedData
    dd 0                        ; SizeOfUninitializedData
    dd entry_point              ; AddressOfEntryPoint
    dd 0x1000                   ; BaseOfCode
    dq 0                        ; ImageBase
    dd 0x1000                   ; SectionAlignment
    dd 0x200                    ; FileAlignment
    dw 0                        ; MajorOSVersion
    dw 0                        ; MinorOSVersion
    dw 0                        ; MajorImageVersion
    dw 0                        ; MinorImageVersion
    dw 0                        ; MajorSubsystemVersion
    dw 0                        ; MinorSubsystemVersion
    dd 0                        ; Win32VersionValue
    dd image_size               ; SizeOfImage
    dd headers_size             ; SizeOfHeaders
    dd 0                        ; CheckSum
    dw 0x0A                     ; Subsystem: EFI_APPLICATION
    dw 0                        ; DllCharacteristics
    dq 0                        ; SizeOfStackReserve
    dq 0                        ; SizeOfStackCommit
    dq 0                        ; SizeOfHeapReserve
    dq 0                        ; SizeOfHeapCommit
    dd 0                        ; LoaderFlags
    dd 0                        ; NumberOfRvaAndSizes: NO DATA DIRECTORIES
```

### UEFI Calling Convention

UEFI uses **Microsoft x64 calling convention**:

**Parameters**:
- RCX, RDX, R8, R9 (first 4 parameters)
- Additional parameters on stack at RSP+32, RSP+40, etc.

**Shadow Space**:
- Caller must reserve 32 bytes on stack (even for <4 parameters)

**Stack Alignment**:
- RSP must be 16-byte aligned before call

**Volatile Registers**:
- RAX, RCX, RDX, R8-R11, XMM0-5 (caller-saved)

**Non-volatile Registers**:
- RBX, RBP, RDI, RSI, RSP, R12-R15 (callee-saved)

### UEFI Call Template

```asm
uefi_call:
    ; Save non-volatile registers
    push rbx
    push rbp
    
    ; Align stack
    mov rbp, rsp
    and rsp, ~15        ; 16-byte alignment
    
    ; Allocate shadow space
    sub rsp, 32
    
    ; Setup parameters (example: 2 parameters)
    mov rcx, param1     ; First parameter
    mov rdx, param2     ; Second parameter
    
    ; Make the call
    call [function_pointer]
    
    ; Cleanup
    mov rsp, rbp
    pop rbp
    pop rbx
    ret
```

### UEFI Console Output

**UEFI Entry Point**:
```asm
efi_main:
    ; UEFI provides:
    ; RCX = EFI_HANDLE ImageHandle
    ; RDX = EFI_SYSTEM_TABLE *SystemTable
    
    mov [ImageHandle], rcx
    mov [SystemTable], rdx
    
    ; ... bootloader code ...
```

**Print String** (UTF-16):
```asm
print_string:
    ; Input: RDX = pointer to UTF-16 string
    
    push rbx
    push rbp
    mov rbp, rsp
    and rsp, ~15
    sub rsp, 32
    
    ; Get ConOut pointer
    mov rbx, [SystemTable]
    mov rbx, [rbx + 64]     ; ConOut at offset 64
    
    ; Call ConOut->OutputString(ConOut, String)
    mov rcx, rbx            ; this pointer
    ; RDX already has string
    call [rbx + 8]          ; OutputString at offset 8
    
    mov rsp, rbp
    pop rbp
    pop rbx
    ret

; UTF-16 string example
HelloString:
    dw 'H', 'e', 'l', 'l', 'o', '!', 0x0A, 0x0D, 0
```

**Important**: UEFI strings are UTF-16LE (2 bytes per character).

### Boot Process

1. **UEFI firmware** loads e6 bootloader (PE64 format)
2. **Bootloader** uses UEFI services for:
   - Console output (debugging)
   - Disk I/O (reading OS files)
   - Memory allocation
   - Graphics (optional)
3. **Load e6os kernel** from disk
4. **Setup page tables** with protection bits
5. **Setup GDT, IDT, TSS**
6. **Configure syscall/sysret** (MSRs)
7. **Load first program** with E6BINARY format
8. **Switch to Ring 3** and jump to program entry

---

## Future Considerations

### Not Yet Decided

1. **Non-error return values**: Which registers for multiple return values
2. **Exact syscall interface**: Which syscalls, syscall numbers
3. **Thread creation API**: Parameters, limits
4. **Memory allocation API**: How programs request additional 2MiB pages
5. **Info block byte offsets**: Exact layout of fields
6. **Reserved flag bits**: Usage of bits 5-7 in info block flags
7. **Reserved header fields**: Usage of 10 reserved bytes in E6BINARY header
8. **sixfs design**: Feature set, journaling, optimizations
9. **vixenfs design**: Directory structure, metadata

### Design Tradeoffs Discussed

**Security vs Performance**:
- Syscalls have overhead (~100-200 cycles) but provide validation
- Choice: Use ring protection or run everything in Ring 0
- Current direction: Use syscalls for heavy operations, direct calls for lightweight

**Single-Process Limitations**:
- CPU idle during I/O if single-threaded
- **Solution**: Asynchronous I/O + multithreading
- Threads can block on I/O while others continue

---

## Summary

e6os is designed to be:
- **Simple**: Single-task reduces complexity
- **Fast**: 2MiB pages, minimal overhead, direct hardware access
- **Concurrent**: Multithreading provides parallelism
- **Efficient**: Async I/O with optional blocking maximizes CPU usage
- **Safe**: Ring protection prevents bugs from corrupting OS
- **Compatible**: Multi-OS executables, standard filesystems
- **Modern**: x86-64, UEFI, NVMe, preemptive threading

The design balances simplicity with functionality, providing a clean foundation for a performance-oriented operating system.
