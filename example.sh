#!/bin/bash
#
set -euo pipefail # e option will stop further processing on fails
IFS=$'\n\t'

cat production.yaml | \
	 ./yamlBash.sh -k image:cube:digest -f cube/digest |\
	 ./yamlBash.sh -k image:initDb:digest -f init-db/digest\
	 > updated.production.yaml
