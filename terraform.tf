terraform {
  required_version = ">= 0.15"

  required_providers {
    template = {
      source  = "hashicorp/template"
      version = "~> 2.0"
    }

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
