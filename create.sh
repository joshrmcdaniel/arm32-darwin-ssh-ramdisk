#!/bin/bash

## Ramdisk_Maker - Copyright 2019-2020, @Ralph0045
## Ported to linux by @joshrmcdaniel

echo "**** SSH Ramdisk_Maker 2.0 ****"
echo "made by @Ralph0045, patched version by meowcat454"
echo "ported to linux by joshrmcdaniel"

if [ $# -lt 2 ]; then
echo "Usage:

-d      specify device by model
-i      specify iOS version (if not specified, it will use earliest version available)

[example]

ramdisk_maker -d iPhone5,1 -i 9.0.1
For /mnt2 support on iOS 9/10, you must use a ramdisk of iOS 9 or higher.
"
exit
fi

if ! [ -d "bin" ]; then
  echo "Required files not found, you must run Requirements.sh first."
  exit 1
fi

args=("$@")

for i in {0..4}
 do
    
    if [ "${args[i]}" = "-d" ]; then
        device=${args[i+1]}
    fi
    
    if [ "${args[i]}" = "-i" ]; then
        version=${args[i+1]}
    fi
done

## Check if 32/64 bit

type=$(echo ${device:0:6})

if [ "$type" = "iPhone" ]; then
    number=$(echo ${device:6} | awk -F, '{print $1}')
    if [ "$number" -gt "5" ]; then
        is_64="true"
    fi
else
    type=$(echo ${device:0:4})
    number=$(echo ${device:4} | awk -F, '{print $1}')
    if [ "$type" = "iPad" ]; then
        if [ "$number" -gt "3" ]; then
            is_64="true"
        fi
    else
        if [ "$type" = "iPod" ]; then
            if [ "$number" -gt "5" ]; then
                is_64="true"
            fi
        fi
    fi
fi

#if [ "$is_64" = "true" ]; then
#    if [ -e "resources/dropbear_rsa_host_key" ]; then
#    echo "" &> /dev/null
#    else
#    echo "dropbear_rsa_host_key is not present. Please run the script to get one"
#    exit
#    fi
#fi

if [ "$is_64" == "true" ]; then
  echo "64-bit devices are not supported by this tool."
  exit 1
fi

## Define BoardConfig
boardcfg="$((cat firmware.json) | grep $device -A4 | grep BoardConfig | sed 's/"BoardConfig"//' | sed 's/: "//' | sed 's/",//' | xargs)"
{
if [ -z "$version" ]; then
    ipsw_link=$(curl "https://api.ipsw.me/v2.1/$device/earliest/url")
    version=$(curl "https://api.ipsw.me/v2.1/$device/earliest/info.json" | grep version | sed s+'"version": "'++ | sed s+'",'++ | xargs)
    BuildID=$(curl "https://api.ipsw.me/v2.1/$device/earliest/info.json" | grep buildid | sed s+'"buildid": "'++ | sed s+'",'++ | xargs)
else
    ipsw_link=$(curl "https://api.ipsw.me/v2.1/$device/$version/url")
    BuildID=$(curl "https://api.ipsw.me/v2.1/$device/$version/info.json" | grep buildid | sed s+'"buildid": "'++ | sed s+'",'++ | xargs)
fi
} &> /dev/null

iOS_Vers=`echo $version | awk -F. '{print $1}'`

{
## Define RootFS name
echo "$BuildID"
echo "$iOSVers"
echo "device"
RootFS="$((curl "https://www.theiphonewiki.com/wiki/Firmware_Keys/$iOS_Vers.x") | grep "$BuildID"_"" |  grep $device -m 1| awk -F_ '{print $1}' | awk -F"wiki" '{print "wiki"$2}')"
} &> /dev/null

mkdir -p SSH-Ramdisk-$device/work
cd SSH-Ramdisk-$device/work

## Get wiki keys page

echo Downloading firmware keys...

curl "https://www.theiphonewiki.com/$RootFS"_"$BuildID"_"($device)" -o temp_keys.html &> /dev/null

if [ -e "temp_keys.html" ]; then
echo Done!
else
echo Failed to download firmware keys
exit 1
fi

# Get firmware keys, components and decrypt them

../../bin/partialZipBrowser -g BuildManifest.plist $ipsw_link &> /dev/null

for i in $(awk 'BEGIN{RS="."} ; {print $1}' <<< 'iBSS.iBEC.applelogo.DeviceTree.kernelcache.RestoreRamDisk'); do
    temp_type="$(echo "$i" | tr '[:upper:]' '[:lower:]')"
    temp_type2="$i"
    
    eval "$temp_type"_iv="$((cat temp_keys.html) | grep "$temp_type-iv" | awk -F"</code>" '{print $1}' | awk -F"-iv\"\>" '{print $2}')"
    eval "$temp_type"_key="$((cat temp_keys.html) | grep "$temp_type-key" | awk -F"</code>" '{print $1}' | awk -F"$temp_type-key\"\>" '{print $2}')"
    iv=$temp_type"_iv"
    key=$temp_type"_key"
    
    if [ "$temp_type2" = "RestoreRamDisk" ]; then
        component="$((cat BuildManifest.plist) | grep -i $boardcfg -A 3000 | grep $temp_type2 -A 100| grep dmg -m 1 | sed s+'<string>'++ | sed s+'</string>'++ | xargs)"
    else
        component="$((cat BuildManifest.plist) | grep -i $boardcfg -A 3000 | grep $temp_type2 | grep string -m 1 | sed s+'<string>'++ | sed s+'</string>'++ | xargs)"
    fi
    
    echo Downloading $component...
    
    ../../bin/partialZipBrowser -g $component $ipsw_link &> /dev/null
    
    echo Done!
    
    if [ "$is_64" = "true" ]; then
        if [ "$temp_type2" = "RestoreRamDisk" ]; then
            ../../bin/img4 -i $component -o RestoreRamDisk.raw.dmg ${!iv}${!key}
            if [ "$iOS_Vers" -gt "11" ]; then
                echo Downloading $component.trustcache...
                ../../bin/partialZipBrowser -g Firmware/$component.trustcache $ipsw_link &> /dev/null
                echo Done!
            fi
        else
            ../../bin/img4 -i $temp_type2* -o $temp_type2.raw ${!iv}${!key}
        fi
    else
    
        if [ "$temp_type2" = "RestoreRamDisk" ]; then
            ../../bin/xpwntool "$component" RestoreRamDisk.dec.img3 -iv ${!iv} -k ${!key} -decrypt &> /dev/null
        else
            ../../bin/xpwntool $temp_type2* $temp_type2.dec.img3 -iv ${!iv} -k ${!key} -decrypt &> /dev/null
        fi
    fi
done

echo "Making ramdisk..."
bootargs="-v amfi=0xff cs_enforcement_disable=1 msgbuf=1048576 wdt=-1"
#{
if [ "$is_64" = "true" ]; then
    ../../bin/tsschecker -d $device -e FFFFFFFFFFFFF -l -s
    plutil -extract ApImg4Ticket xml1 -o - *.shsh2 | xmllint -xpath '/plist/data/text()' - | base64 -D > apticket.der
    ../../bin/Kernel64Patcher kernelcache.raw kcache.patched -a
    python3 ../../bin/compareFiles.py kernelcache.raw kcache.patched
    if [ "$iOS_Vers" -gt "11" ]; then
        ../../bin/img4 -i *.trustcache -o trustcache -M apticket.der
        mv trustcache ../
    fi
    ../../bin/img4 -i kernelcache.re* -o kernelcache.img4 -T rkrn -P kc.bpatch -J -M apticket.der
    mv kernelcache.img4 ../
    ../../bin/kairos iBSS.raw iBSS.patched
    ../../bin/kairos iBEC.raw iBEC.patched -b "rd=md0 -v"
    ../../bin/img4 -i iBSS.patched -o iBSS.img4 -T ibss -A -M apticket.der
    ../../bin/img4 -i iBEC.patched -o iBEC.img4 -T ibec -A -M apticket.der
    mv -v iBSS.img4 ../
    mv -v iBEC.img4 ../
    ../../bin/img4 -i applelogo.raw -o applelogo.img4 -T logo -A -M apticket.der
    mv -v applelogo.img4 ../
    ../../bin/img4 -i DeviceTree.raw -o devicetree.img4 -T rdtr -A -M apticket.der
    mv -v devicetree.img4 ../
    mkdir ramdisk_mountpoint
    dd if=/dev/zero of=./RestoreRamDisk.raw.dmg bs=1M count=100
    /sbin/mkfs.hfsplus -v RestoreRamDisk ./RestoreRamDisk.raw.dmg
    sudo mount -o loop,rw ./RestoreRamDisk.raw.dmg ramdisk_mountpoint/
    tar -xvf ../../resources/iosbinpack.tar -C .
    cd iosbinpack64
    tar -cvf ../tar.tar bin sbin usr
    cd ..
    tar -xvf tar.tar -C ramdisk_mountpoint
    mkdir libs
    curl -LO https://www.dropbox.com/s/3mbep81xx8kmvak/dependencies.tar
    tar -xvf dependencies.tar -C libs
    cp -a libs/libncurses.5.4.dylib ramdisk_mountpoint/usr/lib
    cp -a ../../resources/dropbear.plist ramdisk_mountpoint/System/Library/LaunchDaemons
    cp -a ../../resources/dropbear_rsa_host_key ramdisk_mountpoint/private/var

    if [ -e "ramdisk_mountpoint/usr/lib/libiconv.2.dylib" ]; then
    echo ""
    else
    cp -a libs/libiconv.2.dylib ramdisk_mountpoint/usr/lib
    fi
    ../../bin/ldid2 -S../../resources/dd_ent.plist ramdisk_mountpoint/bin/dd
    mkdir ramdisk_mountpoint/private/var/root
    sudo umount ramdisk_mountpoint
    ../../bin/img4 -i RestoreRamDisk.raw.dmg -o ramdisk.img4 -T rdsk -A -M apticket.der
    mv ramdisk.img4 ../
    cd ..
    rm -rf work
    cd ..
else
    ../../bin/xpwntool RestoreRamDisk.dec.img3 RestoreRamDisk.raw.dmg
    dd if=/dev/zero of=./RestoreRamDisk.raw.dmg bs=1M count=30
    /sbin/mkfs.hfsplus -v RestoreRamDisk ./RestoreRamDisk.raw.dmg
    #hdiutil resize -size 30MB RestoreRamDisk.raw.dmg
    mkdir ramdisk_mountpoint
    sudo mount -o loop,rw ./RestoreRamDisk.raw.dmg ./ramdisk_mountpoint
    tar -xvf ../../resources/ssh.tar.gz -C ramdisk_mountpoint/
    if [ "$iOS_Vers" -gt 7 ]; then
      echo "iOS 8 or later detected, patching restored_external..."
      mv ramdisk_mountpoint/usr/local/bin/restored_external ramdisk_mountpoint/usr/local/bin/restored_external.real
      cp ../../resources/setup.sh ramdisk_mountpoint/usr/local/bin/restored_external
      chmod +x ramdisk_mountpoint/usr/local/bin/restored_external
    fi
    # Try to stop auto-reboot after around 5 minutes
    mv ramdisk_mountpoint/sbin/reboot ramdisk_mountpoint/sbin/reboot_bak
    mv ramdisk_mountpoint/sbin/halt ramdisk_mountpoint/sbin/halt_bak
    # Copy custom logo
    cp ../../resources/applelogo\@2x.tga ramdisk_mountpoint/usr/share/progressui
    #hdiutil detach ramdisk_mountpoint
    sudo umount ./ramdisk_mountpoint
    ../../bin/xpwntool RestoreRamDisk.raw.dmg ramdisk.dmg -t RestoreRamDisk.dec.img3
    mv -v ramdisk.dmg ../
    ../../bin/xpwntool iBSS.dec.img3 iBSS.raw
    ../../bin/iBoot32Patcher iBSS.raw iBSS.patched -r
    ../../bin/xpwntool iBSS.patched iBSS -t iBSS.dec.img3
    mv -v iBSS ../
    ../../bin/xpwntool iBEC.dec.img3 iBEC.raw
    ../../bin/iBoot32Patcher iBEC.raw iBEC.patched -r -d -b "rd=md0 $bootargs"
    ../../bin/iBoot32Patcher iBEC.raw iBEC_boot.patched -r -d -b "$bootargs"
    ../../bin/xpwntool iBEC.patched iBEC -t iBEC.dec.img3
    ../../bin/xpwntool iBEC_boot.patched iBEC_boot -t iBEC.dec.img3
    mv -v iBEC ../
    mv -v iBEC_boot ../
    mv -v applelogo.dec.img3 ../applelogo
    mv -v DeviceTree.dec.img3 ../devicetree
    mv -v kernelcache.dec.img3 ../kernelcache
    cd ..
    rm -rf work
    cd ..
fi

#} &> ramdisk.log

echo "Done!"
