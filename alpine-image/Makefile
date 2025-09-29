SUDO = sudo
QEMU_IMG = qemu-img

alpine.branch = v3.22
alpine-make-vm-image.url = https://raw.githubusercontent.com/alpinelinux/alpine-make-vm-image/v0.13.3/alpine-make-vm-image
alpine-make-vm-image.sha256 = 8c3e6c537aff8649238ff9928fe632953c7948b8c4941d8eb3c2e93abe4cb53e
image.qcow2.size = 8G
image.qcow2.opts = -o nocow=on

image.qcow2: alpine-make-vm-image packages build.sh
	$(eval image_format = $(patsubst .%,%,$(suffix $@)))
	@echo Building $@ ...
	@[ ! -f '$@' ] || rm -f -- '$@'
	@{ \
	  $(QEMU_IMG) create -f '$(image_format)' $($@.opts) '$@.tmp' '$($@.size)' \
	  && $(SUDO) ./alpine-make-vm-image \
	    --branch '$(alpine.branch)' \
	    --image-format '$(image_format)' \
	    --packages '$(shell cat packages)' \
	    --script-chroot \
	    '$@.tmp' \
	    ./build.sh \
	  && $(QEMU_IMG) convert -f '$(image_format)' -O '$(image_format)' -c $($@.opts) '$@.tmp' '$@' \
	  && chmod a-w '$@' \
	  && rm -- '$@.tmp' \
	  ; \
	} \
	  || { \
	    code=$$?; rm -f -- '$@' '$@.tmp' && exit $$code \
	    ; \
	  }

alpine-make-vm-image:
	@echo Downloading $(alpine-make-vm-image.url) ...
	@{ \
	  curl -Lfo '$@' '$(alpine-make-vm-image.url)' \
	    && { echo '$(alpine-make-vm-image.sha256)  $@' | sha256sum -c; } \
	    && chmod +x -- '$@' \
	    ; \
	} \
	  || { \
	    code=$$?; rm -f -- '$@' && exit $$code \
	    ; \
	  }

clean:
	rm -f alpine-make-vm-image image.qcow2 image.qcow2.tmp
