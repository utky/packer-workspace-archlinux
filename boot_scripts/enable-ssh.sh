#!/usr/bin/env bash
set -x

PASSWORD=$(/usr/bin/openssl passwd -crypt "$1")

# Vagrant-specific configuration
/usr/bin/useradd --password ${PASSWORD} --comment 'Packer User' --create-home --user-group packer
echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/10_packer
echo 'packer ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/10_packer
/usr/bin/chmod 0440 /etc/sudoers.d/10_packer
/usr/bin/systemctl start sshd.service
