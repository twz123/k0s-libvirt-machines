DOCKER ?= docker
JQ ?= jq
K0S ?= k0s
KUBECTL ?= kubectl
SSH ?= ssh
TF ?= terraform

.PHONY: apply
apply: .tf.apply
.tf.apply: .terraform/.init $(shell find . -type f -name '*.tf') local.tfvars
	$(MAKE) -C alpine-image image.qcow2
	$(TF) apply -auto-approve -var-file=local.tfvars
	touch -- '$@'

ssh.%: ID ?= 0
ssh.%: IP ?= $(shell $(TF) output -json machines | $(JQ) -r '.[] | select(.name | endswith("$(patsubst .%,%,$(suffix $@))-$(ID)")).ipv4')
.PHONY: ssh.controller ssh.worker
ssh.controller ssh.worker: .tf.apply
	@[ -n '$(IP)' ] || { echo No IP found.; exit 1; }
	$(SSH) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ./id_rsa 'k0s@$(IP)'

.PHONY: airgap-images.tar
airgap-images.tar:
	@set -e \
	  && set -- \
	  && images="$$($(K0S) airgap list-images)" \
	  && for image in $$images; do \
	    $(DOCKER) pull -- "$$image" \
	    && set -- "$$@" "$$image" \
	  ; done \
	  && echo Saving $@ ... \
	  && $(DOCKER) image save "$$@" -o '$@.tmp' \
	  && mv -- '$@.tmp' '$@'

.PHONY: destroy
destroy: .terraform/.init
	$(TF) destroy -auto-approve
	-rm terraform.tfstate terraform.tfstate.backup
	@#-rm kubeconfig
	-rm .tf.apply

.PHONY: kube-env
kube-env:
	@echo '# use like so: eval "$$($(MAKE) $@)"'
	@echo export KUBECONFIG="'$(CURDIR)/kubeconfig'":'"$${KUBECONFIG-$$HOME/.kube/config}"'
	@echo echo KUBECONFIG set.

.terraform/.init: $(shell find . -type f -name 'terraform.tf')
	$(TF) init
	touch .terraform/.init

local.tfvars:
	@if [ ! -f '$@' ]; then \
	  { \
	    echo '# Put your variable overrides here ...' \
	    ; echo \
	    ; echo \
	  ; } >'$@' \
	  ; echo Put your local variable overrides into $@ \
	; else \
	  touch -- '$@' \
	; fi

clean:
	-$(MAKE) destroy
	-rm -rf .terraform
	-rm airgap-images.tar airgap-images.tar.tmp
	-$(MAKE) -C alpine-image clean
