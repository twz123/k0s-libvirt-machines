#!/usr/bin/env sh

# Based on https://github.com/alpinelinux/alpine-make-vm-image/blob/v0.8.0/example/configure.sh

_step_counter=0
step() {
  _step_counter=$((_step_counter + 1))
  printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2 # bold cyan
}

step 'Set up timezone'
setup-timezone -z UTC

step 'Set up networking'
cat >/etc/network/interfaces <<-EOF
	iface lo inet loopback
	iface eth0 inet dhcp
  iface eth0 inet6 auto
EOF
ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

step 'Adjust init system'
sed -Ei \
  -e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
  -e 's/^[# ](rc_logger)=.*/\1=YES/' \
  -e 's/^[# ](unicode)=.*/\1=YES/' \
  /etc/rc.conf
#sed -Ei -e 's/^(tty\d+:)/# \1/' /etc/inittab # Disable TTYs

step 'Enable services'
rc-update add machine-id boot
rc-update add net.lo boot
rc-update add net.eth0 boot
rc-update add termencoding boot
rc-update add qemu-guest-agent boot

step 'Setup cloud-init'
setup-cloud-init

step 'Modify defaults'
#passwd -l root          # prevent root logins
truncate -s 0 /etc/motd # no greetings
