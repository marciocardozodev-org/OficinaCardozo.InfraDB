# Executa migrations EF Core após o RDS estar disponível
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Importa outputs do Terraform do EKS para usar subnets e security group da mesma VPC
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "oficina-cardozo-terraform-state"
    key    = "eks/prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "enable_db" {
  description = "Se true, cria os recursos de banco gerenciado (RDS/Aurora)."
  type        = bool
  default     = false
}

variable "app_name" {
  description = "Prefixo para nomear recursos de banco (ex.: oficina-cardozo)."
  type        = string
  default     = "oficina-cardozo"
}

variable "db_username" {
  description = "Usuário administrador do banco."
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Senha do banco (min 8 chars). Usar secret/tfvars em produção."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = length(var.db_password) == 0 || length(var.db_password) >= 8
    error_message = "Senha inválida. Requisitos: vazio (para testes) ou mínimo 8 caracteres."
  }
}

variable "db_subnet_ids" {
  description = "Lista de subnets privadas onde o Aurora será criado."
  type        = list(string)
  default     = []
  # Não pode usar data source como default. Defina via tfvars ou CLI se necessário.
}

variable "db_security_group_ids" {
  description = "Security Groups que controlam o acesso ao Aurora."
  type        = list(string)
  default     = []
  # Não pode usar data source como default. Defina via tfvars ou CLI se necessário.
}

## Aurora DB Subnet Group (criado apenas quando enable_db=true)
resource "aws_db_subnet_group" "main" {
  count      = var.enable_db ? 1 : 0
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = length(var.db_subnet_ids) > 0 ? var.db_subnet_ids : (try(data.terraform_remote_state.eks.outputs.private_subnet_ids, []))

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

## Aurora PostgreSQL Cluster (criado apenas quando enable_db=true)
resource "aws_rds_cluster" "main" {
  count                    = var.enable_db ? 1 : 0
  cluster_identifier       = "${var.app_name}-aurora-cluster"
  engine                   = "aurora-postgresql"
  engine_version           = "15.15"
  master_username          = var.db_username
  master_password          = var.db_password
  database_name            = "oficinacardozo"
  vpc_security_group_ids   = length(var.db_security_group_ids) > 0 ? var.db_security_group_ids : (try(data.terraform_remote_state.eks.outputs.eks_security_group_ids, []))
  db_subnet_group_name     = aws_db_subnet_group.main[0].name
  skip_final_snapshot      = true
  backup_retention_period  = 1
  storage_encrypted        = true
  apply_immediately        = true
  tags = {
    Name = "${var.app_name}-aurora-cluster"
  }
}

resource "aws_rds_cluster_instance" "main" {
  count               = var.enable_db ? 1 : 0
  identifier          = "${var.app_name}-aurora-instance-1"
  cluster_identifier  = aws_rds_cluster.main[0].id
  instance_class      = "db.r6g.large"
  engine              = aws_rds_cluster.main[0].engine
  engine_version      = aws_rds_cluster.main[0].engine_version
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.main[0].name
  tags = {
    Name = "${var.app_name}-aurora-instance-1"
  }
}


output "rds_host" {
  value       = aws_rds_cluster.main[0].endpoint
  description = "Endpoint do Aurora Cluster"
}

output "rds_reader_host" {
  value       = aws_rds_cluster.main[0].reader_endpoint
  description = "Endpoint de leitura do Aurora Cluster"
}

output "rds_user" {
  value       = var.db_username
  description = "Usuário do Aurora"
}

output "rds_password" {
  value       = var.db_password
  description = "Senha do Aurora"
  sensitive   = true
}

output "rds_db_name" {
  value       = aws_rds_cluster.main[0].database_name
  description = "Nome do banco no Aurora"
}
