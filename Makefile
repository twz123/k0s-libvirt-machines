TF = terraform
JQ = jq
SSH = ssh

.PHONY: apply
apply: .terraform/.init id_rsa.pub
	$(MAKE) -C alpine-image image.qcow2
	$(TF) apply -auto-approve

ssh.%: ID ?= 0
ssh.%: IP ?= $(shell $(TF) output -json  $(patsubst .%,%,$(suffix $@))_infos | jq -r '.[$(ID)].ips[] | select(contains("::") | not)')
.PHONY: ssh.controller
ssh.controller:
	@[ -n '$(IP)' ] || { echo No IP found.; echo '$(TF) refresh'; $(TF) refresh; exit 1; }
	$(SSH) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ./id_rsa 'k0s@$(IP)'

.PHONY: destroy
destroy:
	$(TF) destroy -auto-approve
	-rm terraform.tfstate terraform.tfstate.backup

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
