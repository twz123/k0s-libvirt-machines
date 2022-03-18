terraform {
  required_version = "~> 1.0"

  required_providers {
    tls     = { source = "hashicorp/tls", version = "~> 3.0", }
    local   = { source = "hashicorp/local", version = "~> 2.0", }
    libvirt = { source = "dmacvicar/libvirt", version = "~> 0.6.0", }
  }
}
