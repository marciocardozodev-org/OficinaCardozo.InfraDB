# Executa migrations EF Core após o RDS estar disponível
resource "null_resource" "run_migrations" {
  provisioner "local-exec" {
    command = <<EOT
      set -o pipefail
      bash ${path.module}/wait-for-db-and-migrate.sh 2>&1 | tee ${path.module}/run-migrations.log
      EXIT_CODE=$${PIPESTATUS[0]}
      echo "\n================ LOG COMPLETO DO SCRIPT ================\n"
      cat ${path.module}/run-migrations.log
      echo "\n================ FIM DO LOG ================\n"
      exit $EXIT_CODE
    EOT
    environment = {
      RDS_HOST        = aws_db_instance.main[0].address
      RDS_USER        = var.db_username
      RDS_PASS        = var.db_password # Apenas esta variável é sensível, mas não será marcada explicitamente
      RDS_DB          = aws_db_instance.main[0].db_name
      CONNECTION_STRING = "Host=${aws_db_instance.main[0].address};Port=5432;Database=${aws_db_instance.main[0].db_name};Username=${var.db_username};Password=${var.db_password};Ssl Mode=Require;Trust Server Certificate=true;"
      API_PROJECT_PATH = "../../OficinaCardozo.App/OficinaCardozo.API"
      DOTNET_ROOT      = "/usr/share/dotnet"
      DOTNET_VERSION   = "8.0.x"
    }
  }
  depends_on = [aws_db_instance.main]
}
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
  description = "Lista de subnets privadas onde o RDS será criado."
  type        = list(string)
  default     = []
  # Não pode usar data source como default. Defina via tfvars ou CLI se necessário.
}

variable "db_security_group_ids" {
  description = "Security Groups que controlam o acesso ao RDS."
  type        = list(string)
  default     = []
  # Não pode usar data source como default. Defina via tfvars ou CLI se necessário.
}

# DB Subnet Group (criado apenas quando enable_db=true)
resource "aws_db_subnet_group" "main" {
  count      = var.enable_db ? 1 : 0
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = length(var.db_subnet_ids) > 0 ? var.db_subnet_ids : (try(data.terraform_remote_state.eks.outputs.private_subnet_ids, []))

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
  vpc_security_group_ids  = length(var.db_security_group_ids) > 0 ? var.db_security_group_ids : (try(data.terraform_remote_state.eks.outputs.eks_security_group_ids, []))
  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = 0
  maintenance_window      = "mon:04:00-mon:05:00"

  tags = {
    Name = "${var.app_name}-postgresql"
  }
}

  output "rds_host" {
    value       = aws_db_instance.main[0].address
    description = "Endpoint do RDS"
  }

  output "rds_user" {
    value       = aws_db_instance.main[0].username
    description = "Usuário do RDS"
  }

  output "rds_password" {
    value       = var.db_password
    description = "Senha do RDS"
    sensitive   = true
  }

  output "rds_db_name" {
    value       = aws_db_instance.main[0].db_name
    description = "Nome do banco no RDS"
  }

# TODO: importar o RDS existente (aws_db_instance.main) e migrar
#       o provisionamento a partir deste repositório, alinhando nomes
#       e parâmetros com o Terraform atual do projeto serverless.
