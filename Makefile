TF = terraform
JQ = jq
SSH = ssh

.PHONY: apply
apply: alpine-image/image.qcow2 .terraform/.init id_rsa.pub
	$(TF) apply -auto-approve

.PHONY: metadata
metadata:
	$(TF) refresh && $(TF) output ips

.PHONY: ssh
ssh: IP ?= $(shell $(TF) output -json ips | $(JQ) -r '.[0][0]')
ssh:
	@[ '$(IP)' != null ] || { echo 'Run `$(MAKE) metadata` first.' 1>&2; exit 1; }
	$(SSH) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ./id_rsa 'k0s@$(IP)'

.PHONY: destroy
destroy:
	$(TF) destroy -auto-approve
	-rm terraform.tfstate terraform.tfstate.backup

.PHONY: alpine-image/%
alpine-image/%:
	$(MAKE) -C '$(dir $@)' '$(notdir $@)'

id_rsa.pub:
	ssh-keygen -t rsa -b 4096 -f id_rsa -C simple -N "" -q

clean:
	-$(MAKE) destroy
	-$(MAKE) -C alpine-image clean
	-rm -rf .terraform
	-rm id_rsa id_rsa.pub

.terraform/.init:
	$(TF) init
	touch .terraform/.init
