#!/bin/bash
#  Install wrapper script to sync configs only
#
tdh_path=$(dirname "$(readlink -f "$0")")
tag="tdh-config"

# -------

( $tdh_path/tdh-gcp-install.sh --tags $tag $@ )

exit $?
