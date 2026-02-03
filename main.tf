############################################
# MAIN.TF – Production-ready Terraform File
# Resources: Resource Group, Storage + Containers,
#            SAS Token, Key Vault, Cosmos DB, ACR
############################################

# -----------------------------
# Locals
# -----------------------------
locals {
    # Normalize project name for Azure resource naming
  project = lower(replace(var.project_name, "-", ""))
}

# -----------------------------
# Current Client Info
# -----------------------------
data "azurerm_client_config" "current" {}  # Used for tenant_id and object_id in Key Vault

# -----------------------------
# Random values
# -----------------------------
resource "random_string" "suffix" {
    # Adds uniqueness to globally-scoped resources
  length  = 6
  upper   = false
  special = false
}

resource "random_id" "suffix" {
# Short hex suffix for resource names
  byte_length = 3
}

resource "random_id" "kv_suffix" {
    # Smaller suffix specifically for Key Vault naming
  byte_length = 2
}

# -----------------------------
# Resource Group
# -----------------------------
resource "azurerm_resource_group" "rg" {
      # Central container for all Azure resources
  name     = "${local.project}-rg-${random_id.suffix.hex}"
  location = var.location
  tags     = var.tags
}

# -----------------------------
# Storage Account
# -----------------------------
resource "azurerm_storage_account" "storage" {
    # Blob storage for media, profiles, and messages
  name                     = "${local.project}store${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

# -----------------------------
# Storage Containers
# -----------------------------
resource "azurerm_storage_container" "media" {
     # Stores post media (images/videos)
  name                  = "media"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "profilepics" {
     # Stores user profile pictures
  name                  = "profilepics"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "messagecontent" {
    # Stores chat message attachments
  name                  = "messagecontent"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}