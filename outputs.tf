output "machines" {
  value = local.machines
}

output "laodbalancer" {
  value = one(module.loadbalancer.*.info)
}

output "ssh" {
  value = {
    user     = var.machine_user
    key_file = local_file.ssh_private_key.filename
  }
}

output "k0sctl_config" {
  value     = local.k0sctl_config
  sensitive = true # not really sensitive but clutters output
}

output "kubeconfig" {
  value     = one(data.external.k0s_kubeconfig.*.result.kubeconfig)
  sensitive = true
}
