server-2025/disk.vmdk: server-2025.iso server-2025.conf virtio-win.iso unattended.iso
# https://github.com/quickemu-project/quickemu/blob/4.9.7/quickemu#L1386
	mkdir -p server-2025
	quickemu --vm server-2025.conf

virtio-win.iso:
	curl -Lo $@ https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/$@

PowerShell-win-x64.msi:
	latestVersion=$$(curl -sSfL https://api.github.com/repos/PowerShell/PowerShell/releases/latest | jq -r .tag_name) && \
	curl -Lo $@ "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-$${latestVersion#v*}-win-x64.msi"

authorized_keys:
	curl -Lo $@ https://github.com/twz123.keys

# https://github.com/quickemu-project/quickemu/blob/4.9.7/quickget#L2977-L2979

spice-webdavd-x64-latest.msi:
	curl -Lo $@ https://www.spice-space.org/download/windows/spice-webdavd/$@

spice-vdagent-x64-0.10.0.msi:
	curl -Lo $@ https://www.spice-space.org/download/windows/vdagent/vdagent-win-0.10.0/$@

UsbDk_1.0.22_x64.msi:
	curl -Lo $@ https://www.spice-space.org/download/windows/usbdk/$@

unattended.iso: autounattend.xml PowerShell-win-x64.msi specialize.ps1 authorized_keys
unattended.iso: spice-webdavd-x64-latest.msi spice-vdagent-x64-0.10.0.msi UsbDk_1.0.22_x64.msi
unattended.iso:
	mkisofs -quiet -iso-level 3 -J -R -V UNATTEND -o '$@' $^

clean:
	rm -rf server-2025/
	rm -f authorized_keys
	rm -f virtio-win.iso
	rm -f PowerShell-win-x64.msi
	rm -f spice-vdagent-x64-0.10.0.msi
	rm -f spice-webdavd-x64-latest.msi
	rm -f UsbDk_1.0.22_x64.msi
	rm -f unattended.iso
