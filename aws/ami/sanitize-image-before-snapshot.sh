#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

echo "### Sanitize the image before creating the AMI snapshot"

# Disable every form of password-based SSH authentication and direct root login.
sudo mkdir -p /etc/ssh/sshd_config.d
printf '%s\n' \
  'PasswordAuthentication no' \
  'KbdInteractiveAuthentication no' \
  'PermitRootLogin no' |
  sudo tee /etc/ssh/sshd_config.d/99-querypie-marketplace.conf >/dev/null
sudo passwd --lock root
sudo sshd -t

# Build-time keys must never be included in an image delivered to customers.
sudo find /root /home -xdev -type f -name authorized_keys -delete
sudo find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*_key*' -delete

# Force cloud-init and systemd to initialize per-instance state on the next boot.
# Amazon Linux 2023's cloud-init does not expose the --machine-id flag, so
# reproduce its documented systemd behavior explicitly.
sudo cloud-init clean --logs
printf 'uninitialized\n' | sudo tee /etc/machine-id >/dev/null
sudo rm -f /var/lib/dbus/machine-id
sudo rm -f /var/lib/systemd/random-seed

# Remove build caches, temporary files, histories, and logs.
sudo dnf clean all
sudo find /tmp /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
sudo find /root /home -xdev -type f -name '.*history' -delete
sudo find /var/log -type f -exec truncate -s 0 {} +

if sudo find /root /home -xdev -type f -name authorized_keys -size +0c | grep -q .; then
  echo >&2 "ERROR: A non-empty SSH authorized_keys file remains in the image."
  exit 1
fi

sync
echo "### Image sanitization completed"
