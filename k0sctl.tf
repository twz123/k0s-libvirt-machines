locals {
  use_remote_k0s_version = var.k0s_version == "stable" || var.k0s_version == "latest"
}

data "http" "k0s_version" {
  count = local.use_remote_k0s_version ? 1 : 0
  url   = "https://docs.k0sproject.io/${var.k0s_version}.txt"
}

resource "local_file" "k0sctl_yaml" {
  filename        = "k0sctl.yaml"
  file_permission = "0666"

  content = yamlencode({
    apiVersion = "k0sctl.k0sproject.io/v1beta1"
    kind       = "Cluster"
    metadata   = { name = "k0s-cluster" }
    spec = {
      k0s = { version = local.use_remote_k0s_version ? chomp(data.http.k0s_version.0.body) : var.k0s_version }
      hosts = [for info in module.controllers.*.info : {
        role = var.controller_k0s_enable_worker ? "controller+worker" : "controller"
        ssh = {
          address = info.ipv4
          keyPath = local_file.id_rsa.filename
          port    = 22
          user    = var.machine_user
        }
      }]
    }
  })
}
