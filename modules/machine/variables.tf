variable "libvirt_provider_uri" {
  type        = string
  description = "Libvirt provider's URI"
}

variable "libvirt_resource_pool_name" {
  type        = string
  description = "Name of libvirt the resource pool into which the virtual machine will be placed"
}

variable "libvirt_base_volume_id" {
  type        = string
  description = "Libvirt base image voulme ID for the virtual machine"
}

variable "libvirt_network_id" {
  type        = string
  description = "Libvirt network ID in which the virtual machine resides"
}

variable "libvirt_network_ipv4_cidr" {
  type        = string
  description = "IPv4 CIDR of the libvirt network in which the virtual machine resides"

  validation {
    condition     = can(cidrnetmask(var.libvirt_network_ipv4_cidr))
    error_message = "Invalid IPv4 network CIDR."
  }

  validation {
    condition     = try(cidrsubnet(var.libvirt_network_ipv4_cidr, 0, 0) == var.libvirt_network_ipv4_cidr, true)
    error_message = "IPv4 network CIDR is not a network address in canonical form. Did you mean ${try(cidrsubnet(var.libvirt_network_ipv4_cidr, 0, 0), "")}?"
  }
}

variable "libvirt_network_ipv6_cidr" {
  type        = string
  description = "IPv6 CIDR of the libvirt network in which the virtual machine resides, or null if it has none"

  validation {
    condition = var.libvirt_network_ipv6_cidr == null || (
      # The cidrnetmask function only accepts IPv4 CIDRs.
      can(cidrhost(var.libvirt_network_ipv6_cidr, 0)) && !can(cidrnetmask(var.libvirt_network_ipv6_cidr))
    )
    error_message = "Invalid IPv6 network CIDR."
  }

  validation {
    condition     = try(cidrsubnet(var.libvirt_network_ipv6_cidr, 0, 0) == var.libvirt_network_ipv6_cidr, true)
    error_message = "IPv6 network CIDR is not a network address in canonical form. Did you mean ${try(cidrsubnet(var.libvirt_network_ipv6_cidr, 0, 0), "")}?"
  }
}

variable "machine_name" {
  type        = string
  description = "The virtual machine's name"
}

variable "machine_dns_domain" {
  type        = string
  description = "The virtual machine's DNS domain name"
}

variable "machine_num_cpus" {
  type        = number
  description = "The number CPUs allocated to the virtual machine"
}

variable "machine_memory" {
  type        = number
  description = "The amount of RAM (in MiB) allocated to the virtual machine"
}

variable "machine_user" {
  type        = string
  description = "Username used to SSH into the virtual machine"
}

variable "machine_ssh_public_key" {
  type        = string
  description = "SSH public key used to SSH into the virtual machine"
}

variable "cloudinit_extra_runcmds" {
  type        = list(string)
  description = "xoxo"
  default     = []

  validation {
    condition     = var.cloudinit_extra_runcmds != null
    error_message = "cloud-init extra runcmds cannot be null."
  }
}

variable "cloudinit_extra_user_data" {
  type    = map(any)
  default = {}

  validation {
    condition     = var.cloudinit_extra_user_data != null
    error_message = "cloud-init extra data cannot be null."
  }
}

variable "cloudinit_network_config" {
  type    = any
  default = null
}
