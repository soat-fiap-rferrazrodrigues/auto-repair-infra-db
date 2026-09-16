# auto-repair-infra-db

Banco de dados gerenciado (Amazon RDS PostgreSQL 16) da plataforma
Auto Repair Shop.

## Conteúdo

| Caminho | Descrição |
|---|---|
| `terraform/db/` | Instância RDS, subnet group, security groups e segredo |
| `.github/workflows/infra-db.yml` | Plan em PR, apply em homolog e produção |

## Pré-requisitos

- Terraform >= 1.5.0
- O stack `auto-repair-infra-k8s` **já aplicado**: a rede (VPC e subnets
  privadas) é lida deste repositório via remote state
- Bucket S3 `auto-repair-terraform-state` para o state remoto

## Como aplicar

```bash
cd terraform/db

terraform init -backend-config="key=db/homolog/terraform.tfstate"
terraform plan  -var="environment=homolog"
terraform apply -var="environment=homolog"
```

A senha é gerada pelo Terraform (`random_password`) e publicada no AWS Secrets
Manager junto com os dados de conexão. Ela nunca aparece em variável de
ambiente, manifest ou arquivo de configuração.

## Diferenças entre ambientes

| | homolog | produção |
|---|---|---|
| Instância | `db.t3.micro` | `db.t3.small` |
| Multi-AZ | não | sim |
| Deletion protection | não | sim |
| Retenção de backup | 7 dias | 30 dias |

## Guardrail de destruição

O workflow falha o Pull Request se o plan indicar **delete** do recurso
`aws_db_instance`. É uma proteção deliberada: um `terraform apply` distraído
sobre um banco de produção é irreversível, e o plan é o único momento em que
isso ainda pode ser barrado.

Para mudanças que realmente exijam recriar a instância, remova o guardrail em
um commit separado e explícito.

## Migrations

Este repositório provisiona **apenas a infraestrutura**. O schema é versionado
em migrations do TypeORM, no repositório `auto-repair-shop-api`, e aplicado
pelo pipeline da aplicação antes de cada rollout.

## Secrets do repositório

| Secret | Uso |
|---|---|
| `AWS_ROLE_ARN` | Role assumida via OIDC pelo pipeline |
