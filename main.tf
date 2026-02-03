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