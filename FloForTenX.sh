#!/bin/bash
#
set -euo pipefail						# e option will stop further processing on fails
IFS=$'\n\t'

bash ./ymf.sh -i production.values.yaml -p cumbersell -v cumbersell/digest -o temp
bash ./ymf.sh -i temp -p initDb -v cumbersell-init-db/digest -o updated-chart/production.values.yaml
