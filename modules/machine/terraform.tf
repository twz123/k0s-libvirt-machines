terraform {
  required_version = "~> 1.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.6.0"
    }
  }
}
