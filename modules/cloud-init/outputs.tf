output "id" {
  value       = libvirt_cloudinit_disk.cloud_init.id
  description = "ID of the cloud-init ISO"
}
