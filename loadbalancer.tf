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
}
