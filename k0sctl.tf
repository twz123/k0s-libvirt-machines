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
      k0s = {
        version = local.use_remote_k0s_version ? chomp(data.http.k0s_version.0.body) : var.k0s_version
        config  = { spec = { telemetry = { enabled = false, }, }, }
      }
      hosts = [for info in module.controllers.*.info : merge(
        {
          role = var.controller_k0s_enable_worker ? "controller+worker" : "controller"
          ssh = {
            address = info.ipv4
            keyPath = local_file.id_rsa.filename
            port    = 22
            user    = var.machine_user
          }
          uploadBinary = true
        },
        var.k0sctl_k0s_binary_path == null ? {} : {
          k0sBinaryPath = var.k0sctl_k0s_binary_path
        },
        var.controller_k0s_enable_worker && var.k0sctl_airgap_image_bundle != null ? {
          files = [
            {
              src    = var.k0sctl_airgap_image_bundle
              dstDir = "/var/lib/k0s/images/"
              name   = "bundle-file"
              perm   = "0755"
            }
          ]
        } : {},
      )]
    }
  })
}

resource "null_resource" "k0sctl_apply" {
  count = var.k0sctl_binary_path == null ? 0 : 1

  triggers = {
    k0sctl_config = local_file.k0sctl_config.content
  }

  provisioner "local-exec" {
    command = join(" ", [
      "'${var.k0sctl_binary_path}'", "apply",
      "--disable-telemetry", "--disable-upgrade-check",
      "'${local_file.k0sctl_config.filename}'",
    ])
  }
}

data "external" "k0s_kubeconfig" {
  count = var.k0sctl_binary_path == null ? 0 : 1

  # Dirty hack to get the kubeconfig into Terrafrom. Requires jq.
  program = [
    "/usr/bin/env", "sh", "-ec",
    <<-EOF
      KUBECONFIG="$('${var.k0sctl_binary_path}' kubeconfig --config='${local_file.k0sctl_config.filename}')"
      printf %s "$KUBECONFIG" | jq --raw-input --slurp '{kubeconfig: .}'
    EOF
  ]

  depends_on = [null_resource.k0sctl_apply]
}

resource "local_file" "k0sctl_kubeconfig" {
  count = var.k0sctl_binary_path == null ? 0 : 1

  filename        = "kubeconfig"
  file_permission = "0600"

  content = data.external.k0s_kubeconfig[0].result.kubeconfig
}
