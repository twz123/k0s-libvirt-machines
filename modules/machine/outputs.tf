output "machine_info" {
  value = {
    name = libvirt_domain.machine.name,
    ips  = libvirt_domain.machine.network_interface.0.addresses.*
  }

  description = "Virtual machine info containing it's name and IP addresses"
}
