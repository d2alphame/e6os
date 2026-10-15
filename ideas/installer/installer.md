# Ideas for the e6os installer

## Thu, 15-Oct-2026
```
CODE:
EntryPoint:
    call STANDARD_HEADER.pre_start

    ; ---------------------------------------------------------------------------------------------
    ; Installer flow
    ; ---------------------------------------------------------------------------------------------
    ;
    ; 1. Detect storage devices
    ;    - Locate every handle that supports EFI_BLOCK_IO_PROTOCOL.
    ;    - Skip partitions (Media->LogicalPartition = TRUE), skip devices with no media
    ;      (Media->MediaPresent = FALSE), and skip read-only devices. Only whole disks are candidates.
    ;    - Size in bytes = (Media->LastBlock + 1) * Media->BlockSize.
    ;    - Vendor/model: Block I/O doesn't provide it. Try EFI_DISK_INFO_PROTOCOL or the NVMe/ATA pass-thru
    ;      Identify data. If neither is available, fall back to the device path type (e.g. "NVMe", "SATA", "USB").
    ;
    ; 2. List the devices for the user, one per line, numbered from 1. Show the partitioning scheme, the
    ;    vendor/model and the size in bytes (with thousands separators). Example:
    ;       1. (GPT) Samsung NVMe 12,884,901,888 bytes
    ;       2. (---) SanDisk USB  16,008,609,792 bytes
    ;    - Determine the scheme by reading LBA 0 and LBA 1. A valid GPT has "EFI PART" at the start of LBA 1,
    ;      and the header CRC32 must check out. A bad CRC counts as "not GPT".
    ;    - If no usable device is found, say so and exit to the firmware.
    ;
    ; 3. Select a device
    ;    - The user types a number and presses Enter. Reject out-of-range or non-numeric input and
    ;      ask again. Allow Esc to quit without changing anything.
    ;
    ; 4. Partitioning
    ;    - If the device is not GPT-formatted, tell the user and ask whether to format it with the GPT
    ;      partitioning scheme.
    ;    - If they answer 'y', tell them to back up their data first, because everything on the device
    ;      will be erased. Show the device they chose again (number, vendor, size) in the warning.
    ;    - Require an explicit confirmation (for example, typing ERASE rather than a single key) so
    ;      the destructive step can't be reached by accident.
    ;    - If they answer 'n', go back to step 2 or exit. Nothing is written.
    ;
    ; 5. Write the GPT
    ;    - Protective MBR at LBA 0 (one partition of type 0xEE covering the disk).
    ;    - Primary GPT header at LBA 1 and the partition entry array at LBA 2 onward (128 entries of
    ;      128 bytes, so 32 sectors at 512 bytes per sector).
    ;    - Backup entry array and backup header at the end of the disk.
    ;    - Generate a random disk GUID and a unique GUID for each partition (rdrand is available).
    ;    - Compute CRC32 over the entry array first, then over the header.
    ;    - Align partition starts to 1 MiB.
    ;    - Call FlushBlocks and read everything back to verify before moving on.
    ;
    ; 6. Create the EFI System Partition (ESP)
    ;    - Partition type GUID C12A7328-F81F-11D2-BA4B-00A0C93EC93B.
    ;    - Size: 512 MiB is a safe default. FAT32 needs at least 65,525 clusters, which is the practical
    ;      lower bound on small partitions.
    ;    - Format it as FAT32: boot sector (with the backup at sector 6), FSInfo sector, two FATs and a
    ;      root directory at cluster 2. Set a volume label (e.g. "E6EFI").
    ;    - Create \EFI\BOOT\ and copy the e6 boot loader to \EFI\BOOT\BOOTX64.EFI, which is the
    ;      fallback path firmware looks for when there are no boot entries.
    ;
    ; 7. Create the e6 system partition
    ;    - Uses the remaining space (or a size the user chooses) and an e6-specific partition type GUID.
    ;    - Write the kernel and the other files that the boot loader needs into it.
    ;
    ; 8. Finish
    ;    - Tell the user the installation is complete, ask them to remove the install media, and press a key
    ;      to reboot (ResetSystem).
    ;    - On any failure, report the step that failed and the EFI_STATUS value (print_rax is handy here)
    ;      and don't continue to the next step.
    ; ---------------------------------------------------------------------------------------------

    xor eax, eax                    ; EFI_SUCCESS
    ret
```
Some refinements:
```
    ; 1. Detect storage devices
    ;    - Locate every handle that supports EFI_BLOCK_IO_PROTOCOL.
    ;    - Skip partitions (Media->LogicalPartition = TRUE), devices with no media
    ;      (Media->MediaPresent = FALSE), and read-only devices.
    ;    - Skip any device whose Media->BlockSize is not 4096. The e6 installer supports 4096-byte-sector
    ;      drives only. 512-byte-sector drives (including 512e drives that emulate 512 over 4K
    ;      physical sectors) are never listed.
    ;    - Size in bytes = (Media->LastBlock + 1) * 4096.
    ;
    ; 2. List the devices ...
    ;    - If no 4096-byte-sector device is found, say so explicitly ("no 4Kn drives found") rather than
    ;      a generic "no devices", and exit to the firmware. Otherwise users with only 512-byte
    ;      drives will think detection is broken.
    ;
    ; 5. Write the GPT (all LBAs are 4096-byte sectors)
    ;    - Protective MBR at LBA 0: the 0xEE partition covers LBA 1 through min(LastBlock, 0xFFFFFFFF).
    ;      The MBR signature 0x55AA still sits at byte offset 510 of the sector. The rest of the
    ;      4096-byte sector is zero.
    ;    - Primary GPT header at LBA 1 (92 bytes used, the remainder of the sector zero).
    ;    - Partition entry array at LBA 2: 128 entries x 128 bytes = 16,384 bytes = 4 sectors (LBA 2-5).
    ;    - FirstUsableLBA = 6, but align the first partition to 1 MiB = LBA 256.
    ;    - Backup entry array occupies the last 4 sectors before the last LBA, and the backup header is
    ;      at LastBlock. LastUsableLBA = LastBlock - 5.
    ;
    ; 6. Create the EFI System Partition (ESP)
    ;    - On 4Kn, FAT32 needs at least 65,525 clusters. At 1 sector per cluster (4 KiB) that is
    ;      about 256 MiB at minimum, so the 512 MiB default is fine (131,072 clusters of 4 KiB at the
    ;      smallest cluster size, or use 8 sectors per cluster, i.e. 32 KiB, if you prefer).
    ;    - BPB_BytsPerSec = 4096. FSInfo is at sector 1, the backup boot sector at sector 6. These
    ;      are the same sector numbers as on 512-byte drives. Only the sector size changes.
    ;    - Many FAT32 drivers, including some firmware implementations, handle 4096 bytes per sector
    ;      poorly. Test the ESP on the firmware you target. If your own boot loader reads it, you
    ;      control that code.
```


## Thu, 08-Oct-2026

To install the e6 operating system, the user carries out the following steps:

1. Get an external storage device such as a usb flash stick, ssd disk, or external hard drive.
2. Use GPT partitioning scheme to partition the storage device. This step can be skipped if the external storage already has this.
3. Create a FAT32 system partition (UEFI uses FAT32 to boot). Mark the partition as the EFI System Partition (ESP).
4. Copy the installer files on to the ESP partition.
5. Boot the system from that external storage device.
6. The e6os installer starts up and runs. Follow the installer steps to install e6os on the target system.


## Tue, 16-Jun-2026

The following outlines steps the installer needs to take when installing e6os.
1. UEFI boots the e6 installer from the usb flash disk.
2. Installer prints the installer's boot message.
3. Installer enumerates storage devices.
4. Present storage devices and ask use to select one for installation of e6os.
5. User selects installation device
6. Warn user data might get lost and advice user to back up.
7. User backs up data and continues.
8. If storage device has GPT, then find EFI System Partition and copy OS files.
9. If no, format the storage device and install OS files.
10. Restart, ask user to restart
11. E6os is ready to run from the computer

