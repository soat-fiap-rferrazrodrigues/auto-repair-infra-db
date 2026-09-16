locals {
  name       = "auto-repair-${var.environment}"
  vpc_id     = data.terraform_remote_state.k8s.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.k8s.outputs.private_subnets
  node_sg_id = data.terraform_remote_state.k8s.outputs.node_security_group_id
}

# Master password is generated and never stored in git.
resource "random_password" "db" {
  length  = 32
  special = true
  # RDS rejects these characters in master passwords.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnet"
  subnet_ids = local.subnet_ids
}

resource "aws_security_group" "rds" {
  name_prefix = "${local.name}-rds-"
  description = "Allows PostgreSQL traffic from EKS nodes and the auth Lambda only"
  vpc_id      = local.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "from_eks_nodes" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = local.node_sg_id
  description              = "PostgreSQL from EKS worker nodes"
}

resource "aws_security_group_rule" "from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "PostgreSQL from the CPF authentication Lambda"
}

resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound"
}

# Security group attached to the auth Lambda ENIs so it can reach RDS.
resource "aws_security_group" "lambda" {
  name_prefix = "${local.name}-auth-lambda-"
  description = "Egress-only group for the CPF authentication Lambda"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "postgres" {
  identifier     = "${local.name}-db"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 3
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = var.multi_az
  publicly_accessible = false

  backup_retention_period = var.backup_retention_days
  deletion_protection     = var.environment == "prod"
  skip_final_snapshot     = var.environment != "prod"
  final_snapshot_identifier = (
    var.environment == "prod" ? "${local.name}-final-snapshot" : null
  )

  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  auto_minor_version_upgrade      = true
}

# Connection details consumed by the API (External Secrets) and the Lambda.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/database"
  description             = "PostgreSQL connection details for the Auto Repair Shop platform"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    DATABASE_HOST     = aws_db_instance.postgres.address
    DATABASE_PORT     = tostring(aws_db_instance.postgres.port)
    DATABASE_NAME     = aws_db_instance.postgres.db_name
    DATABASE_USER     = var.db_username
    DATABASE_PASSWORD = random_password.db.result
    DATABASE_SSL      = "true"
  })
}
