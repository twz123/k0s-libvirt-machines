variable "profile_folder" {
  type        = string
  description = "Folder in which to create profile-specific files."

  validation {
    condition     = var.profile_folder != null
    error_message = "Profile folder cannot be empty."
  }
}

variable "resource_name_prefix" {
  type        = string
  description = "Prefix to be prepended to all resource names."

  validation {
    condition     = var.resource_name_prefix != null && can(regex("^([a-z][a-z0-9-_]*)?$", var.resource_name_prefix))
    error_message = "Invalid resource prefix."
  }
}

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

variable "libvirt_network_ipv4_cidr" {
  type        = string
  description = "IPv4 CIDR of the libvirt network of the virtual machines."

  validation {
    condition     = can(regex("^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}/([1-9]|[1-2][0-9]|3[0-2])$", var.libvirt_network_ipv4_cidr))
    error_message = "Invalid IPv4 network CIDR."
  }
}

variable "libvirt_network_ipv6_cidr" {
  type        = string
  description = "IPv6 CIDR of the libvirt network of the virtual machines, or null to not specify any."
  default     = null

  validation {
    condition     = var.libvirt_network_ipv6_cidr == null || can(regex("^[0-9a-f]{1,4}(:[0-9a-f]{1,4})+::/[0-9]+$", var.libvirt_network_ipv6_cidr))
    error_message = "Invalid IPv6 network CIDR."
  }
}

variable "libvirt_network_dns_domain" {
  type        = string
  description = "DNS domain of the libvirt network of the virtual machines, or null if a domain name should be auto-generated."
  default     = null

  validation {
    condition     = var.libvirt_network_dns_domain == null || can(regex("^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$", var.libvirt_network_dns_domain))
    error_message = "Invalid libvirt network DNS domain."
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
  description = "Username used to SSH into virtual machines."
  default     = "k0s"
}

# Controller node parameters

variable "controller_num_nodes" {
  type        = number
  description = "The number controller nodes to spin up."
  default     = 1
}

variable "controller_num_cpus" {
  type        = number
  description = "The number CPUs allocated to a controller node."
  default     = 1
}

variable "controller_memory" {
  type        = number
  description = "The amount of RAM (in MiB) allocated to a controller node."
  default     = 1024
}

variable "controller_k0s_enable_worker" {
  type        = bool
  description = "Whether k0s on the controllers should also schedule workloads."
  default     = false
}

# Worker node parameters

variable "worker_num_nodes" {
  type        = number
  description = "The number worker nodes to spin up."
  default     = 1
}

variable "worker_num_cpus" {
  type        = number
  description = "The number CPUs allocated to a worker node."
  default     = 1
}

variable "worker_memory" {
  type        = number
  description = "The amount of RAM (in MiB) allocated to a worker node."
  default     = 1024
}

# Load balancer variables

variable "loadbalancer_enabled" {
  type        = bool
  description = "Whether to use a load balancer in front of the control plane."
  default     = false
}

# k0s variables
variable "k0s_version" {
  type        = string
  description = "The k0s version to deploy on the machines. May be an exact version, \"stable\" or \"latest\"."
  default     = "stable"
}

variable "k0s_dynamic_config" {
  type        = bool
  description = "Whether to enable k0s dynamic configuration."
  default     = false
}

variable "k0s_config_spec" {
  type = object({
    api = optional(object({
      extraArgs = map(string),
    })),
    extensions = optional(object({
      helm = optional(object({
        repositories = optional(list(
          object({
            name     = string,
            url      = string,
            caFile   = optional(string),
            certFile = optional(string),
            insecure = optional(bool),
            keyfile  = optional(string),
            username = optional(string),
            password = optional(string),
          }),
        )),
        charts = optional(list(
          object({
            name      = string,
            chartname = string,
            version   = optional(string),
            values    = optional(string),
            namespace = string,
            timeout   = optional(string),
          }),
        )),
      })),
    })),
    network = optional(object({
      provider = optional(string),
      calico   = optional(map(string)),
      nodeLocalLoadBalancing = optional(object({
        enabled = optional(bool),
        type    = optional(string),
        envoyProxy = optional(object({
          image = optional(object({
            image   = string,
            version = string,
          })),
          port = optional(number),
        })),
      })),
    })),
    images = optional(map(map(object({
      image   = optional(string),
      version = optional(string),
    })))),
    storage = optional(object({
      type = optional(string),
      etcd = optional(object({
        peerAddress = string,
        extraArgs   = map(string),
        externalCluster = optional(object({
          endpoints      = optional(string),
          etcdPrefix     = optional(string),
          caFile         = optional(string),
          clientCertFile = optional(string),
          clientKeyFile  = optional(string),
        })),
      })),
      kine = optional(object({
        dataSource = optional(string),
      })),
    })),
  })
  description = "The k0s config spec"
  default     = null
}

# k0sctl variables

variable "k0sctl_binary" {
  type        = string
  description = "Path to the k0sctl binary to use for local-exec provisioning, or null to skip k0sctl resources."
  default     = "k0sctl"
}

variable "k0sctl_k0s_binary" {
  type        = string
  description = "Path to the k0s binary to use, or null if it should be downloaded."
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

variable "k0sctl_additional_controller_files" {
  type = list(object({
    src    = string
    dstDir = string
    name   = string
    perm   = string
  }))
  nullable    = false
  description = "Additional files to be copied over to controller nodes."
  default     = []
}

variable "k0sctl_k0s_install_flags" {
  type        = list(string)
  description = "Install flags to be passed to k0s."
  default     = []

  validation {
    condition     = var.k0sctl_k0s_install_flags != null
    error_message = "K0s install flags cannot be null."
  }
}

variable "k0sctl_k0s_controller_install_flags" {
  type        = list(string)
  description = "Install flags to be passed to k0s controllers."
  default     = []

  validation {
    condition     = var.k0sctl_k0s_controller_install_flags != null
    error_message = "K0s controller install flags cannot be null."
  }
}

variable "k0sctl_k0s_worker_install_flags" {
  type        = list(string)
  description = "Install flags to be passed to k0s workers."
  default     = []

  validation {
    condition     = var.k0sctl_k0s_worker_install_flags != null
    error_message = "K0s worker install flags cannot be null."
  }
}
