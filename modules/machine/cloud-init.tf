# Some random password to assign to the virtual machine's user
resource "random_password" "password" {
  length  = 32
  special = false
}

# Assemble the cloud-init iso
resource "libvirt_cloudinit_disk" "cloudinit" {
  name = "${var.machine_name}-cloudinit.iso"
  pool = var.libvirt_resource_pool_name

  user_data = format("#cloud-config\n%s", jsonencode({
    hostname         = var.machine_name
    fqdn             = join(".", [var.machine_name, var.machine_dns_domain])
    manage_etc_hosts = true

    users = [{
      name                = var.machine_user
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      home                = "/home/${var.machine_user}"
      shell               = "/bin/sh"
      lock_passwd         = true
      ssh-authorized-keys = [var.machine_ssh_public_key]
    }]

    ssh_pwauth   = false
    disable_root = true

    chpasswd = {
      list   = join(":", [var.machine_user, random_password.password.result])
      expire = false
    }

    runcmd = [
      # https://github.com/k0sproject/k0sctl/issues/334#issuecomment-1047694966
      ["sh", "-c", "echo PubkeyAcceptedAlgorithms +ssh-rsa >> /etc/ssh/sshd_config"],
      ["/etc/init.d/sshd", "restart"],
    ]

    # written to /var/log/cloud-init-output.log
    final_message = "The system is finally up, after $UPTIME seconds"
  }))

  network_config = jsonencode({
    version   = 2
    ethernets = { eth0 = { dhcp4 = true, dhcp6 = true, }, }
  })
}
