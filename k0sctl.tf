locals {
  use_remote_k0s_version = var.k0s_version == "stable" || var.k0s_version == "latest"
}

data "http" "k0s_version" {
  count = local.use_remote_k0s_version ? 1 : 0
  url   = "https://docs.k0sproject.io/${var.k0s_version}.txt"
}

resource "local_file" "k0sctl_config" {
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

resource "null_resource" "k0s_apply" {
  triggers = {
    k0sctl_config = local_file.k0sctl_config.content
  }

  provisioner "local-exec" {
    command = "'${var.k0sctl_path}' apply '${local_file.k0sctl_config.filename}'"
  }
}

data "external" "k0s_kubeconfig" {
  # Dirty hack to get the kubeconfig into Terrafrom. Requires jq.
  program = [
    "/usr/bin/env", "sh", "-ec",
    <<-EOF
      KUBECONFIG="$('${var.k0sctl_path}' kubeconfig --config='${local_file.k0sctl_config.filename}')"
      printf %s "$KUBECONFIG" | jq --raw-input --slurp '{kubeconfig: .}'
    EOF
  ]

  depends_on = [null_resource.k0s_apply]
}

resource "local_file" "k0sctl_kubeconfig" {
  filename        = "kubeconfig"
  file_permission = "0600"

  content = data.external.k0s_kubeconfig.result.kubeconfig
}
