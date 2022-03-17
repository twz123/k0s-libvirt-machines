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

variable "libvirt_network_cidr" {
  type        = string
  description = "CIDR of the libvirt network of the virtual machines."
  default     = "10.83.134.0/24"

  validation {
    condition     = can(regex("^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}/([1-9]|[1-2][0-9]|3[0-2])$", var.libvirt_network_cidr))
    error_message = "Invalid network CIDR."
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
  default     = 3
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