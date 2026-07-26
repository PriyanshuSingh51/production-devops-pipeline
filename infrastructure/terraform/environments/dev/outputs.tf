output "eks_cluster_name" {
  value = module.platform.eks_cluster_name
}

output "rds_endpoint" {
  value     = module.platform.rds_endpoint
  sensitive = true
}
