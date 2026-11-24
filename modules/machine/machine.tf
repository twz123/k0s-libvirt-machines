# Create the boot volume
resource "libvirt_volume" "boot" {
  name = "${var.machine_name}-boot.qcow2"
  pool = var.libvirt_resource_pool_name

  capacity = var.libvirt_base_volume.capacity

  target = { format = { type = "qcow2" } }

  backing_store = {
    path   = var.libvirt_base_volume.path
    format = { type = "qcow2" }
  }
}

# Create the machine
resource "libvirt_domain" "machine" {
  name = var.machine_name
  type = "kvm"

  memory      = var.machine_memory
  memory_unit = "MiB"
  vcpu        = var.machine_num_cpus

  running = true

  os = { type = "hvm" }

  features = {
    acpi = true
    apic = {}
  }

  cpu = { mode = "host-passthrough" }

  devices = {
    disks = [
      {
        # Needs to be spelled out, libvirt assumes raw otherwise
        driver = { type = "qcow2" }
        target = { dev = "vda" }

        source = {
          volume = {
            pool   = libvirt_volume.boot.pool
            volume = libvirt_volume.boot.name
          }
        }
      },
      {
        device = "cdrom"
        target = { dev = "hdd" }

        source = {
          volume = {
            pool   = libvirt_volume.cloudinit.pool
            volume = libvirt_volume.cloudinit.name
          }
        }
      },
    ]

    interfaces = [{
      model  = { type = "virtio" }
      source = { network = { network = var.libvirt_network_name } }

      # Wait until the guest agent reports an IPv4 address in the network
      wait_for_ip = {
        source  = "agent"
        network = var.libvirt_network_ipv4_cidr
      }
    }]

    # Allow the host to talk to the guest agent
    channels = [{
      source = { unix = {} }
      target = { virt_io = { name = "org.qemu.guest_agent.0" } }
    }]

    graphics = [{
      spice = { auto_port = true }
    }]

    rngs = [{
      model   = "virtio"
      backend = { random = "/dev/urandom" }
    }]
  }
}

data "libvirt_domain_interface_addresses" "machine" {
  domain = libvirt_domain.machine.uuid
  source = "agent"
}
