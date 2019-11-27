#!/bin/bash
#
bash ./ymf.sh production.values.yaml cumbersell cumbersell/digest temp
bash ./ymf.sh temp initDb cumbersell-init-db/digest updated-chart/production.values.yaml

