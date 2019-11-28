#!/bin/bash
#
set -euo pipefail # e option will stop further processing on fails
IFS=$'\n\t'

cat production.values.yaml | \
	 ./ymf.sh -p cumbersell -f cumbersell/digest |\
	 ./ymf.sh -p initDb -f cumbersell-init-db/digest\
	 > updated-chart/production.values.yaml
