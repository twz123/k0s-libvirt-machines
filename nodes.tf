module "controllers" {
  source = "./modules/machine"

  count = var.controller_num_nodes

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume_id     = libvirt_volume.base.id
  libvirt_network_id         = libvirt_network.network.id

  machine_name     = "${var.resource_name_prefix}controller-${count.index}"
  machine_num_cpus = var.controller_num_cpus
  machine_memory   = var.controller_memory
  machine_user     = var.machine_user

  cloud_init_id = module.controllers_cloud_init[count.index].id
}

module "controllers_cloud_init" {
  source = "./modules/cloud-init"

  count = var.controller_num_nodes

  libvirt_resource_pool_name = libvirt_pool.resource_pool.name

  hostname   = "${var.resource_name_prefix}controller-${count.index}"
  dns_domain = libvirt_network.network.domain

  cloud_user                    = var.machine_user
  cloud_user_authorized_ssh_key = chomp(tls_private_key.ssh.public_key_openssh)
}

module "workers" {
  source = "./modules/machine"

  count = var.worker_num_nodes

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = libvirt_pool.resource_pool.name
  libvirt_base_volume_id     = libvirt_volume.base.id
  libvirt_network_id         = libvirt_network.network.id

  machine_name     = "${var.resource_name_prefix}worker-${count.index}"
  machine_num_cpus = var.worker_num_cpus
  machine_memory   = var.worker_memory
  machine_user     = var.machine_user

  cloud_init_id = module.workers_cloud_init[count.index].id
}

module "workers_cloud_init" {
  source = "./modules/cloud-init"

  count = var.worker_num_nodes

  libvirt_resource_pool_name = libvirt_pool.resource_pool.name

  hostname   = "${var.resource_name_prefix}worker-${count.index}"
  dns_domain = libvirt_network.network.domain

  cloud_user                    = var.machine_user
  cloud_user_authorized_ssh_key = chomp(tls_private_key.ssh.public_key_openssh)
}
