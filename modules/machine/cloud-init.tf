# Some random password to assign to the virtual machine's user
resource "random_password" "password" {
  length  = 32
  special = false
}

# Assemble the cloud-init iso
resource "libvirt_cloudinit_disk" "cloudinit" {
  name = "${var.machine_name}-cloudinit.iso"
  pool = var.libvirt_resource_pool_name

  user_data = format("#cloud-config\n%s", jsonencode(merge(var.cloudinit_extra_user_data, {
    hostname         = var.machine_name
    fqdn             = join(".", [var.machine_name, var.machine_dns_domain])
    manage_etc_hosts = true

    users = [{
      name                = var.machine_user
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      home                = "/home/${var.machine_user}"
      shell               = "/bin/sh"
      lock_passwd         = true
      ssh-authorized-keys = [var.machine_ssh_public_key]
    }]

    ssh_pwauth   = false
    disable_root = true

    chpasswd = {
      list   = join(":", [var.machine_user, random_password.password.result])
      expire = false
    }

    runcmd = concat([
      <<-EOF
        case "$(. /etc/os-release 2>/dev/null && echo "$ID_LIKE")" in
        debian | 'debian '* | *' debian' | *' debian '*)
          DEBIAN_FRONTEND=noninteractive apt-get update
          DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends qemu-guest-agent
          systemctl start qemu-guest-agent
          ;;
        esac
      EOF,

      # https://github.com/kubernetes/kubernetes/issues/108877
      <<-EOF
        mkdir /etc/modules-load.d
        {
          # for kube-proxy
          echo ip_tables
          # echo iptable_filter
          # echo iptable_nat
          # echo iptable_mangle

          # https://github.com/kubernetes/kubernetes/blob/v1.23.4/pkg/proxy/ipvs/README.md#prerequisite
          # echo ip_vs
          # echo ip_vs_rr
          # echo ip_vs_wrr
          # echo ip_vs_sh
          # echo nf_conntrack
        } >>/etc/modules-load.d/k0s.conf \
          && modprobe -a -- $(cat /etc/modules-load.d/k0s.conf)
      EOF
      ,
    ], var.cloudinit_extra_runcmds)

    # apply network config on every boot
    updates = { network = { when = ["boot"], }, }

    # written to /var/log/cloud-init-output.log
    final_message = "The system is finally up, after $UPTIME seconds"
  })))

  network_config = var.cloudinit_network_config == null ? null : jsonencode(var.cloudinit_network_config)
}
