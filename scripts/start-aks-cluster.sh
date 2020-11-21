#!/bin/bash

log() { echo "$1" >&2; }

RESOURCE_GROUP="$1"
CLUSTER="$2"
if [[ -z "$CLUSTER" || -z "$RESOURCE_GROUP" ]]; then
	log "stop-aks-cluster.sh <resource_group> <cluster>"
	exit 1
fi

set -euo pipefail

enable_autoscaler()
{
	MIN_COUNT=0
	MAX_COUNT=3

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
            log "Cluster Autoscaler for AKS nodepool - $NODEPOOL is already enabled."
        else
			# System nodepool cannot scale to 0
			if [[ "$NODEPOOL" == "system" ]]; then MIN_COUNT=1; fi
			
            # Enable cluster autoscaler (CA) in system nodepool
            az aks nodepool update \
                --resource-group $RESOURCE_GROUP \
                --cluster-name $CLUSTER \
                --name $NODEPOOL \
                --enable-cluster-autoscaler \
				--min-count $MIN_COUNT \
				--max-count $MAX_COUNT

            log "Successfully enabled Cluster Autoscaler for AKS nodepool - $NODEPOOL."
        fi
	done
}

POWERSTATE=$(az aks show \
	--resource-group "$RESOURCE_GROUP" \
	--name "$CLUSTER" \
	--query "powerState.code" -o tsv)

if [[ "$POWERSTATE" == "Stopped" ]]; then
	az aks start \
		--resource-group "$RESOURCE_GROUP" \
		--name "$CLUSTER" 

    log "Successfully started AKS cluster '$CLUSTER'."
else
    log "AKS cluster '$CLUSTER' is already in running state."
fi

POWERSTATE=$(az aks show \
	--resource-group $RESOURCE_GROUP \
	--name $CLUSTER \
	--query 'powerState.code' -o tsv)

if [[ "$POWERSTATE" == "Running" ]]; then
    enable_autoscaler
fi