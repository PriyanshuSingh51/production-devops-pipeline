module "platform" {
  source = "../../"

  environment        = "dev"
  aws_region         = "us-east-1"
  database_username  = var.database_username
  database_password  = var.database_password
}
