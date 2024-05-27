terraform {
  required_version = ">= 1.3.0"

  required_providers {
    tls      = { source = "hashicorp/tls", version = "~> 4.0", }
    local    = { source = "hashicorp/local", version = "~> 2.0", }
    http     = { source = "hashicorp/http", version = "~> 2.0", }
    null     = { source = "hashicorp/null", version = "~> 3.0", }
    external = { source = "hashicorp/external", version = "~> 2.0", }
    libvirt  = { source = "dmacvicar/libvirt", version = "~> 0.7.0", }
  }
}
