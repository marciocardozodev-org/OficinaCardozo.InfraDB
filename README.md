# OficinaCardozo.InfraDB

## Descrição
Repositório de infraestrutura como código para provisionamento do banco de dados Aurora e recursos relacionados na AWS para a aplicação Oficina Cardozo.

## Tecnologias Utilizadas
- AWS Aurora
- Terraform / CloudFormation (ajustar conforme ferramenta utilizada)

## Passos para Execução e Deploy
1. Clone o repositório.
2. Configure as credenciais AWS.
3. Execute os scripts Terraform/CloudFormation para provisionar o banco.

## Diagrama da Arquitetura
```mermaid
flowchart LR
    App[OficinaCardozo.API (EKS)]
    Lambda[AWS Lambda (Autenticação)]
    DB[(Aurora)]
    App --> DB
    Lambda --> DB
```
