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
