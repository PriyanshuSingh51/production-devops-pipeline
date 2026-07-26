module "platform" {
  source = "../../"

  environment        = "prod"
  aws_region         = "us-east-1"
  database_username  = var.database_username
  database_password  = var.database_password
}

# Production overrides — bigger nodes, multi-AZ database, longer retention.
# (Root module reads var.environment == "prod" to toggle multi_az/backup
# retention automatically; add explicit overrides here if you need to
# diverge further, e.g. a larger node_groups map.)
