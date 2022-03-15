SUDO = sudo
TF = terraform
QEMU_IMG = qemu-img
JQ = jq
SSH = ssh

alpine.branch = v3.15
alpine.qcow2.size = 8G
alpine.qcow2.opts = -o nocow=on
alpine-make-vm-image.url = https://raw.githubusercontent.com/alpinelinux/alpine-make-vm-image/v0.8.0/alpine-make-vm-image

.PHONY: apply
apply: alpine.qcow2 .terraform.lock.hcl id_rsa.pub
	$(TF) apply -auto-approve

.PHONY: metadata
metadata:
	$(TF) refresh && $(TF) output ips

.PHONY: ssh
ssh: IP ?= $(shell $(TF) output -json ips | $(JQ) -r '.[0][0]')
ssh:
	$(SSH) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ./id_rsa 'k0s@$(IP)'

.PHONY: destroy
destroy:
	$(TF) destroy -auto-approve
	-rm terraform.tfstate terraform.tfstate.backup

alpine.qcow2: image/alpine-make-vm-image image/packages image/build.sh
	$(eval image_format = $(patsubst .%,%,$(suffix $@)))
	@echo Building $@ ...
	@[ ! -f '$@' ] || rm -f -- '$@'
	@{ \
	  $(QEMU_IMG) create -f '$(image_format)' $($@.opts) '$@.tmp' '$($@.size)' \
	  && $(SUDO) image/alpine-make-vm-image \
	    --branch '$(alpine.branch)' \
	    --image-format '$(image_format)' \
	    --packages '$(shell cat image/packages)' \
	    --script-chroot \
	    '$@.tmp' \
	    image/build.sh \
	  && $(QEMU_IMG) convert -f '$(image_format)' -O '$(image_format)' -c $($@.opts) '$@.tmp' '$@' \
	  && chmod a-w '$@' \
	  && rm -- '$@.tmp' \
	  ; \
	} \
	  || { \
	    code=$$?; rm -f -- '$@' '$@.tmp' && exit $$code \
	    ; \
	  }

image/alpine-make-vm-image:
	@echo Downloading $(alpine-make-vm-image.url) ...
	@{ \
	  curl -Lfo '$@' '$(alpine-make-vm-image.url)' \
	    && chmod +x -- '$@' \
	    ; \
	} \
	  || { \
	    code=$$?; rm -f -- '$@' && exit $$code \
	    ; \
	  }

id_rsa.pub:
	ssh-keygen -t rsa -b 4096 -f id_rsa -C simple -N "" -q

clean:
	-$(MAKE) destroy
	-rm -f image/alpine-make-vm-image alpine.qcow2 alpine.qcow2.tmp
	-rm -rf .terraform
	-rm id_rsa id_rsa.pub

.terraform.lock.hcl: main.tf
	$(TF) init
