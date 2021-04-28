#!/bin/bash -x
# https://wiki.archlinux.org/index.php/installation_guide#Pre-installation

timedatectl set-ntp true

# Partitioning
ROOT_DEVICE=/dev/sda
FS_TYPE=ext4
FS_PART_NUM=3
FS_DEVICE=${ROOT_DEVICE}${FS_PART_NUM}
CONFIG_SCRIPT="/usr/local/bin/arch-config.sh"
CONFIG_SCRIPT_SHORT=$(basename ${CONFIG_SCRIPT})
FQDN=workspace
KEYMAP=us
LANGUAGE=en_US.UTF-8

VAULT_REPO_HOST=192.168.1.10
VAULT_REPO_USER=pi
VAULT_REPO_VAULTPASS=/mnt/share/home/imamura.yutaka/vault/vaultpass
VAULT_REPO_VAULTFILE=/mnt/share/home/imamura.yutaka/vault/vaultfile.yml
VAULT_DIR=".vault"

sgdisk -o ${ROOT_DEVICE}

sgdisk --new=1:0:+512M --change-name=1:"boot" --typecode=1:EF00 ${ROOT_DEVICE}
sgdisk --new=2:0:+1G --change-name=2:"swap" --typecode=2:8200 ${ROOT_DEVICE}
sgdisk --new=${FS_PART_NUM}:0:0 --change-name=${FS_PART_NUM}:"filesystem" --typecode=${FS_PART_NUM}:8300 ${ROOT_DEVICE}
sgdisk -p ${ROOT_DEVICE}
lsblk

# Formatting
mkfs.vfat -F32 ${ROOT_DEVICE}1
mkswap ${ROOT_DEVICE}2
swapon ${ROOT_DEVICE}2
mkfs.${FS_TYPE} "${FS_DEVICE}"
mount "${FS_DEVICE}" /mnt
mkdir /mnt/boot
mount ${ROOT_DEVICE}1 /mnt/boot

# Installation
pacstrap /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

cat <<-EOF > "/mnt${CONFIG_SCRIPT}"
  set -x
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
  #pacman -S --noconfirm dhcpd
  #/usr/bin/systemctl enable dhcpcd@eth0.service

  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring sshd.."
  #/usr/bin/sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
  pacman -S --noconfirm openssh
  /usr/bin/systemctl enable sshd.service
  # Workaround for https://bugs.archlinux.org/task/58355 which prevents sshd to accept connections after reboot
  #echo ">>>> ${CONFIG_SCRIPT_SHORT}: Adding workaround for sshd connection issue after reboot.."
  #/usr/bin/pacman -S --noconfirm rng-tools
  #/usr/bin/systemctl enable rngd

  # Main-user configuration
  pacman -S --noconfirm sudo
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Creating main user.."
  /usr/bin/useradd --comment 'Main User' --password $(/usr/bin/openssl passwd -crypt "${MAIN_PASSWORD}") --create-home --user-group "${MAIN_USER}"
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring sudo.."
  echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/00_${MAIN_USER}
  echo "${MAIN_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/00_${MAIN_USER}
  /usr/bin/chmod 0640 /etc/sudoers.d/00_${MAIN_USER}
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring ssh access for ${MAIN_USER}.."
  /usr/bin/install --directory --owner=${MAIN_USER} --group=${MAIN_USER} --mode=0700 /home/${MAIN_USER}/.ssh
  echo "${SSH_PUBLIC_KEY}" > /home/${MAIN_USER}/.ssh/authorized_keys
  /usr/bin/chown ${MAIN_USER}:${MAIN_USER} /home/${MAIN_USER}/.ssh/authorized_keys
  /usr/bin/chmod 0600 /home/${MAIN_USER}/.ssh/authorized_keys
  sudo mv /id_rsa /home/${MAIN_USER}/.ssh/id_rsa
  sudo chown ${MAIN_USER}:${MAIN_USER} /home/${MAIN_USER}/.ssh/id_rsa
  sudo chmod 600 /home/${MAIN_USER}/.ssh/id_rsa

  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  hwclock --systohc
  
  echo "workspace" > /etc/hostname
  echo "127.0.1.1	workspace.localdomain	workspace" >> /etc/hosts 

  pacman -S --noconfirm grub efibootmgr 
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=boot --removable
  grub-mkconfig -o /boot/grub/grub.cfg

  ls -l /boot/EFI/boot/bootx64.efi

  systemctl enable systemd-networkd.service
  systemctl enable systemd-resolved.service
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

  echo '[Match]' > /etc/systemd/network/20-wired.network
  echo 'Name=en*' >> /etc/systemd/network/20-wired.network
  echo '' >> /etc/systemd/network/20-wired.network
  echo '[Network]' >> /etc/systemd/network/20-wired.network
  echo 'DHCP=yes' >> /etc/systemd/network/20-wired.network
  cat /etc/systemd/network/20-wired.network

  pacman -S --noconfirm ansible git

  sudo -u ${MAIN_USER} -H sh -x <<EOS
    mkdir -p "/home/${MAIN_USER}/${VAULT_DIR}"
    chmod 700 "/home/${MAIN_USER}/${VAULT_DIR}"
    scp -i /home/${MAIN_USER}/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${VAULT_REPO_USER}@${VAULT_REPO_HOST}:${VAULT_REPO_VAULTPASS} "/home/${MAIN_USER}/${VAULT_DIR}/vaultpass"
    chmod 600 "/home/${MAIN_USER}/${VAULT_DIR}/vaultpass"
    GIT_SSH_COMMAND="ssh -i /home/${MAIN_USER}/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git clone git@github.com:utky/ansible-workstation.git "/home/${MAIN_USER}/ansible-workstation"
    scp -i /home/${MAIN_USER}/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${VAULT_REPO_USER}@${VAULT_REPO_HOST}:${VAULT_REPO_VAULTFILE} "/home/${MAIN_USER}/ansible-workstation/group_vars/all/vaultfile.yml"
    cd /home/${MAIN_USER}/ansible-workstation
    ansible-playbook -i inventory.yaml workspace.yml
  EOS
EOF

chmod 755 /mnt${CONFIG_SCRIPT}
cp  /home/${MAIN_USER}/.ssh/id_rsa /mnt/id_rsa
arch-chroot /mnt ${CONFIG_SCRIPT}

echo ">>>> install-base.sh: Completing installation.."
/usr/bin/sleep 3
/usr/bin/umount -R /mnt


