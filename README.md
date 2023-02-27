# arm32-darwin-ssh-ramdisk
- Credit:
  - @Ralph0045
  -  /u/meowcat454

This is a port to linux of the original tool [found on reddit](https://www.reddit.com/r/setupapp/comments/ub4ypc/how_to_mount_mnt2_on_ios_9_and_10/)<br>
Binaries have been compiled for linux, and `create.sh` has been modified to work with linux<br>
Per my needs I only converted the 32-bit portion and tested successfully, **use 64-bit devices at your own risk**<br>
Run with `sudo`

Tested on: 
- Debian 11

Please leave an issue if any bugs arise.

## Requirements
- `apt install hfsplus python3`

## Original README:
 
### 32-bit SSH ramdisk tool
This tool was created for mounting /mnt2 on iOS 9 and 10, but it works with all 32-bit devices on iOS 6 and up.

For all steps, replace `[devicetype]` with your device type (like iPhone5,1)

### Part 1: Making the ramdisk
Open a terminal, and run these commands:
1. `cd (drag and drop this ramdisk folder)`

2. `bash create.sh -d [devicetype] -i [iOS version for ramdisk from 6.0 to 10.3.4]`

To mount /mnt2 on iOS 9 and 10, use a ramdisk version of 9.0.1 or higher.

### Part 2: Loading the ramdisk
1. Keep the terminal open, then open sliver and go to the page for your device.

2. Start with entering pwned DFU, but instead of using the ramdisk button, type this into the terminal window: `bash load.sh -d [devicetype]`. If it worked, you should see a verbose boot for a few seconds, and then a screen will show up that looks like this: ![boot screen](https://i.imgur.com/eTyMecj.jpg).

3. After using the Relay Device Info button, connect to the device over SSH (`ssh root@localhost -p 2222`).

4. Once connected, type `mount.sh` to mount the partitions.

### SSH error
If you are on MacOS 13 and get this error when connecting to the device over SSH:

`Unable to negotiate with 127.0.0.1 port 2222: no matching host key type found. Their offer: ssh-rsa,ssh-dss`

Run this command in a terminal:

`echo 'HostKeyAlgorithms=+ssh-rsa' >> ~/.ssh/config`

then try connecting again.

## Update history
2022-04-22: Initial release

2023-01-17: Include dependencies by default, add date binary, clean up scripts
