output "elasticache" {
  value = module.elasticache
}

output "admin_password" {
  description = "Superset password"
  value       = random_password.admin_password.result
  sensitive   = true
}