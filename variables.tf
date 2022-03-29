# General libvirt configuration

variable "libvirt_provider_uri" {
  type        = string
  description = "Libvirt provider's URI"
  default     = "qemu:///system"
}

variable "libvirt_resource_pool_location" {
  type        = string
  description = "Location where resource pool will be initialized"
  default     = "/var/lib/libvirt/pools/"

  validation {
    condition     = length(var.libvirt_resource_pool_location) != 0
    error_message = "Libvirt resource pool location cannot be empty."
  }
}

variable "libvirt_resource_name_prefix" {
  type        = string
  description = "Prefix added to libvirt resources"
  default     = "k0s-"

  validation {
    condition     = length(var.libvirt_resource_name_prefix) != 0
    error_message = "Libvirt resource name prefix cannot be empty."
  }
}

variable "libvirt_network_ipv4_cidr" {
  type        = string
  description = "IPv4 CIDR of the libvirt network of the virtual machines."
  default     = "10.83.134.0/24"

  validation {
    condition     = can(regex("^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}/([1-9]|[1-2][0-9]|3[0-2])$", var.libvirt_network_ipv4_cidr))
    error_message = "Invalid IPv4 network CIDR."
  }
}

variable "libvirt_network_ipv6_cidr" {
  type        = string
  description = "IPv6 CIDR of the libvirt network of the virtual machines."
  default     = "fd43:7c8a:a2ba:c2::/64"

  validation {
    condition     = can(regex("^[0-9a-f]{1,4}(:[0-9a-f]{1,4})+::/[0-9]+$", var.libvirt_network_ipv6_cidr))
    error_message = "Invalid IPv6 network CIDR."
  }
}

variable "libvirt_network_dns_domain" {
  type        = string
  description = "DNS domain of the libvirt network of the virtual machines."
  default     = "k0s-net.local"

  validation {
    condition     = length(var.libvirt_network_dns_domain) != 0
    error_message = "Libvirt network DNS domain cannot be empty."
  }
}

# General virtual machine configuration

variable "machine_image_source" {
  type        = string
  description = "Image source, which can be path on host's filesystem or URL."
  default     = "alpine-image/image.qcow2"

  validation {
    condition     = length(var.machine_image_source) != 0
    error_message = "Virtual machine image source is missing."
  }
}

variable "machine_user" {
  type        = string
  description = "Username used to SSH into virtual machines"
  default     = "k0s"
}

# Controller node parameters

variable "controller_num_nodes" {
  type        = number
  description = "The number controller nodes to spin up"
  default     = 1
}

variable "controller_num_cpus" {
  type        = number
  description = "The number CPUs allocated to a controller node"
  default     = 1
}

variable "controller_memory" {
  type        = number
  description = "The amount of RAM (in MiB) allocated to a controller node"
  default     = 1024
}

variable "controller_k0s_enable_worker" {
  type        = bool
  description = "Whether k0s on the controllers should also schedule workloads"
  default     = false
}

# Worker node parameters

variable "worker_num_nodes" {
  type        = number
  description = "The number worker nodes to spin up"
  default     = 1
}

variable "worker_num_cpus" {
  type        = number
  description = "The number CPUs allocated to a worker node"
  default     = 1
}

variable "worker_memory" {
  type        = number
  description = "The amount of RAM (in MiB) allocated to a worker node"
  default     = 1024
}

# k0s variables
variable "k0s_version" {
  type        = string
  description = "The k0s version to deploy on the machines. May be an exact version, \"stable\" or \"latest\"."
  default     = "stable"
}

# k0sctl variables

variable "k0sctl_binary_path" {
  type        = string
  description = "Path to the k0sctl binary to use for local-exec provisioning, or null to skip k0sctl resources."
  default     = "k0sctl"
}

variable "k0sctl_k0s_binary_path" {
  type        = string
  description = "Path to the k0s binary to use, or null if it should be downloaded"
  default     = null
}

variable "k0sctl_airgap_image_bundle" {
  type        = string
  description = <<-EOD
    Path to the airgap image bundle to be copied to the worker-enabled nodes, or null
    if it should be downloaded. See https://docs.k0sproject.io/head/airgap-install/
    for details on that.
  EOD
  default     = null
}
