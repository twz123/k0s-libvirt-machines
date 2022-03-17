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
    fqdn             = var.machine_name
    manage_etc_hosts = true

    users = [{
      name                = var.machine_user
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      home                = "/home/${var.machine_user}"
      shell               = "/bin/sh"
      lock_passwd         = true
      ssh-authorized-keys = [file("id_rsa.pub")]
    }]

    ssh_pwauth   = false
    disable_root = true

    chpasswd = {
      list   = join(":", [var.machine_user, random_password.password.result])
      expire = false
    }

    # written to /var/log/cloud-init-output.log
    final_message = "The system is finally up, after $UPTIME seconds"
  }))

  network_config = jsonencode({
    version   = 2
    ethernets = { eth0 = { dhcp4 = true, }, }
  })
}
