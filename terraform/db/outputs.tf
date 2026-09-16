output "db_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "db_host" {
  description = "RDS hostname"
  value       = aws_db_instance.postgres.address
}

output "db_name" {
  description = "Initial database name"
  value       = aws_db_instance.postgres.db_name
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the connection details"
  value       = aws_secretsmanager_secret.db.arn
}

output "lambda_security_group_id" {
  description = "Security group the auth Lambda must attach to in order to reach RDS"
  value       = aws_security_group.lambda.id
}
