module "machine" {
  source = "../machine"

  libvirt_provider_uri       = var.libvirt_provider_uri
  libvirt_resource_pool_name = var.libvirt_resource_pool_name
  libvirt_base_volume_id     = var.libvirt_base_volume_id
  libvirt_network_id         = var.libvirt_network_id

  machine_name     = var.machine_name
  machine_num_cpus = var.machine_num_cpus
  machine_memory   = var.machine_memory

  cloud_init_id = module.cloud_init.id
}

module "cloud_init" {
  source = "../cloud-init"

  libvirt_resource_pool_name = var.libvirt_resource_pool_name

  hostname   = var.machine_name
  dns_domain = var.machine_dns_domain

  cloud_user                    = var.cloud_user
  cloud_user_authorized_ssh_key = var.cloud_user_authorized_ssh_key
}
