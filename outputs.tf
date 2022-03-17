output "controller_infos" {
  value = module.controllers.*.machine_info
}
