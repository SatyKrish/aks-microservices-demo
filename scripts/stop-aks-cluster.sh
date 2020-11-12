#!/bin/bash

set -euo pipefail
log() { echo "$1" >&2; }

RESOURCE_GROUP="$1"
CLUSTER="$2"
if [[ -z "$CLUSTER" || -z "$RESOURCE_GROUP" ]]; then
	echo "stop-aks-cluster.sh <resource_group> <cluster>"
	exit 1
fi

# List nodepools in AKS cluster
NODEPOOLS=$(az aks nodepool list \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER \
    --query '[].name' -o tsv)

for NODEPOOL in $NODEPOOLS
do
    AUTOSCALING_ENABLED=$(az aks nodepool show \
        --resource-group  $RESOURCE_GROUP \
        --cluster-name $CLUSTER \
        --name $NODEPOOL \
        --query "enableAutoScaling")

    if ( $AUTOSCALING_ENABLED ); then
        # Disable cluster autoscaler (CA) in system nodepool
        az aks nodepool update \
            --resource-group $RESOURCE_GROUP \
            --cluster-name $AKS_CLUSTER \
            --name $NODEPOOL \
            --disable-cluster-autoscaler

        log "Successfully disabled Cluster Autoscaler for AKS nodepool - $NODEPOOL."
    else
        log "Cluster Autoscaler for AKS nodepool - $NODEPOOL is in disabled state."
    fi
done


POWERSTATE=$(az aks show \
	--resource-group "$RESOURCE_GROUP" \
	--name "$CLUSTER" \
	--query "powerState.code" -o tsv)

if [[ "$POWERSTATE" -eq "Running" ]]; then
	az aks stop \
		--resource-group "$RESOURCE_GROUP" \
		--name "$CLUSTER" \
		--no-wait

    log "Successfully stopped AKS cluster '$CLUSTER'."
else
    log "AKS cluster '$CLUSTER' is already in stopped state."
fi
