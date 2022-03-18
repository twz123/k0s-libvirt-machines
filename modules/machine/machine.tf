# Create the boot volume
resource "libvirt_volume" "boot" {
  name = "${var.machine_name}-boot.qcow2"
  pool = var.libvirt_resource_pool_name

  base_volume_id = var.libvirt_base_volume_id
  format         = "qcow2"
}

# Create the machine
resource "libvirt_domain" "machine" {
  name = var.machine_name

  memory     = var.machine_memory
  vcpu       = var.machine_num_cpus
  qemu_agent = true

  network_interface {
    network_id     = var.libvirt_network_id
    wait_for_lease = true
    hostname       = var.machine_name
    addresses      = [var.machine_network_ipv4_address, var.machine_network_ipv6_address]
  }

  cloudinit = libvirt_cloudinit_disk.cloudinit.id

  disk {
    volume_id = libvirt_volume.boot.id
  }
}
