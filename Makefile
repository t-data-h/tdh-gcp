# Makefile
#
CP=cp --preserve

SSH_PUBKEY=ansible/.ansible/master-id_rsa.pub

clean:
	( rm $(SSH_PUBKEY) )

distclean: clean


install:
	@echo "Note that the tdh-gcp project is intended to be self-contained and relies "
	@echo "on relative path to the project root. Some of the base gcp scripts can function "
	@echo "as stand-alone scripts, but installing them is not necessary."
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