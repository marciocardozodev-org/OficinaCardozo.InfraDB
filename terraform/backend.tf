terraform {
  backend "s3" {
    bucket  = "oficina-cardozo-terraform-state"
    key     = "db/prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
