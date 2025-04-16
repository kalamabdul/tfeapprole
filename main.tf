# variable "token" {
# }


locals {
  # Generate 10 chunks of 1000
  entities = flatten([
    for chunk in range(0, 3) : [
      for i in range(1, 1002) : format("%05d-tfe", i + (chunk * 1001))
    ]
  ])
}


variable "kv_version" {
    description = "The version for the KV secrets engine. Valid values are kv-v2 or kv"
    default = "kv-v2"
}

variable "kv_mount_path" {
    description = "A Path where the KV Secret Engine should be mounted"
    default = "secrets/kv"
}

variable "postgres_mount_path" {
    description = "A Path where the Database Secret Engine of type Postgres should be mounted"
    default = "postgres"
}

variable "create_entity_token" {
    description = "Specifies whether a KV read and write policy token should be created"
    default = 1
}

variable "approle_mount_path" {
    description = "A Path where the AppRole Auth Method should be mounted"
    default = "approle"
}

variable "token_ttl" {
    description = "Vault token ttl for KV policies"
    default = "24h"
}

variable "postgres_ttl" {
    description = "# of seconds that postgres credentials should be valid for"
    default = 60
}
# Create the vault entities
resource "vault_identity_entity" "entity" {
  for_each = toset(var.entities)
  name      = each.key
  policies = ["kv_rw_policy"]

  metadata  = {
    ait = split("-", each.key)[0]
  }
}

# Create an approle alias
resource "vault_identity_entity_alias" "test" {
  for_each = toset(var.entities)
  name            = vault_approle_auth_backend_role.entity-role[each.key].role_id
  mount_accessor  = "auth_approle_2d330717"
  canonical_id    = vault_identity_entity.entity[each.key].id
}

# Generate a random suffix (5 chars, uppercase alphanumeric)
resource "random_string" "role_suffix" {
for_each = toset(var.entities)
  length  = 5
  upper   = true
  numeric  = true
  lower   = false
  special = false
}


resource "vault_approle_auth_backend_role" "entity-role" {
  backend        = "approle"
  for_each = toset(var.entities)
  role_name      = each.key
  role_id = "ZS${random_string.role_suffix[each.key].result}"
  token_policies = ["default", "kv_rw_policy"]
}

