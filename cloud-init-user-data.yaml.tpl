#cloud-config

hostname: ${hostname}
fqdn: ${fqdn}
manage_etc_hosts: true

users:
- name: k0s
  sudo: ALL=(ALL) NOPASSWD:ALL
  home: /home/k0s
  shell: /bin/sh
  lock_passwd: true
  ssh-authorized-keys:
  - ${file("id_rsa.pub")}

ssh_pwauth: false
disable_root: true

chpasswd:
  list: |
     k0s:${password}
  expire: False

# written to /var/log/cloud-init-output.log
final_message: "The system is finally up, after $UPTIME seconds"

