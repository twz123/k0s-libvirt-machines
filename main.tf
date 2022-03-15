terraform {
  required_version = ">= 0.15"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.6.0"
    }
  }
}
