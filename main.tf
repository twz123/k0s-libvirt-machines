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

  target = {
    path = pathexpand("${trimsuffix(var.libvirt_resource_pool_location, "/")}/${local.libvirt_resource_pool_name}")
  }
}

resource "libvirt_network" "network" {
  name = "${var.resource_name_prefix}network"

  autostart = true

  forward = { mode = "nat" }

  domain = {
    name = var.libvirt_network_dns_domain == null ? "${var.resource_name_prefix}net.local" : var.libvirt_network_dns_domain
  }

  # The first address of each network is assigned to the host,
  # the following ones are handed out via DHCP.
  ips = [for net in [
    { family = "ipv4", cidr = var.libvirt_network_ipv4_cidr },
    { family = "ipv6", cidr = var.libvirt_network_ipv6_cidr }
    ] : {
    family  = net.family
    address = cidrhost(net.cidr, 1)
    prefix  = tonumber(split("/", net.cidr)[1])
    dhcp = {
      ranges = [{
        start = cidrhost(net.cidr, 2)
        # Leave out the broadcast address. Moreover, libvirt refuses to
        # define DHCP ranges that span more than 65535 addresses.
        end = cidrhost(net.cidr, min(pow(2, (net.family == "ipv6" ? 128 : 32) - tonumber(split("/", net.cidr)[1])) - 2, 65535))
      }]
    }
    }
    if net.cidr != null
  ]
}

resource "libvirt_volume" "controller_base" {
  name = "${var.resource_name_prefix}controller-base-volume"
  pool = libvirt_pool.resource_pool.name

  target = { format = { type = "qcow2" } }

  create = {
    content = { url = pathexpand(var.controller_image_source) }
  }
}

resource "libvirt_volume" "worker_base" {
  name = "${var.resource_name_prefix}worker-base-volume"
  pool = libvirt_pool.resource_pool.name

  target = { format = { type = "qcow2" } }

  create = {
    content = { url = pathexpand(var.worker_image_source) }
  }
}

module "controllers" {
  source = "./modules/machine"

  count = var.controller_num_nodes

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume        = libvirt_volume.controller_base
  libvirt_network_name       = libvirt_network.network.name
  libvirt_network_ipv4_cidr  = var.libvirt_network_ipv4_cidr
  libvirt_network_ipv6_cidr  = var.libvirt_network_ipv6_cidr

  machine_name       = "${var.resource_name_prefix}controller-${count.index}"
  machine_dns_domain = libvirt_network.network.domain.name

  # Ignore the CPLB IPs when determining the machine's primary address.
  machine_additional_ips = local.k0s_cplb_ips

  machine_num_cpus = var.controller_num_cpus
  machine_memory   = var.controller_memory

  machine_user           = var.machine_user
  machine_ssh_public_key = chomp(tls_private_key.ssh.public_key_openssh)
}

module "workers" {
  source = "./modules/machine"

  count = var.worker_num_nodes

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume        = libvirt_volume.worker_base
  libvirt_network_name       = libvirt_network.network.name
  libvirt_network_ipv4_cidr  = var.libvirt_network_ipv4_cidr
  libvirt_network_ipv6_cidr  = var.libvirt_network_ipv6_cidr

  cloudinit_extra_user_data = var.worker_cloudinit_extra_user_data
  cloudinit_extra_runcmds   = var.worker_cloudinit_extra_runcmds

  machine_name       = "${var.resource_name_prefix}worker-${count.index}"
  machine_dns_domain = libvirt_network.network.domain.name

  machine_num_cpus = var.worker_num_cpus
  machine_memory   = var.worker_memory

  machine_user           = var.machine_user
  machine_ssh_public_key = chomp(tls_private_key.ssh.public_key_openssh)
}

module "loadbalancer" {
  source = "./modules/machine"

  count = var.loadbalancer_enabled ? 1 : 0

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume        = libvirt_volume.controller_base
  libvirt_network_name       = libvirt_network.network.name
  libvirt_network_ipv4_cidr  = var.libvirt_network_ipv4_cidr
  libvirt_network_ipv6_cidr  = var.libvirt_network_ipv6_cidr

  machine_name       = "${var.resource_name_prefix}lb"
  machine_dns_domain = libvirt_network.network.domain.name

  machine_num_cpus = 1
  machine_memory   = 128

  machine_user           = var.machine_user
  machine_ssh_public_key = chomp(tls_private_key.ssh.public_key_openssh)

  cloudinit_extra_runcmds = [
    "rc-update add haproxy boot",
    "/etc/init.d/haproxy start",
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

  cloudinit_network_config = startswith(var.controller_image_source, "alpine-image/") ? {
    version   = 2
    ethernets = { eth0 = { dhcp4 = true, dhcp6 = true, }, }
  } : null
}
