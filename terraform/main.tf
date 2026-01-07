terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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
  description = "Lista de subnets privadas onde o RDS será criado."
  type        = list(string)
  default     = []
}

variable "db_security_group_ids" {
  description = "Security Groups que controlam o acesso ao RDS."
  type        = list(string)
  default     = []
}

# DB Subnet Group (criado apenas quando enable_db=true)
resource "aws_db_subnet_group" "main" {
  count      = var.enable_db ? 1 : 0
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

# Instância RDS PostgreSQL básica (criada apenas quando enable_db=true)
resource "aws_db_instance" "main" {
  count = var.enable_db ? 1 : 0

  identifier              = "${var.app_name}-db"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp2"
  db_name                 = "oficinacardozo"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main[0].name
  vpc_security_group_ids  = var.db_security_group_ids
  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = 0
  maintenance_window      = "mon:04:00-mon:05:00"

  tags = {
    Name = "${var.app_name}-postgresql"
  }
}

# TODO: importar o RDS existente (aws_db_instance.main) e migrar
#       o provisionamento a partir deste repositório, alinhando nomes
#       e parâmetros com o Terraform atual do projeto serverless.
