# Makefile
#
CP=cp --preserve

install:
	@echo "Note that the tdh-gcp project is intended to be self-contained."
	@echo "Most of the tools rely on relative path, so the repository "
	@echo "should be added to the user's system PATH instead."
	@echo "Some of the base scripts can function independently and "
	@echo "can be installed by setting TCAMAKE_PREFIX."
ifdef TCAMAKE_PREFIX
	@echo
	@echo "Installing to ${TCAMAKE_PREFIX}/bin/"
	$(CP) bin/gcp-compute.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gcp-fw-ingress.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gcp-networks.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gke-init.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/tdh-gcp-env.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) tools/tdh-push.sh ${TCAMAKE_PREFIX}/bin/
endif