locals {
  k8s_api_port             = 6443
  k0s_api_port             = 9443
  konnectivity_server_port = 8132

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
    ],
  )
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
        version       = local.use_remote_k0s_version ? chomp(data.http.k0s_version.0.response_body) : var.k0s_version
        dynamicConfig = var.k0s_dynamic_config
        config = { spec = merge(
          { telemetry = { enabled = false, }, },
          (var.loadbalancer_enabled ? { api = {
            externalAddress = module.loadbalancer.0.info.ipv4,
            sans = [
              module.loadbalancer.0.info.name,
              module.loadbalancer.0.info.ipv4,
            ],
          }, } : {}),
          { for k, v in var.k0s_config_spec : k => v if v != null }
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
          installFlags = concat(
            var.k0sctl_k0s_install_flags,
            machine.controller_enabled ? var.k0sctl_k0s_controller_install_flags : [],
            machine.worker_enabled ? var.k0sctl_k0s_worker_install_flags : [],
          )
          uploadBinary = true,
          files = concat(
            machine.worker_enabled && var.k0sctl_airgap_image_bundle != null ? [
              {
                src    = var.k0sctl_airgap_image_bundle
                dstDir = "/var/lib/k0s/images/"
                name   = "bundle-file"
                perm   = "0755"
              }
            ] : [],
            machine.controller_enabled ? var.k0sctl_additional_controller_files : [],
          )
          hooks = { apply = {
            before = concat(
              machine.controller_enabled ? coalesce(var.k0sctl_k0s_controller_hooks.apply.before, []) : [],
              machine.worker_enabled ? coalesce(var.k0sctl_k0s_worker_hooks.apply.before, []) : [],
            ),
            after = concat(
              machine.controller_enabled ? coalesce(var.k0sctl_k0s_controller_hooks.apply.after, []) : [],
              machine.worker_enabled ? coalesce(var.k0sctl_k0s_worker_hooks.apply.after, []) : [],
            ),
          } },
        },
        var.k0sctl_k0s_binary == null ? {} : {
          k0sBinaryPath = var.k0sctl_k0s_binary
        },
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
      printf %s "$K0SCTL_CONFIG" | env -u SSH_AUTH_SOCK SSH_KNOWN_HOSTS='' "$K0SCTL_BINARY" apply --disable-telemetry --disable-upgrade-check -c -
      EOF
  }
}

data "external" "k0s_kubeconfig" {
  count = var.k0sctl_binary == null ? 0 : 1

  query = {
    k0sctl_config = jsonencode(local.k0sctl_config)
  }

  program = [
    "env", "sh", "-ec",
    <<-EOS
      jq '.k0sctl_config | fromjson' |
        { env -u SSH_AUTH_SOCK SSH_KNOWN_HOSTS='' "$1" kubeconfig --disable-telemetry -c - || echo ~~~FAIL; } |
        jq --raw-input --slurp "$2"
    EOS
    , "--",
    var.k0sctl_binary, <<-EOS
      if endswith("~~~FAIL\n") then
        error("Failed to generate kubeconfig!\n" + .)
      else
        {kubeconfig: .}
      end
    EOS
  ]

  depends_on = [null_resource.k0sctl_apply]
}
