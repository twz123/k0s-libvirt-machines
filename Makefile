TF = terraform
JQ = jq
SSH = ssh
K0SCTL = k0sctl

.PHONY: apply
apply: .tf.apply
.tf.apply: .terraform/.init $(shell find . -type f -name '*.tf') local.tfvars
	$(MAKE) -C alpine-image image.qcow2
	$(TF) apply -auto-approve -var-file=local.tfvars
	touch -- '$@'

ssh.%: ID ?= 0
ssh.%: IP ?= $(shell $(TF) output -json $(patsubst .%,%,$(suffix $@))_infos | jq -r '.[$(ID)].ipv4')
.PHONY: ssh.controller
ssh.controller: .tf.apply
	@[ -n '$(IP)' ] || { echo No IP found.; echo '$(TF) refresh'; $(TF) refresh; exit 1; }
	$(SSH) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ./id_rsa 'k0s@$(IP)'

.PHONY: destroy
destroy: .terraform/.init
	$(TF) destroy -auto-approve
	-rm terraform.tfstate terraform.tfstate.backup
	-rm kubeconfig .k0sctl.apply
	-rm .tf.apply

.PHONY: k0sctl.apply
k0sctl.apply: .k0sctl.apply
.k0sctl.apply: .tf.apply
	$(K0SCTL) apply --config=k0sctl.yaml
	$(K0SCTL) kubeconfig >kubeconfig
	touch -- '$@'

.terraform/.init:
	$(TF) init
	touch .terraform/.init

local.tfvars:
	@if [ ! -f '$@' ]; then \
	  { \
	    echo '# Put your variable overrides here ...' \
	    ; echo \
	    ; echo \
	    ; \
	  } >'$@' \
	  ; echo Put your local variable overrides into $@ \
	  ; \
	else \
	  touch -- '$@' \
	  ; \
	fi

clean:
	-$(MAKE) destroy
	-rm -rf .terraform
	-$(MAKE) -C alpine-image clean
