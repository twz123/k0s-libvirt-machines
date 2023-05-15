provider "libvirt" {
  uri = var.libvirt_provider_uri
}

locals {
  libvirt_resource_pool_name = "${var.resource_name_prefix}resource-pool"
}

resource "tls_private_key" "ssh" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${var.profile_folder}/ssh-private-key.pem"
  file_permission = "0400"
}

# Creates a resource pool for virtual machine volumes
resource "libvirt_pool" "resource_pool" {
  name = local.libvirt_resource_pool_name

  type = "dir"
  path = pathexpand("${trimsuffix(var.libvirt_resource_pool_location, "/")}/${local.libvirt_resource_pool_name}")
}

resource "libvirt_network" "network" {
  name = "${var.resource_name_prefix}network"

  mode      = "nat"
  autostart = true
  addresses = [for addr in [
    var.libvirt_network_ipv4_cidr,
    var.libvirt_network_ipv6_cidr,
    ] : addr if addr != null
  ]

  domain = var.libvirt_network_dns_domain == null ? "${var.resource_name_prefix}net.local" : var.libvirt_network_dns_domain

  dns {
    enabled    = true
    local_only = false
  }

  dhcp {
    enabled = true
  }
}

# Creates base OS image for the machines
resource "libvirt_volume" "base" {
  name = "${var.resource_name_prefix}base-volume"
  pool = libvirt_pool.resource_pool.name

  source = pathexpand(var.machine_image_source)
}
