# Makefile

CP=cp --preserve

install:
ifdef TCAMAKE_PREFIX
	@echo "Installing to ${TCAMAKE_PREFIX}/bin/"
	$(CP) bin/gcp-compute.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gcp-fw-ingress.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gcp-networks.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/gke-init.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/tdh-gcp-config.sh ${TCAMAKE_PREFIX}/bin/
	$(CP) bin/tdh-push.sh ${TCAMAKE_PREFIX}/bin/
endif