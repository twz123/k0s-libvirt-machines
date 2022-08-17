locals {
  use_remote_k0s_version = var.k0s_version == "stable" || var.k0s_version == "latest"

  machines = concat(
    [for machine in module.controllers.*.info :
      merge(machine, {
        controller_enabled = true
        worker_enabled     = var.controller_k0s_enable_worker
      })
    ],
    [for machine in module.workers.*.info :
      merge(machine, {
        controller_enabled = false
        worker_enabled     = true
      })
  ])
}

data "http" "k0s_version" {
  count = local.use_remote_k0s_version ? 1 : 0
  url   = "https://docs.k0sproject.io/${var.k0s_version}.txt"
}

locals {
  k0sctl_config = {
    apiVersion = "k0sctl.k0sproject.io/v1beta1"
    kind       = "Cluster"
    metadata   = { name = "k0s-cluster" }
    spec = {
      k0s = {
        version = local.use_remote_k0s_version ? chomp(data.http.k0s_version.0.body) : var.k0s_version
        config = { spec = merge(
          { telemetry = { enabled = false, }, },
          var.k0s_config_spec,
        ), }
      }
      hosts = [for machine in local.machines : merge(
        {
          role = machine.controller_enabled ? (machine.worker_enabled ? "controller+worker" : "controller") : "worker"
          ssh = {
            address = machine.ipv4
            keyPath = local_file.ssh_private_key.filename
            port    = 22
            user    = var.machine_user
          }
          installFlags = var.k0sctl_k0s_install_flags
          uploadBinary = true
        },
        var.k0sctl_k0s_binary == null ? {} : {
          k0sBinaryPath = var.k0sctl_k0s_binary
        },
        machine.worker_enabled && var.k0sctl_airgap_image_bundle != null ? {
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
  }
}

resource "null_resource" "k0sctl_apply" {
  count = var.k0sctl_binary == null ? 0 : 1

  triggers = {
    k0sctl_config            = jsonencode(local.k0sctl_config)
    k0s_binary_hash          = var.k0sctl_k0s_binary == null ? null : filesha256(var.k0sctl_k0s_binary)
    airgap_image_bundle_hash = var.k0sctl_airgap_image_bundle == null ? null : filesha256(var.k0sctl_airgap_image_bundle)
  }

  provisioner "local-exec" {
    environment = {
      K0SCTL_BINARY = var.k0sctl_binary
      K0SCTL_CONFIG = jsonencode(local.k0sctl_config)
    }

    command = <<-EOF
      printf %s "$K0SCTL_CONFIG" | "$K0SCTL_BINARY" apply --disable-telemetry --disable-upgrade-check -c -
      EOF
  }
}

data "external" "k0s_kubeconfig" {
  # Dirty hack to get the kubeconfig into Terrafrom. Requires jq.

  count = var.k0sctl_binary == null ? 0 : 1
  query = {
    k0sctl_config = jsonencode(local.k0sctl_config)
  }

  program = [
    "/usr/bin/env", "sh", "-ec",
    "jq '.k0sctl_config | fromjson' | '${var.k0sctl_binary}' kubeconfig --disable-telemetry -c - | jq --raw-input --slurp '{kubeconfig: .}'",
  ]

  depends_on = [null_resource.k0sctl_apply]
}
