variable "libvirt_resource_pool_name" {
  type        = string
  description = "Name of libvirt the resource pool into which the cloud-init ISO will be placed."
}

variable "hostname" {
  type        = string
  description = "The hostname to be set on the machine."
}

variable "dns_domain" {
  type        = string
  description = "The DNS domain of the machine. Used to construct the FQDN together with the hostname."
}

variable "cloud_user" {
  type        = string
  description = "The name of the user that's to be provisioned on the machine."
}

variable "cloud_user_authorized_ssh_key" {
  type        = string
  description = "The SSH key that's authorized to connect to the user provisined by cloud-init."
}

variable "extra_runcmds" {
  type    = list(string)
  default = []

  validation {
    condition     = var.extra_runcmds != null
    error_message = "cloud-init extra runcmds cannot be null."
  }
}

variable "extra_user_data" {
  type    = map(any)
  default = {}

  validation {
    condition     = var.extra_user_data != null
    error_message = "cloud-init extra data cannot be null."
  }
}
