terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.90" }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatesaaks"
    container_name       = "tfstate"
    key                  = "aks-petclinic.tfstate"
  }
}

provider "azurerm" {
  features { key_vault { purge_soft_delete_on_destroy = false } }
}

resource "azurerm_resource_group" "aks" {
  name     = "petclinic-aks-rg"
  location = "Southeast Asia"
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "petclinic-aks"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "petclinic"
  kubernetes_version  = "1.28"
  sku_tier            = "Standard"

  # Private cluster — API server accessible only via VNet
  private_cluster_enabled = true
  private_dns_zone_id     = "System"

  default_node_pool {
    name                = "system"
    vm_size             = "Standard_D4s_v5"
    node_count          = 3
    min_count           = 3
    max_count           = 5
    enable_auto_scaling = true
    os_disk_type        = "Ephemeral"
    vnet_subnet_id      = azurerm_subnet.aks_nodes.id
    zones               = ["1", "2", "3"]
    node_labels         = { "nodepool-type" = "system" }
    node_taints         = ["CriticalAddonsOnly=true:NoSchedule"]
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    ebpf_data_plane     = "cilium"
    outbound_type       = "userDefinedRouting"  # NAT Gateway
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = [var.aks_admin_group_id]
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  tags = { environment = "production", team = "platform" }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D8s_v5"
  min_count             = 2
  max_count             = 20
  enable_auto_scaling   = true
  os_disk_type          = "Ephemeral"
  vnet_subnet_id        = azurerm_subnet.aks_nodes.id
  zones                 = ["1", "2", "3"]
  node_labels           = { "nodepool-type" = "user" }
}

resource "azurerm_container_registry" "acr" {
  name                = "petclinicacr"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = "Premium"
  admin_enabled       = false
  georeplications { location = "East Asia" }
}

resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

resource "azurerm_key_vault" "main" {
  name                       = "petclinic-kv"
  resource_group_name        = azurerm_resource_group.aks.name
  location                   = azurerm_resource_group.aks.location
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  enable_rbac_authorization  = true
}
