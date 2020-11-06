terraform {
  # Use a recent version of Terraform
  required_version = ">= 0.13"

  # Map providers to thier sources, required in Terraform 13+
  required_providers {
    # Azure Active Directory 1.x
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 1.0"
    }
    # Azure Resource Manager 2.x
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
    }
    # Random 3.x
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  version = "~> 2.14.0"
  features {}
}

locals {
  aks_cluster_name    = "${var.prefix}-k8s"
}

resource "azurerm_resource_group" "k8s_rg" {
  name     = "${local.aks_cluster_name}-rg"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "k8s_monitor" {
  name                = "${local.aks_cluster_name}-monitor"
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azuread_group" "k8s_administrators" {
  name        = "${local.aks_cluster_name}-administrators"
  description = "Kubernetes administrators for the ${local.aks_cluster_name} cluster."
}

resource "azurerm_kubernetes_cluster" "k8s_cluster" {
  name                = local.aks_cluster_name
  location            = azurerm_resource_group.k8s_rg.location
  resource_group_name = azurerm_resource_group.k8s_rg.name
  dns_prefix          = local.aks_cluster_name

  default_node_pool {
    name                  = "system"
    vm_size               = "Standard_DS2_v2"
    type                  = "VirtualMachineScaleSets"
    enable_auto_scaling   = true
    max_count             = 3
    min_count             = 1
    availability_zones    = [1,2,3]
  }

  network_profile {
    network_plugin = "kubenet"
    load_balancer_sku = "standard"
  }


  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed                = true
      admin_group_object_ids = [azuread_group.k8s_administrators.object_id]
    }
  }

  addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = true
    }

    http_application_routing {
      enabled = false
    }

    kube_dashboard {
      enabled = true
    }

    oms_agent {
      enabled = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.k8s_monitor.id
    }
  }

  tags = {
    environment = var.environment
  }
}