# Vault server configuration (production, HA via Raft storage on EKS)
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-node-1"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/tls.crt"
  tls_key_file  = "/vault/tls/tls.key"
}

seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/vault-unseal-key"
}

api_addr     = "https://vault.ecommerce.internal:8200"
cluster_addr = "https://vault.ecommerce.internal:8201"
ui           = true
