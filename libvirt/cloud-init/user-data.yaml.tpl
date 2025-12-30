#cloud-config
# Cloud-init user-data template for voip-stack VMs

hostname: ${HOSTNAME}
fqdn: ${HOSTNAME}.local
manage_etc_hosts: true

users:
  - name: debian
    gecos: Debian User
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin, sudo
    shell: /bin/bash
    lock_passwd: false
    # Password: debian (hashed)
    passwd: $6$rounds=4096$xyz$LnbU3Lg3W1PpvQqYBfWmFKqMzR7d1hLfKUxqYeJQb0VXLA3mPq9Bx5RqPgaYMHfJsYwG1JfNJqHfMG1cZ1lJP1
    ssh_authorized_keys:
      - ${SSH_PUBLIC_KEY}

# Enable password authentication for SSH (can disable after keys are set up)
ssh_pwauth: true

# Install essential packages
packages:
  - qemu-guest-agent
  - vim
  - curl
  - wget
  - net-tools
  - dnsutils
  - htop
  - sudo

# Enable and start qemu-guest-agent
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - echo "Cloud-init complete for ${HOSTNAME}" > /var/log/cloud-init-complete.log

# Write files
write_files:
  - path: /etc/sudoers.d/90-cloud-init-users
    content: |
      debian ALL=(ALL) NOPASSWD:ALL
    permissions: '0440'

# Final message
final_message: |
  cloud-init complete for ${HOSTNAME}
  Version: $version
  Datasource: $datasource
  Uptime: $uptime
