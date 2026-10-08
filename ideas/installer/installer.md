# Ideas for the e6os installer

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


## Thu, 08-Oct-2026

To install the e6 operating system, the user carries out the following steps:

1. Get an external storage device such as a usb flash stick, ssd disk, or external hard drive.

2. Use GPT partitioning scheme to partition the storage device. This step can be skipped if the external storage already has this.

3. Create a FAT32 system partition (UEFI uses FAT32 to boot). Mark the partition as the EFI System Partition (ESP).

4. Copy the installer files on to the ESP partition.

5. Boot the system from that external storage device.

6. The e6os installer starts up and runs. Follow the installer steps to install e6os on the target system.