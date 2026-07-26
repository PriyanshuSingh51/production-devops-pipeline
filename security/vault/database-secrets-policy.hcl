# Vault policy: read-only access to database credentials for app service accounts
path "secret/data/database/*" {
  capabilities = ["read"]
}

path "secret/data/apis/*" {
  capabilities = ["read"]
}

path "database/creds/ecommerce-readonly" {
  capabilities = ["read"]
}
