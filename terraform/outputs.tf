output "endpoint" {
  description = "Endpoint do RDS (host:porta)"
  value       = aws_db_instance.db.endpoint
}

output "host" {
  description = "Host do RDS — DB_HOST no overlay prod"
  value       = aws_db_instance.db.address
}

output "db_nome" {
  description = "Nome do banco"
  value       = aws_db_instance.db.db_name
}

output "secret_arn" {
  description = "ARN do segredo com as credenciais"
  value       = aws_secretsmanager_secret.db.arn
}

output "security_group_id" {
  description = "SG do RDS"
  value       = aws_security_group.db.id
}
