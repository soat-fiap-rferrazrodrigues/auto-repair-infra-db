variable "aws_region" {
  description = "AWS region for all database resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (homolog or prod)"
  type        = string

  validation {
    condition     = contains(["homolog", "prod"], var.environment)
    error_message = "environment must be either 'homolog' or 'prod'."
  }
}

variable "state_bucket" {
  description = "S3 bucket holding the remote state of the Kubernetes stack"
  type        = string
  default     = "auto-repair-terraform-state"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "auto_repair"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "db_instance_class" {
  description = "RDS instance size"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial storage in GB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ. Recommended true for prod."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup retention window in days"
  type        = number
  default     = 7
}
