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

# -----------------------------
# SAS Token (Write Only)  # Ramesh Ramesh ramesh
# -----------------------------
data "azurerm_storage_account_sas" "write_sas" {
  connection_string = azurerm_storage_account.storage.primary_connection_string
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    file  = false
    queue = false
    table = false
  }

  start  = formatdate("YYYY-MM-DD", timestamp())
  expiry = formatdate("YYYY-MM-DD", timeadd(timestamp(), "168h"))

  permissions {
    read    = false
    write   = true
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

# -----------------------------
# Key Vault
# -----------------------------
resource "azurerm_key_vault" "kv" {
  name                       = "${local.project}kv${random_id.kv_suffix.hex}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Recover",
      "Backup", "Restore", "Purge"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover",
      "Backup", "Restore", "Purge"
    ]
  }
}

# -----------------------------
# Cosmos DB Account
# -----------------------------
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "${local.project}cosmos${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

# -----------------------------
# Cosmos DB SQL Database
# -----------------------------
resource "azurerm_cosmosdb_sql_database" "socialappdb" {
  name                = "socialappdb"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

# -----------------------------
# Cosmos DB Containers  # Ramesh Ramesh
# -----------------------------
resource "azurerm_cosmosdb_sql_container" "Users" {
  name                = "Users"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.socialappdb.name
  partition_key_path  = "/userId"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "Posts" {
  name                = "Posts"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.socialappdb.name
  partition_key_path  = "/postId"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "Comments" {
  name                = "Comments"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.socialappdb.name
  partition_key_path  = "/commentId"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "Likes" {
  name                = "Likes"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.socialappdb.name
  partition_key_path  = "/likeId"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "ReportedPosts" {
  name                = "ReportedPosts"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.socialappdb.name
  partition_key_path  = "/postId"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "Chats" {
  name                = "Chats"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.socialappdb.name
  partition_key_path  = "/chatId"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "Messages" {
  name                = "Messages"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.socialappdb.name
  partition_key_path  = "/chatId"
  throughput          = 400
}

# -----------------------------
# Azure Container Registry
# -----------------------------
resource "azurerm_container_registry" "acr" {
  name                = "${local.project}acr${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}
