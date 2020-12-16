# Makefile

CP=cp --preserve


install:
	@echo "Note that the tdh-gcp project is intended to be self-contained and relies "
	@echo "on relative path to the project root. Some of the base gcp scripts do function "
	@echo "properly as stand-alone scripts, but installing them is not really necessary."
ifdef TCAMAKE_PREFIX
	@echo "Installing to ${TCAMAKE_PREFIX}/bin/"
	$(CP) bin/gcp-compute.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gcp-fw-ingress.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gcp-networks.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gke-init.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/tdh-gcp-config.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/tdh-push.sh ${TCAMAKE_PREFIX}/bin/
endif