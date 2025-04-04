variable "token" {
}
# Create the vault entities
resource "vault_identity_entity" "entity" {
  for_each = toset(var.entities)
  name      = each.key
  policies = [vault_policy.kv_rw_policy.name, vault_policy.postgres_creds_policy.name]

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
