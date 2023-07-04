DOCKER ?= docker
JQ ?= jq
SSH ?= ssh
TF ?= terraform

PROFILE ?= k0s

.DELETE_ON_ERROR:

apply: profiles/$(PROFILE)/kubeconfig
init: .terraform/.init
destroy:
	$(MAKE) .destroy

PHONY: .destroy
.destroy:
	-rm -- 'profiles/$(PROFILE)/profile.tfstate' 'profiles/$(PROFILE)/profile.tfstate.backup'
	-rm -- 'profiles/$(PROFILE)/kubeconfig'
	-rm '.tf.apply.$(PROFILE)'
	[ -s 'profiles/$(PROFILE)/profile.tfvars' ] || rm -f -- 'profiles/$(PROFILE)/profile.tfvars'

TF_STATE_CMDS := apply
TF_PHONY_CMDS := console destroy refresh output
TF_CMDS := $(TF_STATE_CMDS) $(TF_PHONY_CMDS)

TF_CLI_ARGS :=

ifneq ($(firstword $(MAKECMDGOALS)),+)
# If the first goal is a terraform command ...
ifneq ($(filter $(firstword $(MAKECMDGOALS)),$(TF_CMDS)),)
  # use all subsequent goals as args to that command
  TF_CLI_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # and turn them into do-nothing targets
  $(eval $(TF_CLI_ARGS):;@:)
endif
else
+:;@:
endif

# common args to terraform commands
.tf.%: TF_ARGS += -state='profiles/$(PROFILE)/profile.tfstate'
.tf.apply.% .tf.destroy: TF_ARGS += -auto-approve
.tf.apply.% .tf.console .tf.destroy .tf.refresh: TF_ARGS += -var-file='profiles/$(PROFILE)/profile.tfvars' -var='profile_folder=profiles/$(PROFILE)'

.PHONY: $(addprefix .tf.,$(TF_PHONY_CMDS))
$(addprefix .tf.,$(TF_PHONY_CMDS)): .terraform/.init
	$(TF) $(patsubst .tf.%,%,$@) $(TF_ARGS) $(TF_CLI_ARGS)

$(patsubst %,.tf.%.$(PROFILE),$(TF_STATE_CMDS)): .terraform/.init
	$(TF) $(patsubst .tf.%.$(PROFILE),%,$@) $(TF_ARGS) $(TF_CLI_ARGS)
	touch -- '$@'

.PHONY: $(TF_CMDS)
$(foreach cmd,$(TF_PHONY_CMDS),$(eval $(cmd): .tf.$(cmd)))
$(foreach cmd,$(TF_STATE_CMDS),$(eval $(cmd): .tf.$(cmd).$(PROFILE)))

.tf.apply.$(PROFILE): .alpine-image $(shell find . -type f -name '*.tf') profiles/$(PROFILE)/profile.tfvars

.tf.destroy: .tf.touch-profile

.PHONY: .tf.touch-profile
.tf.touch-profile: | profiles/$(PROFILE)
	touch -- 'profiles/$(PROFILE)/profile.tfvars'

.PHONY: .alpine-image
.alpine-image:
	$(MAKE) -C alpine-image image.qcow2

Rocky-9-GenericCloud.latest.x86_64.qcow2:
	truncate -s0 -- '$@'
	chattr +C -- '$@'
	curl -Lo '$@' -- 'https://dl.rockylinux.org/vault/rocky/9.1/images/x86_64/$@'

OL8U8_x86_64-kvm-b198.qcow2:
	truncate -s0 -- '$@'
	chattr +C -- '$@'
	curl -Lo '$@' -- 'https://yum.oracle.com/templates/OracleLinux/OL8/u8/x86_64/$(@:%.qcow2=%.qcow)'

OL9U2_x86_64-kvm-b197.qcow2:
	truncate -s0 -- '$@'
	chattr +C -- '$@'
	curl -Lo '$@' -- 'https://yum.oracle.com/templates/OracleLinux/OL9/u2/x86_64/$(@:%.qcow2=%.qcow)'

CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2:
	truncate -s0 -- '$@'
	chattr +C -- '$@'
	curl -Lo '$@' -- 'https://cloud.centos.org/centos/8-stream/x86_64/images/$@'

ssh.%: ID ?= 0
ssh.%: SSH_CONNECT ?= $(shell $(MAKE) -s output -- -json | $(JQ) -r '@sh "-i \(.ssh.value.key_file) \(.ssh.value.user)@\((.machines.value[] | select(.name | endswith("$(patsubst .%,%,$(suffix $@))-$(ID)")).ipv4))"')
.PHONY: ssh.controller ssh.worker
ssh.controller ssh.worker:
	@[ -n '$(SSH_CONNECT)' ] || { echo No machine found.; exit 1; }
	$(SSH) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $(SSH_CONNECT) $(SSH_CMDLINE)

profiles/$(PROFILE):
	mkdir -p -- '$@'

.PHONY: profiles/$(PROFILE)/airgap-images.tar
profiles/$(PROFILE)/airgap-images.tar: | profiles/$(PROFILE)
	@set -e \
	  && set -- \
	  && images="$$(cat)" \
	  && for image in $$images; do \
	    $(DOCKER) pull -- "$$image" \
	    && set -- "$$@" "$$image" \
	  ; done \
	  && echo Saving $@ ... \
	  && $(DOCKER) image save "$$@" -o '$@.tmp' \
	  && mv -- '$@.tmp' '$@'

.PHONY: kube-env
kube-env:
# use / as a marker for "KUBECONFIG wasn't set", since this is never a valid file name
	@echo '# use like so: eval "$$($(MAKE) $@)"'
	@echo
	@echo 'case "$${__K0S_LIBVIRT_MACHINES_OLD_KUBECONFIG-//}" in'
	@echo '//) ;;'
	@echo '/) unset KUBECONFIG;;'
	@echo '*) export KUBECONFIG="$$__K0S_LIBVIRT_MACHINES_OLD_KUBECONFIG";;'
	@echo 'esac'
	@echo 'unset __K0S_LIBVIRT_MACHINES_OLD_KUBECONFIG'
	@echo
	@echo export __K0S_LIBVIRT_MACHINES_OLD_KUBECONFIG="$${KUBECONFIG-/}"
	@echo export KUBECONFIG="'$(CURDIR)/profiles/$(PROFILE)/kubeconfig'":'"$${KUBECONFIG-$$HOME/.kube/config}"'
	@echo echo KUBECONFIG set.

.terraform/.init: $(shell find . -type f -name 'terraform.tf')
	$(TF) init
	touch -- '$@'

profiles/$(PROFILE)/profile.tfvars: | profiles/$(PROFILE)
	@if [ ! -f '$@' ]; then \
	  { \
	    echo '# Put your variable overrides here ...' \
	    ; echo \
	    ; echo '# Prefix to be prepended to all resource names.' \
	    ; echo resource_name_prefix = '"$(PROFILE)-"'\
	    ; echo \
	    ; echo '# IPv4 CIDR of the libvirt network of the virtual machines.' \
	    ; u4() { od -N1 -tu4 -An < /dev/urandom | tr -d [:space:]; } \
	    ; printf 'libvirt_network_ipv4_cidr = "172.%s.%s.0/24"\n' "$$(($$(u4) % 8 + 24))" "$$(u4)" \
	    ; echo \
	    ; echo '# The k0s version to deploy on the machines. May be an exact version, "stable" or "latest".' \
	    ; echo 'k0s_version = "stable"' \
	    ; echo '# Whether to enable k0s dynamic configuration.' \
	    ; echo 'k0s_dynamic_config = false' \
	    ; echo '# The k0s config spec' \
	    ; echo 'k0s_config_spec = {}' \
	    ; echo '# Path to the k0s binary to use, or null if it should be downloaded.' \
	    ; echo 'k0sctl_k0s_binary = null' \
	    ; echo '# Path to the airgap image bundle to be copied to the worker-enabled nodes, or null.' \
	    ; echo 'k0sctl_airgap_image_bundle = null' \
	    ; echo '# Additional files to be copied over to controller nodes.' \
	    ; echo 'k0sctl_additional_controller_files = []' \
	    ; echo '# Install flags to be passed to k0s.' \
	    ; echo 'k0sctl_k0s_install_flags = []' \
	    ; echo '# Install flags to be passed to k0s controllers.' \
	    ; echo 'k0sctl_k0s_controller_install_flags = []' \
	    ; echo '# Install flags to be passed to k0s workers.' \
	    ; echo 'k0sctl_k0s_worker_install_flags = []' \
	    ; echo '' \
	    ; echo '# Whether k0s on the controllers should also schedule workloads.' \
	    ; echo 'controller_k0s_enable_worker = false' \
	    ; echo '# The amount of RAM (in MiB) allocated to a controller node.' \
	    ; echo 'controller_memory = 1024' \
	    ; echo '# The number CPUs allocated to a controller node.' \
	    ; echo 'controller_num_cpus = 1' \
	    ; echo '# The number controller nodes to spin up.' \
	    ; echo 'controller_num_nodes = 1' \
	    ; echo \
	    ; echo '# The amount of RAM (in MiB) allocated to a worker node.' \
	    ; echo 'worker_memory = 1024' \
	    ; echo '# The number CPUs allocated to a worker node.' \
	    ; echo 'worker_num_cpus = 1' \
	    ; echo '# The number worker nodes to spin up.' \
	    ; echo 'worker_num_nodes = 1' \
	    ; echo \
	    ; echo '# Whether to use a load balancer in front of the control plane.' \
	    ; echo 'loadbalancer_enabled = false' \
	  ; } >'$@' \
	  ; echo The file $@ has been created with some local terraform variable overrides. 1>&2 \
	  ; if [ -n "$$EDITOR" ]; then \
	    read -p 'Please hit enter to edit it right now ... ' \
	    ; "$$EDITOR" '$@' \
	  ; else \
	    echo Please inspect it and re-run $(MAKE) $(MAKECMDGOALS) ... 1>&2 \
	    ; exit 1 \
	  ; fi \
	; else \
	  touch -- '$@' \
	; fi

profiles/$(PROFILE)/kubeconfig: .tf.apply.$(PROFILE) | profiles/$(PROFILE)
	$(MAKE) -s output -- -json kubeconfig | $(JQ) -r . >'$@'

clean:
	-if [ -f .terraform/init ]; then \
	  $(MAKE) destroy; \
	else \
	  $(MAKE) .destroy; \
	fi
	-rm -rf .terraform
	-rm -- 'profiles/$(PROFILE)/airgap-images.tar' 'profiles/$(PROFILE)/airgap-images.tar.tmp'
	-$(MAKE) -C alpine-image clean
