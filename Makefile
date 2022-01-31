# Makefile
#
CP=cp --preserve

SSH_PUBKEY=ansible/.ansible/master-id_rsa.pub

clean:
	( rm $(SSH_PUBKEY) )

distclean: clean


install:
	@echo "Note that the tdh-gcp project is intended to be self-"
	@echo "contained. The tools rely on relative path and instead"
	@echo "the repository should be added to the user's system PATH"
	@echo "instead. Some of the base scripts can function independently"
	@echo "and can be installed by setting TCAMAKE_PREFIX"
ifdef TCAMAKE_PREFIX
	@echo
	@echo "Installing to ${TCAMAKE_PREFIX}/bin/"
	$(CP) bin/gcp-compute.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gcp-fw-ingress.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gcp-networks.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gke-init.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/tdh-gcp-env.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/tdh-push.sh ${TCAMAKE_PREFIX}/bin/
endif