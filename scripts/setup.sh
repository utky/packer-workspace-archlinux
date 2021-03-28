#!/bin/bash -xe
# https://wiki.archlinux.org/index.php/installation_guide#Pre-installation

timedatectl set-ntp true

# Partitioning
ROOT_DEVICE=/dev/sda
FS_PART_NUM=3
FS_DEVICE=${ROOT_DEVICE}${FS_PART_NUM}
VG_NAME="primary"
LV_NAME="root"
LV_DEVICE="/dev/${VG_NAME}/${LV_NAME}"
CONFIG_SCRIPT="/usr/local/bin/arch-config.sh"
CONFIG_SCRIPT_SHORT=$(basename ${CONFIG_SCRIPT})
FQDN=workspace
KEYMAP=us
LANGUAGE=en_US.UTF-8
DATA_DISK_UUID=${DATA_DISK_UUID:-$DATA_DISK_UUID}
MAIN_USER=ilyaletre

sgdisk -o ${ROOT_DEVICE}

sgdisk --new=1:0:+512M --change-name=1:"boot" --typecode=1:EF00 ${ROOT_DEVICE}
sgdisk --new=2:0:+1G --change-name=2:"swap" --typecode=2:8200 ${ROOT_DEVICE}
sgdisk --new=${FS_PART_NUM}:0:0 --change-name=${FS_PART_NUM}:"filesystem" --typecode=${FS_PART_NUM}:8300 ${ROOT_DEVICE}
sgdisk -p ${ROOT_DEVICE}

# LVM provisioning
pvcreate "${FS_DEVICE}"
pvs

vgcreate "${VG_NAME}" "${FS_DEVICE}"
vgs

lvcreate --extents +100%FREE "${VG_NAME}" --name "${LV_NAME}"

lsblk

ls -l /dev/disk/by-uuid

# Formatting
mkfs.vfat -F32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mkfs.ext4 "${LV_DEVICE}"
mount "${LV_DEVICE}" /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir -p /mnt/mnt/data
mount --uuid "${DATA_DISK_UUID}" /mnt/mnt/data

# Installation
pacstrap /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

cat <<-EOF > "/mnt${CONFIG_SCRIPT}"
  echo ">>>> ${CONFIG_SCRIPT}: Configuring hostname, timezone, and keymap.."
  echo '${FQDN}' > /etc/hostname
  /usr/bin/ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
  echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring locale.."
  /usr/bin/sed -i 's/#${LANGUAGE}/${LANGUAGE}/' /etc/locale.gen
  /usr/bin/locale-gen
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Creating initramfs.."
  /usr/bin/mkinitcpio -p linux

  #echo ">>>> ${CONFIG_SCRIPT_SHORT}: Setting root pasword.."
  #/usr/bin/usermod --password ${PASSWORD} root

  #echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring network.."
  # Disable systemd Predictable Network Interface Names and revert to traditional interface names
  # https://wiki.archlinux.org/index.php/Network_configuration#Revert_to_traditional_interface_names
  #/usr/bin/ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
  #/usr/bin/systemctl enable dhcpcd@eth0.service

  #echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring sshd.."
  #/usr/bin/sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
  #/usr/bin/systemctl enable sshd.service
  # Workaround for https://bugs.archlinux.org/task/58355 which prevents sshd to accept connections after reboot

  #echo ">>>> ${CONFIG_SCRIPT_SHORT}: Adding workaround for sshd connection issue after reboot.."
  #/usr/bin/pacman -S --noconfirm rng-tools
  #/usr/bin/systemctl enable rngd

  # Vagrant-specific configuration
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Creating main user.."

  /usr/bin/useradd --password ${PASSWORD} --comment 'Main User' --create-home --user-group "${MAIN_USER}"
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring sudo.."
  echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/10_${MAIN_USER}
  echo "${MAIN_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/10_${MAIN_USER}
  /usr/bin/chmod 0440 /etc/sudoers.d/10_${MAIN_USER}
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring ssh access for ${MAIN_USER}.."
  /usr/bin/install --directory --owner=${MAIN_USER} --group=${MAIN_USER} --mode=0700 /home/${MAIN_USER}/.ssh
  /usr/bin/curl --output /home/${MAIN_USER}/.ssh/authorized_keys --location https://github.com/utky.keys
  /usr/bin/chown ${MAIN_USER}:${MAIN_USER} /home/${MAIN_USER}/.ssh/authorized_keys
  /usr/bin/chmod 0600 /home/${MAIN_USER}/.ssh/authorized_keys

  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  hwclock --systohc
  
  echo "workspace" > /etc/hostname
  echo "127.0.1.1	workspace.localdomain	workspace" >> /etc/hosts 
  mkinitcpio -P
  
  grub-install --target=x86_64-efi --efi-directory=boot --bootloader-id=grub
  grub-mkconfig -o /boot/grub/grub.cfg
EOF

arch-chroot /mnt /mnt${CONFIG_SCRIPT}

systemctl reboot
