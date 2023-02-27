#!/bin/bash

## Ramdisk_Loader - Copyright 2019-2020, @Ralph0045

echo "**** SSH Ramdisk_Loader 2.0 ****"
echo "made by @Ralph0045, patched version by meowcat454"
echo "Ported to Linux by joshrmcdaniel"

set -e

if [ $# -lt 2 ]; then
echo "Usage:

-d      specify device by model
-a	use alternate iBSS (if loading ramdisk gets stuck)

[example]

bash Ramdisk_Loader.sh -d iPhone5,1
"
exit
fi

args=("$@")

for i in {0..2}
 do
    if [ "${args[i]}" = "-d" ]; then
        device=${args[i+1]}
    fi
done

type=$(echo ${device:0:6})

if ! [ -d "SSH-Ramdisk-"$device"" ]; then
echo "Ramdisk folder not found, run Ramdisk_Maker.sh to create one."
exit 1
fi

cd SSH-Ramdisk-$device

read -p "Enter pwned DFU mode, then press Enter to continue." -n1 -s

echo
if [ "$3" == "-a" ]; then
  if [ -f "../resources/iBSS/$device.bin" ]; then
    echo "Sending alternate iBSS..."
    irecovery -f ../resources/iBSS/$device.bin
  else
    echo "No alternate iBSS found!"
    exit 1
  fi
else
  echo "Sending iBSS..."
  ../resources/irecovery -f iBSS
fi

sleep 1
echo "Sending iBEC..."
../resources/irecovery -f iBEC

sleep 3
../resources/irecovery -c "bgcolor 224 96 158"
echo "Sending device tree..."
../resources/irecovery -f devicetree
../resources/irecovery -c devicetree

sleep 1
echo "Sending ramdisk..."
../resources/irecovery -f ramdisk.dmg
../resources/irecovery -c ramdisk

echo "Sending kernelcache..."
../resources/irecovery -f kernelcache
echo "Booting device now..."
../resources/irecovery -c bootx

echo "Finished! You should see a verbose boot then the ramdisk logo."

cd ..
