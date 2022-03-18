TF = terraform
JQ = jq
SSH = ssh

.PHONY: apply
apply: .terraform/.init local.tfvars
	$(MAKE) -C alpine-image image.qcow2
	$(TF) apply -auto-approve -var-file=local.tfvars

ssh.%: ID ?= 0
ssh.%: IP ?= $(shell $(TF) output -json  $(patsubst .%,%,$(suffix $@))_infos | jq -r '.[$(ID)].ipv4')
.PHONY: ssh.controller
ssh.controller:
	@[ -n '$(IP)' ] || { echo No IP found.; echo '$(TF) refresh'; $(TF) refresh; exit 1; }
	$(SSH) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ./id_rsa 'k0s@$(IP)'

.PHONY: destroy
destroy: .terraform/.init
	$(TF) destroy -auto-approve
	-rm terraform.tfstate terraform.tfstate.backup

clean:
	-$(MAKE) destroy
	-$(MAKE) -C alpine-image clean
	-rm -rf .terraform

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
