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
  description = "The virtual machine's name in libvirt"
}

variable "machine_dns_domain" {
  type        = string
  description = "The DNS domain of the machine. Used to construct the FQDN together with the machine's name."
}

variable "machine_num_cpus" {
  type        = number
  description = "The number CPUs allocated to the virtual machine"
}

variable "machine_memory" {
  type        = number
  description = "The amount of RAM (in MiB) allocated to the virtual machine"
}

variable "cloud_user" {
  type        = string
  description = "The name of the user that's to be provisioned for SSH access on the machine."
}

variable "cloud_user_authorized_ssh_key" {
  type        = string
  description = "The SSH key that's authorized to connect to the user provisined by cloud-init."
}
