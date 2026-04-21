GITHUB_OWNER_NAME := twz123
ADMIN_ACCOUNT := Administrator

age_version := 1.3.1

server-2025/disk.vmdk: server-2025.iso server-2025.conf virtio-win.iso unattended.iso
# https://github.com/quickemu-project/quickemu/blob/4.9.9/quickemu#L1966
	mkdir -p server-2025
	quickemu --vm server-2025.conf

virtio-win.iso:
	curl -Lo $@ https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/$@

PowerShell-win-x64.msi:
	latestVersion=$$(curl -sSfL https://api.github.com/repos/PowerShell/PowerShell/releases/latest | jq -r .tag_name) && \
	curl -Lo $@ "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-$${latestVersion#v*}-win-x64.msi"

authorized_keys:
	curl -Lo $@ https://github.com/$(GITHUB_OWNER_NAME).keys

# https://github.com/quickemu-project/quickemu/blob/4.9.9/quickget#L3274-L3275

spice-webdavd-x64-latest.msi:
	curl -Lo $@ https://www.spice-space.org/download/windows/spice-webdavd/$@

spice-vdagent-x64-0.10.0.msi:
	curl -Lo $@ https://www.spice-space.org/download/windows/vdagent/vdagent-win-0.10.0/$@

age-v$(age_version)-windows-amd64.zip:
	curl -Lo $@ https://github.com/FiloSottile/age/releases/download/v$(age_version)/$@

unattended.iso: autounattend.xml PowerShell-win-x64.msi specialize.ps1 authorized_keys
unattended.iso: spice-webdavd-x64-latest.msi spice-vdagent-x64-0.10.0.msi
unattended.iso: age-v$(age_version)-windows-amd64.zip
unattended.iso:
	mkisofs -quiet -iso-level 3 -J -R -V UNATTEND -o '$@' $^

.PHONY: powerdown
ssh:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 22220 $(ADMIN_ACCOUNT)@localhost

.PHONY: powerdown
powerdown:
	printf 'system_powerdown\n' | socat - UNIX-CONNECT:server-2025/server-2025-monitor.socket

.PHONY: clean
clean:
	rm -rf server-2025/
	rm -f authorized_keys
	rm -f virtio-win.iso
	rm -f PowerShell-win-x64.msi
	rm -f spice-vdagent-x64-0.10.0.msi
	rm -f spice-webdavd-x64-latest.msi
	rm -f age-v$(age_version)-windows-amd64.zip
	rm -f unattended.iso
