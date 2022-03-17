provider "libvirt" {
  uri = var.libvirt_provider_uri
}

locals {
  libvirt_resource_pool_name = "${var.libvirt_resource_name_prefix}resource-pool"
}

# Creates a resource pool for virtual machine volumes
resource "libvirt_pool" "resource_pool" {
  name = local.libvirt_resource_pool_name

  type = "dir"
  path = pathexpand("${trimsuffix(var.libvirt_resource_pool_location, "/")}/${local.libvirt_resource_pool_name}")
}

resource "libvirt_network" "network" {
  name = "${var.libvirt_resource_name_prefix}network"

  mode      = "nat"
  autostart = true
  addresses = [var.libvirt_network_cidr]

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
  name = "${var.libvirt_resource_name_prefix}-base-volume"
  pool = libvirt_pool.resource_pool.name

  source = pathexpand(var.machine_image_source)
}

module "controllers" {
  source = "./modules/machine"

  count = var.controller_num_nodes

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume_id     = libvirt_volume.base.id
  libvirt_network_id         = libvirt_network.network.id

  machine_name     = "${var.libvirt_resource_name_prefix}controller-${count.index}"
  machine_user     = var.machine_user
  machine_num_cpus = var.controller_num_cpus
  machine_memory   = var.controller_memory
}
