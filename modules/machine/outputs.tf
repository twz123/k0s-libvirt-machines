locals {
  # The addresses of the machine's network interface, as seen by the guest agent.
  interface_addresses = [for addr in libvirt_domain.machine.network_interface.0.addresses : {
    addr = addr
    type = length(regexall(":", addr)) > 0 ? "ipv6" : "ipv4"
  }]

  # Only consider the addresses that are part of the libvirt network.
  addresses = { for family, cidr in {
    ipv4 = var.libvirt_network_ipv4_cidr
    ipv6 = var.libvirt_network_ipv6_cidr
    } : family => cidr == null ? [] : [
    for addr in local.interface_addresses : addr.addr
    if addr.type != family ? false : (
      cidrhost("${addr.addr}/${split("/", cidr)[1]}", 0) == cidrhost(cidr, 0)
    )
  ] }
}

output "info" {
  # The preconditions below aren't checked when destroying, but the value is
  # still evaluated. Don't let ambiguous addresses get in the way of that.
  value = {
    name = libvirt_domain.machine.name
    ipv4 = length(local.addresses.ipv4) == 1 ? local.addresses.ipv4[0] : null
    ipv6 = length(local.addresses.ipv6) == 1 ? local.addresses.ipv6[0] : null
  }

  description = "Virtual machine info containing it's name and IP addresses"

  # A powered-off machine doesn't have any IPs.
  # Failing on that would prevent it from being started again.
  precondition {
    condition     = length(local.addresses.ipv4) <= 1
    error_message = "Expected ${var.machine_name} to have at most one IPv4 address in ${var.libvirt_network_ipv4_cidr}, but its guest agent reported ${join(", ", local.addresses.ipv4)}."
  }

  precondition {
    condition     = length(local.addresses.ipv6) <= 1
    error_message = "Expected ${var.machine_name} to have at most one IPv6 address in ${coalesce(var.libvirt_network_ipv6_cidr, "n/a")}, but its guest agent reported ${join(", ", local.addresses.ipv6)}."
  }
}
