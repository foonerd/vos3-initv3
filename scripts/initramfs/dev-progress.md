
# Current compatible

|Board|initv3|plymouth|
|---|---|---|
x86| yes|yes
RPi| yes|yes
(odroidn2) |yes| untested 
Nanopi Neo2|untested|no (no video-out)
Nanopi Neo3|untested|no (video-out)
|||Add new boards as we proceed testing

# Recipes modifications

## Environment variables
INIT_TYPE=initv3  
PLYMOUTH_THEME="volumio-logo"

## Add initv3 custom functions
Some devices use initv3 custom functions, eg. x86 and pi (more could follow).

|Board|init script addition in function "device_image_tweaks()|
|---|---|
||```log "Copying custom initramfs script functions"```
||```[ -d ${ROOTFSMNT}/root/scripts ] \|\| mkdir ${ROOTFSMNT}/root/scripts```
||followed by device-specific custom functions
|x86|```cp "${SRC}/scripts/initramfs/custom/x86/custom-functions" ${ROOTFSMNT}/root/scripts```
|pi|```cp "${SRC}/scripts/initramfs/custom/pi/custom-functions" ${ROOTFSMNT}/root/scripts```

## Default kernel parameters

|Support type|Parameter (group)
|---|---|
|plymouth default|"splash" "plymouth.ignore-serial-consoles" "initramfs.clear" (preferred order)
|initv3 default|"quiet loglevel=0"
|initv3 default|"use_kmsg=no"
|initv3 default|"hwdevice=```${DEVICE}```" (nice-to-have, currently unused. Perhaps initv3 should read it from ```/etc/os-release``` like it does ```${VOLUMIO_VERSION}```)
||Add new boards as we proceed with testing||