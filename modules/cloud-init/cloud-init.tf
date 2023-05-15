# Some random password to assign to the virtual machine's user
resource "random_password" "password" {
  length  = 32
  special = false
}

# Assemble the cloud-init iso
resource "libvirt_cloudinit_disk" "cloud_init" {
  name = "${var.hostname}-cloud-init.iso"
  pool = var.libvirt_resource_pool_name

  user_data = format("#cloud-config\n%s", jsonencode(merge(var.extra_user_data, {
    hostname         = var.hostname
    fqdn             = join(".", [var.hostname, var.dns_domain])
    manage_etc_hosts = true

    users = [{
      name                = var.cloud_user
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      home                = "/home/${var.cloud_user}"
      shell               = "/bin/sh"
      lock_passwd         = true
      ssh-authorized-keys = [var.cloud_user_authorized_ssh_key]
    }]

    ssh_pwauth   = false
    disable_root = true

    chpasswd = {
      list   = join(":", [var.cloud_user, random_password.password.result])
      expire = false
    }

    runcmd = concat([
      # https://github.com/kubernetes/kubernetes/issues/108877
      <<-EOF
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
        } >>/etc/modules \
          && modprobe -a -- $(cat /etc/modules)
      EOF
      ,
    ], var.extra_runcmds)

    # apply network config on every boot
    updates = { network = { when = ["boot"], }, }

    # written to /var/log/cloud-init-output.log
    final_message = "The system is finally up, after $UPTIME seconds"
  })))

  network_config = jsonencode({
    version   = 2
    ethernets = { eth0 = { dhcp4 = true, dhcp6 = true, }, }
  })
}
