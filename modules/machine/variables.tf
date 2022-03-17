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

variable "machine_name" {
  type        = string
  description = "The virtual machine's name"
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
