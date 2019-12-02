#!/bin/bash
#
set -euo pipefail # e option will stop further processing on fails
IFS=$'\n\t'

cat production.values.yaml | \
	 ./ymf.sh -p image:cumbersell:digest -f cumbersell/digest |\
	 ./ymf.sh -p image:initDb:digest -f cumbersell-init-db/digest\
	 > updated-chart/production.values.yaml
