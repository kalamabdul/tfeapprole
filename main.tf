# variable "token" {
# }


variable "entities" {
    description = "A set of vault clients to create"
    # Keep nginx as the first vault client for docker-compose demo using AppRole. Please append additional apps to the list
    default = [
        "12345-tfe",
        "56789-tfe",
    ]
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
  policies = [vault_policy.kv_rw_policy.name]

  metadata  = {
    ait = split("-", each.key)[0]
  }
}

# Create an approle alias
resource "vault_identity_entity_alias" "test" {
  for_each = toset(var.entities)
  name            = vault_approle_auth_backend_role.entity-role[each.key].role_id
  mount_accessor  = vault_auth_backend.approle.accessor
  canonical_id    = vault_identity_entity.entity[each.key].id
}

# KV Read/Write rule
data "vault_policy_document" "kv_rw_policy" {
  rule {
    path         = "${var.kv_mount_path}/data/ait-73837/{{identity.entity.name}}/token"
    capabilities = ["create", "read", "update", "delete", "list"]
    description  = "allow KV V2 Read Write on secrets"
  }
}


resource "vault_policy" "kv_rw_policy" {
  name = "kv_rw_policy"
  policy = data.vault_policy_document.kv_rw_policy.hcl
}


resource "vault_approle_auth_backend_role" "entity-role" {
  backend        = "approle"
  for_each = toset(var.entities)
  role_name      = each.key
  role_id = each.key
  token_policies = ["default", vault_policy.kv_rw_policy.name]
}

