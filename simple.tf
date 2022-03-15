# variables that can be overriden
variable "hostname" { default = "simple" }
variable "domain" { default = "example.com" }
variable "memoryMB" { default = 1024 * 1 }
variable "cpu" { default = 1 }

# instance the provider
provider "libvirt" {
  uri = "qemu:///system"
}

resource "random_password" "password" {
  length = 32
}

# declare the alpine base image
resource "libvirt_volume" "os_image" {
  name   = "${var.hostname}-os_image"
  pool   = "default"
  source = "alpine.qcow2"
  format = "qcow2"
}

# Use CloudInit ISO to add ssh-key to the instance
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "${var.hostname}-commoninit.iso"
  pool           = "default"
  user_data      = data.template_file.cloud_init_user_data.rendered
  network_config = data.template_file.cloud_init_network_config.rendered
}

data "template_file" "cloud_init_user_data" {
  template = file("${path.module}/cloud-init-user-data.yaml.tpl")
  vars = {
    hostname = var.hostname
    fqdn     = "${var.hostname}.${var.domain}"
    password = random_password.password.result
  }
}

data "template_file" "cloud_init_network_config" {
  template = file("${path.module}/cloud-init-network-config.yaml.tpl")
}


# Create the machine
resource "libvirt_domain" "domain-k0s" {
  name   = var.hostname
  memory = var.memoryMB
  vcpu   = var.cpu

  disk {
    volume_id = libvirt_volume.os_image.id
  }
  network_interface {
    network_name = "default"
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id
}

output "ips" {
  # show IP, run 'terraform refresh' if not populated
  value = libvirt_domain.domain-k0s.*.network_interface.0.addresses
}
