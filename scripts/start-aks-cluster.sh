#!/bin/bash

set -euo pipefail
log() { echo "$1" >&2; }

RESOURCE_GROUP="$1"
CLUSTER="$2"
if [[ -z "$CLUSTER" || -z "$RESOURCE_GROUP" ]]; then
	echo "stop-aks-cluster.sh <resource_group> <cluster>"
	exit 1
fi

POWERSTATE=$(az aks show \
	--resource-group "$RESOURCE_GROUP" \
	--name "$CLUSTER" \
	--query "powerState.code" -o tsv)

if [[ "$POWERSTATE" -eq "Stopped" ]]; then
	az aks stop \
		--resource-group "$RESOURCE_GROUP" \
		--name "$CLUSTER" \
		--no-wait

    log "Successfully started AKS cluster '$CLUSTER'."
else
    log "AKS cluster '$LUSTER' is already in running state."
fi

# az aks scale --resource-group demo-k8s-rg --name demo-k8s --nodepool-name system --node-count 1
# az aks nodepool update --resource-group demo-k8s-rg --cluster-name demo-k8s --name devtest --enable-cluster-autoscaler --min-count 0 --max-count 3