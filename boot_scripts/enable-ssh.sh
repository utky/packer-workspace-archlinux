#!/usr/bin/env bash
set -x

USERNAME=$1
PASSWORD=$2
PUBLIC_KEY=$3

ENCRYPTED_PASSWORD=$(/usr/bin/openssl passwd -crypt "$PASSWORD")
/usr/bin/useradd --password ${ENCRYPTED_PASSWORD} --create-home --user-group $USERNAME
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
echo "${PUBLIC_KEY}" >> /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/10_${USERNAME}
echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/10_${USERNAME}
/usr/bin/chmod 0440 /etc/sudoers.d/10_${USERNAME}
/usr/bin/systemctl start sshd.service
