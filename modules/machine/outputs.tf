output "info" {
  value = {
    name = libvirt_domain.machine.name
    ipv4 = one([for addr in libvirt_domain.machine.network_interface.0.addresses :
      addr if length(regexall(":", addr)) == 0
    ])
    ipv6 = one([for addr in libvirt_domain.machine.network_interface.0.addresses :
      addr if length(regexall(":", addr)) > 0
    ])
  }

  description = "Virtual machine info containing its name and IP addresses"
}
