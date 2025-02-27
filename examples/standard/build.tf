module "rg" {
  source = "cyber-scot/rg/azurerm"

  name     = "rg-${var.short}-${var.loc}-${var.env}-01"
  location = local.location
  tags     = local.tags
}

data "azurerm_subscription" "current" {}

module "vnet_manager" {
  source = "cyber-scot/virtual-network-manager/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags


  name = "avnm-${var.short}-${var.loc}-${var.env}-01"

  scope = [
    {
      subscription_ids = [data.azurerm_subscription.current.id]
    }
  ]

  scope_accesses = [
    "Connectivity",
    "SecurityAdmin"
  ]

  network_groups = [
    "Prd",
    "Dev"
  ]
}

module "hub_network" {
  source = "cyber-scot/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name          = "vnet-hub-${var.short}-${var.loc}-${var.env}-01"
  vnet_location      = module.rg.rg_location
  vnet_address_space = ["10.0.0.0/16"]

  subnets = {
    "sn1-${module.hub_network.vnet_name}" = {
      address_prefixes  = ["10.0.0.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
  }
}

module "hub_nsg" {
  source = "cyber-scot/nsg/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name              = "nsg-hub-${var.short}-${var.loc}-${var.env}-01"
  associate_with_subnet = true
  subnet_id             = element(values(module.hub_network.subnets_ids), 0)
  custom_nsg_rules = {
    "AllowVnetInbound" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
  }
}

module "spoke_network" {
  source = "cyber-scot/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name          = "vnet-spoke-${var.short}-${var.loc}-${var.env}-01"
  vnet_location      = module.rg.rg_location
  vnet_address_space = ["10.0.0.0/16"]

  subnets = {
    "sn1-${module.spoke_network.vnet_name}" = {
      address_prefixes  = ["10.0.0.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
  }
}

module "spoke_nsg" {
  source = "cyber-scot/nsg/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name              = "nsg-spoke-${var.short}-${var.loc}-${var.env}-01"
  associate_with_subnet = true
  subnet_id             = element(values(module.spoke_network.subnets_ids), 0)
  custom_nsg_rules = {
    "AllowVnetInbound" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
  }
}


module "vnet_manager_config" {
  source = "cyber-scot/virtual-network-manager-configuration/azurerm"

  connectivity_config = [
    {
      name                            = "Config1"
      vnet_manager_id                 = module.vnet_manager.network_manager_id
      connectivity_topology           = "HubAndSpoke"
      delete_existing_peering_enabled = true
      global_mesh_enabled             = false
      applies_to_group = [
        {
          group_connectivity  = "DirectlyConnected"
          network_group_id    = module.vnet_manager.network_group_ids["Prd"]
          global_mesh_enabled = false
          use_hub_gateway     = true
        }
      ]
      hub = [
        {
          resource_id = module.hub_network.vnet_id
        }
      ]
    }
  ]

  security_admin_config = [
    {
      name                                          = "SecConfig1"
      vnet_manager_id                               = module.vnet_manager.network_manager_id
      apply_on_network_intent_policy_based_services = ["None"]
      description                                   = "Sec config 1"
    }
  ]
}
