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

module "controllers" {
  source = "./modules/machine"

  count = var.controller_num_nodes

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume_id     = libvirt_volume.base.id
  libvirt_network_id         = libvirt_network.network.id

  machine_name       = "${var.resource_name_prefix}controller-${count.index}"
  machine_dns_domain = libvirt_network.network.domain

  machine_num_cpus = var.controller_num_cpus
  machine_memory   = var.controller_memory

  machine_user           = var.machine_user
  machine_ssh_public_key = chomp(tls_private_key.ssh.public_key_openssh)

  cloudinit_extra_user_data = {
    write_files = [{
      path    = "/etc/firewalld/services/k0s-controller.xml",
      content = file("${path.module}/k0s-controller.firewalld-service.xml"),
    }]
  }

  cloudinit_extra_runcmds = [
    ["firewall-offline-cmd", "--add-service=k0s-controller"],
    # ["firewall-offline-cmd", "--add-source=10.244.0.0/16"],
    ["systemctl", "reload", "firewalld.service"],
  ]
}

module "workers" {
  source = "./modules/machine"

  count = var.worker_num_nodes

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume_id     = libvirt_volume.base.id
  libvirt_network_id         = libvirt_network.network.id

  machine_name       = "${var.resource_name_prefix}worker-${count.index}"
  machine_dns_domain = libvirt_network.network.domain

  machine_num_cpus = var.worker_num_cpus
  machine_memory   = var.worker_memory

  machine_user           = var.machine_user
  machine_ssh_public_key = chomp(tls_private_key.ssh.public_key_openssh)

  cloudinit_extra_user_data = {
    write_files = [{
      path    = "/etc/firewalld/services/k0s-worker.xml",
      content = file("${path.module}/k0s-worker.firewalld-service.xml"),
    }]
  }

  cloudinit_extra_runcmds = [
    ["firewall-offline-cmd", "--add-service=k0s-worker"],
    #["firewall-offline-cmd", "--add-source=10.244.0.0/16"],
    ["firewall-offline-cmd", "--add-masquerade"],
    ["systemctl", "reload", "firewalld.service"],
  ]
}

module "loadbalancer" {
  source = "./modules/machine"

  count = var.loadbalancer_enabled ? 1 : 0

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume_id     = libvirt_volume.base.id
  libvirt_network_id         = libvirt_network.network.id

  machine_name       = "${var.resource_name_prefix}lb"
  machine_dns_domain = libvirt_network.network.domain

  machine_num_cpus = 1
  machine_memory   = 128

  machine_user           = var.machine_user
  machine_ssh_public_key = chomp(tls_private_key.ssh.public_key_openssh)

  cloudinit_extra_runcmds = [
    ["rc-update", "add", "haproxy", "boot"],
    ["/etc/init.d/haproxy", "start"],
  ]

  cloudinit_extra_user_data = {
    write_files = [{
      path = "/etc/haproxy/haproxy.cfg",
      content = templatefile("${path.module}/haproxy.cfg.tftpl", {
        k8s_api_port             = local.k8s_api_port,
        k0s_api_port             = local.k0s_api_port,
        konnectivity_server_port = local.konnectivity_server_port,

        # This is a hack, since the file is only generated on first boot.
        # Just add 5 controllers by default and let HAProxy resolve the IPs via DNS.
        # controllers = module.controllers.*.info
        controllers = [
          { name = "${var.resource_name_prefix}controller-0" },
          { name = "${var.resource_name_prefix}controller-1" },
          { name = "${var.resource_name_prefix}controller-2" },
          { name = "${var.resource_name_prefix}controller-3" },
          { name = "${var.resource_name_prefix}controller-4" },
        ],
      }),
    }]
  }
}
