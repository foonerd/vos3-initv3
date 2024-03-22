#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for x86 devices

# Base system
BASE="Debian"
ARCH="i386"
BUILD="x86"

### Build image with initramfs debug info?
DEBUG_IMAGE="no"
### Device information
DEVICENAME="x86"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="x86"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="http://github.com/volumio/platform-${DEVICEFAMILY}"

### What features do we want to target
# TODO: Not fully implemented
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes
KIOSKMODE=yes

## Partition info
BOOT_START=1
BOOT_END=180
IMAGE_END=3800
BOOT_TYPE=gpt        # msdos or gpt
BOOT_USE_UUID=yes    # Add UUID to fstab

## initramfs info
INIT_TYPE="initv3"   # init{v3|x86}
PLYMOUTH_THEME="volumio-logo"
# Modules that will be added to intramfs
MODULES=("overlay" "squashfs"
  # USB/FS modules
  "usbcore" "usb_common" "mmc_core" "mmc_block" "nvme_core" "nvme" "sdhci" "sdhci_pci" "sdhci_acpi"
  "ehci_pci" "ohci_pci" "uhci_hcd" "ehci_hcd" "xhci_hcd" "ohci_hcd" "usbhid" "hid_cherry" "hid_generic"
  "hid" "nls_cp437" "nls_utf8" "vfat" "fuse" "uas"
  # nls_ascii might be needed on some kernels (debian upstream for example)
  # Plymouth modules
  "intel_agp" "drm" "i915 modeset=1" "nouveau modeset=1" "radeon modeset=1"
  # Ata modules
  "acard-ahci" "ahci" "ata_generic" "ata_piix" "libahci" "libata"
  "pata_ali" "pata_amd" "pata_artop" "pata_atiixp" "pata_atp867x" "pata_cmd64x" "pata_cs5520" "pata_cs5530"
  "pata_cs5535" "pata_cs5536" "pata_efar" "pata_hpt366" "pata_hpt37x" "pata_isapnp" "pata_it8213"
  "pata_it821x" "pata_jmicron" "pata_legacy" "pata_marvell" "pata_mpiix" "pata_netcell" "pata_ninja32"
  "pata_ns87410" "pata_ns87415" "pata_oldpiix" "pata_opti" "pata_pcmcia" "pata_pdc2027x"
  "pata_pdc202xx_old" "pata_piccolo" "pata_rdc" "pata_rz1000" "pata_sc1200" "pata_sch" "pata_serverworks"
  "pata_sil680" "pata_sis" "pata_triflex" "pata_via" "pdc_adma" "sata_mv" "sata_nv" "sata_promise"
  "sata_qstor" "sata_sil24" "sata_sil" "sata_sis" "sata_svw" "sata_sx4" "ata_uli" "sata_via" "sata_vsc"
)
# Packages that will be installed
PACKAGES=()

# Kernel selection
# This will be expanded as a glob, you can be as specific or vague as required
# KERNEL_VERSION=5.10
# KERNEL_VERSION=6.1
KERNEL_VERSION=6.6

# Firmware selection
# FIRMWARE_VERSION="20211027"
# FIRMWARE_VERSION="20221216"
FIRMWARE_VERSION="20230804"
  
### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"
  log "Copying kernel files"
  pkg_root="${PLTDIR}/packages-buster"

  cp "${pkg_root}"/linux-image-${KERNEL_VERSION}*_${ARCH}.deb "${ROOTFSMNT}"

  log "Copying header files, when present"
  if [ -f "${pkg_root}"/linux-headers-${KERNEL_VERSION}*_${ARCH}.deb ]; then
    cp "${pkg_root}"/linux-headers-${KERNEL_VERSION}*_${ARCH}.deb "${ROOTFSMNT}"
  fi

  log "Copying the latest firmware into /lib/firmware"
  log "Unpacking the tar file firmware-${FIRMWARE_VERSION}"
  tar xfJ "${pkg_root}"/firmware-${FIRMWARE_VERSION}.tar.xz -C "${ROOTFSMNT}"

  #log "Copying Alsa Use Case Manager files"
  #With Buster we seem to have a default install, but it is not complete. Add the missing codecs.
  #(UCM2, which is complete, does not work with Buster's Alsa version but will with Bullseye)
  cp -R "${pkg_root}"/UCM/* "${ROOTFSMNT}"/usr/share/alsa/ucm/

  mkdir -p "${ROOTFSMNT}"/usr/local/bin/
  declare -A CustomScripts=(
    [bytcr_init.sh]="bytcr-init/bytcr-init.sh"
    [jackdetect.sh]="bytcr-init/jackdetect.sh"
    [volumio_hda_intel_tweak.sh]="hda-intel-tweaks/volumio_hda_intel_tweak.sh"
    [x86Installer.sh]="x86Installer/x86Installer.sh"
  )
  #TODO: not checked with other Intel SST bytrt/cht audio boards yet, needs more input
  #      to be added to the snd_hda_audio tweaks (see below)
  log "Adding ${#CustomScripts[@]} custom scripts to /usr/local/bin: " "" "${CustomScripts[@]}"
  for script in "${!CustomScripts[@]}"; do
    cp "${pkg_root}/${CustomScripts[$script]}" "${ROOTFSMNT}"/usr/local/bin/"${script}"
    chmod +x "${ROOTFSMNT}"/usr/local/bin/"${script}"
  done

  log "Creating efi folders"
  mkdir -p "${ROOTFSMNT}"/boot/efi
  mkdir -p "${ROOTFSMNT}"/boot/efi/EFI/debian
  mkdir -p "${ROOTFSMNT}"/boot/efi/BOOT/
  
  log "Copying bootloaders and grub configuration template"
  mkdir -p "${ROOTFSMNT}"/boot/grub
  cp "${pkg_root}"/efi/BOOT/grub.cfg "${ROOTFSMNT}"/boot/efi/BOOT/grub.tmpl
  cp "${pkg_root}"/efi/BOOT/BOOTIA32.EFI "${ROOTFSMNT}"/boot/efi/BOOT/BOOTIA32.EFI
  cp "${pkg_root}"/efi/BOOT/BOOTX64.EFI "${ROOTFSMNT}"/boot/efi/BOOT/BOOTX64.EFI

  log "Copying current partition data for use in runtime fast 'installToDisk'"
  cat <<-EOF >"${ROOTFSMNT}/boot/partconfig.json"
{
  "params":[
  {"name":"boot_start","value":"$BOOT_START"},
  {"name":"boot_end","value":"$BOOT_END"},
  {"name":"volumio_end","value":"$IMAGE_END"},
  {"name":"boot_type","value":"$BOOT_TYPE"}
  ]
}
EOF

  cp -dR volumio/usr/share/plymouth/themes/${PLYMOUTH_THEME} ${ROOTFSMNT}/usr/share/plymouth/themes/${PLYMOUTH_THEME}

  # Headphone detect currently only for atom z8350 with rt5640 codec
  # Evaluate additional requirements when they arrive
  log "Copying acpi event handing for headphone jack detect (z8350 with rt5640 only)"
  cp "${pkg_root}"/bytcr-init/jackdetect "${ROOTFSMNT}"/etc/acpi/events
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  log "Copying the Syslinux boot sector"
  dd conv=notrunc bs=440 count=1 if="${ROOTFSMNT}"/usr/lib/syslinux/mbr/gptmbr.bin of="${LOOP_DEV}"
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  log "Running device_image_tweaks" "ext"

  log "Some wireless network drivers (e.g. for Marvell chipsets) create device 'mlan0'"
  log "Rename these to 'wlan0' using a systemd link"
  cat <<-EOF > "${ROOTFSMNT}/etc/systemd/network/10-rename-mlan0.link"
[Match]
Type=wlan
Driver=mwifiex_sdio
OriginalName=mlan0

[Link]
Name=wlan0
EOF

  log "Add service to set sane defaults for baytrail/cherrytrail and HDA soundcards"
  cat <<-EOF >"${ROOTFSMNT}/usr/local/bin/soundcard-init.sh"
#!/bin/sh -e
/usr/local/bin/bytcr_init.sh
/usr/local/bin/volumio_hda_intel_tweak.sh
exit 0
EOF
  chmod +x "${ROOTFSMNT}/usr/local/bin/soundcard-init.sh"

  cat <<-EOF >"${ROOTFSMNT}/lib/systemd/system/soundcard-init.service"
[Unit]
Description = Intel SST and HDA soundcard init service
After=volumio.service

[Service]
Type=simple
ExecStart=/usr/local/bin/soundcard-init.sh

[Install]
WantedBy=multi-user.target
EOF
  ln -s "${ROOTFSMNT}/lib/systemd/system/soundcard-init.service" "${ROOTFSMNT}/etc/systemd/system/multi-user.target.wants/soundcard-init.service"

  #log "Adding ACPID Service to Startup"
  #ln -s "${ROOTFSMNT}/lib/systemd/system/acpid.service" "${ROOTFSMNT}/etc/systemd/system/multi-user.target.wants/acpid.service"

  log "Blacklisting PC speaker"
  cat <<-EOF >>"${ROOTFSMNT}/etc/modprobe.d/blacklist.conf"
blacklist snd_pcsp
blacklist pcspkr
EOF

  log "Copying custom initramfs script functions"
  [ -d ${ROOTFSMNT}/root/scripts ] || mkdir ${ROOTFSMNT}/root/scripts
  cp "${SRC}/scripts/initramfs/custom/x86/custom-functions" ${ROOTFSMNT}/root/scripts
}

# Will be run in chroot (before other things)
device_chroot_tweaks() {
  #log "Running device_image_tweaks" "ext"
  :
}

# Will be run in chroot - Pre initramfs
# TODO Try and streamline this!
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
  log "Preparing kernel stuff" "info"

  log "Installing the kernel"
  # Exact kernel version not known
  # Not brilliant, but safe enough as platform repo *should* have only a single kernel package
  # Confirm anyway
  dpkg-deb -R linux-image-*_"${ARCH}".deb ./
  rm -r /DEBIAN
  rm -r /etc/kernel
  rm -r /usr/share/doc/linux-image*
  rm linux-image-*_"${ARCH}".deb

  log "Installing the headers, when present"
  if [ -f linux-headers-*_"${ARCH}".deb ]; then
    mkdir /tmpheaders
    dpkg-deb -R linux-headers-*_"${ARCH}".deb ./tmpheaders
    cp -R /tmpheaders/usr/src/linux-headers*/include /usr/src
    rm -r /tmpheaders
    rm linux-headers-*_"${ARCH}".deb
  fi

  log "Change linux kernel image name to 'vmlinuz'"
  # Rename linux kernel to a fixed name, like we do for any other platform.
  # We only have one and we should not start multiple versions.
  # - our OTA update can't currently handle that and it blows up size of /boot and /lib.
  # This rename is safe, because we have only one vmlinuz* in /boot
  mv /boot/vmlinuz* /boot/vmlinuz

  log "Preparing BIOS" "info"
  log "Installing Syslinux Legacy BIOS at ${BOOT_PART-?BOOT_PART is not known}"
  syslinux -v
  syslinux "${BOOT_PART}"

  log "Preparing boot configurations" "info"



  # Build up the base parameters
  kernel_params=(
    # Bios stuff
    "biosdevname=0"
    # Boot screen stuff
    "splash" "plymouth.ignore-serial-consoles"
    # Boot params
    "imgpart=UUID=%%IMGPART%%" "bootpart=UUID=%%BOOTPART%%" "datapart=UUID=%%DATAPART%%"
    "hwdevice=x86"
    # Image params
    "imgfile=/volumio_current.sqsh"
    # Disable linux logo during boot
    "logo.nologo"
    # Disable cursor
    "vt.global_cursor_default=0"
    # backlight control (notebooks)
    "acpi_backlight=vendor"
  )
  
  KERNEL_LOGLEVEL="loglevel=0" # Default to KERN_EMERG, also recommended debug image
  DISABLE_PN="net.ifnames=0"   # For legacy ifnames in buster
  kernel_params+=("${DISABLE_PN}")
  
  if [ "${DEBUG_IMAGE}" == "yes" ]; then
    log "Creating debug image" "wrn"
    # Set breakpoints, loglevel, debug, kernel buffer output etc.
    kernel_params+=("break=" "${KERNEL_LOGLEVEL}" "debug" "use_kmsg=yes") 
    log "Enabling ssh on boot"
    touch /boot/ssh
  else
    # No output (use "quiet loglevel=0" and in that order!)
    kernel_params+=("quiet ${KERNEL_LOGLEVEL} use_kmsg=no initramfs.clear") 
  fi
 

  log "Setting ${#kernel_params[@]} Kernel params:" "" "${kernel_params[*]}"

  log "Setting up syslinux and grub configs" "info"
  log "Creating run-time template for syslinux config"
  # Create a template for init to use later in `update_config_UUIDs`
  cat <<-EOF >/boot/syslinux.tmpl
DEFAULT volumio
LABEL volumio
	SAY Booting Volumio Audiophile Music Player...
  LINUX vmlinuz
  APPEND ${kernel_params[@]}
  INITRD volumio.initrd
EOF

  log "Creating syslinux.cfg from syslinux template"
  sed "s/%%IMGPART%%/${UUID_IMG}/g; s/%%BOOTPART%%/${UUID_BOOT}/g; s/%%DATAPART%%/${UUID_DATA}/g" /boot/syslinux.tmpl >/boot/syslinux.cfg

  log "Setting up Grub configuration"
  grub_tmpl=/boot/efi/BOOT/grub.tmpl
  grub_cfg=/boot/efi/BOOT/grub.cfg
  log "Inserting our kernel parameters to grub.tmpl"
  # Use a different delimiter as we might have some `/` paths
  sed -i "s|%%CMDLINE_LINUX%%|""${kernel_params[*]}""|g" ${grub_tmpl}

  log "Creating grub.cfg from grub template"
  cp ${grub_tmpl} ${grub_cfg}

  log "Inserting root and boot partition UUIDs (building the boot cmdline used in initramfs)"
  # Opting for finding partitions by-UUID
  sed -i "s/%%IMGPART%%/${UUID_IMG}/g" ${grub_cfg}
  sed -i "s/%%BOOTPART%%/${UUID_BOOT}/g" ${grub_cfg}
  sed -i "s/%%DATAPART%%/${UUID_DATA}/g" ${grub_cfg}

  log "Finished setting up boot config" "okay"

  log "Creating fstab template to be used in initrd"
  sed "s/^UUID=${UUID_BOOT}/%%BOOTPART%%/g" /etc/fstab >/etc/fstab.tmpl

  log "Setting plymouth theme to ${PLYMOUTH_THEME}"
 
  plymouth-set-default-theme -R ${PLYMOUTH_THEME}
  plymouth-set-default-theme

  
  log "Notebook-specific: ignore 'cover closed' event"
  sed -i "s/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g" /etc/systemd/logind.conf
  sed -i "s/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/g" /etc/systemd/logind.conf

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Cleaning up /boot"
  log "Removing System.map" "$(ls -lh --block-size=M /boot/System.map-*)"
  rm /boot/System.map-*
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
  # log "Running device_image_tweaks_post" "ext"
  :
}
