resource "local_file" "k0sctl_yaml" {
  filename        = "k0sctl.yaml"
  file_permission = "0666"

  content = yamlencode({
    apiVersion = "k0sctl.k0sproject.io/v1beta1"
    kind       = "Cluster"
    metadata   = { name = "k0s-cluster" }
    spec = {
      k0s = { version = "1.23.3+k0s.1" }
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
