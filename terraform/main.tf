# Banco gerenciado. A rede vem do oficina-infra-k8s pela SSM — nenhum state
# lê o state do outro.
#
# Optamos por recursos diretos em vez do módulo terraform-aws-modules/rds:
# são ~6 recursos, todos usados, e o módulo v7 mudou o tratamento de senha
# (password_wo) de um jeito que custaria mais tempo de leitura do que escrever
# isto à mão. Registrado como ADR.

data "aws_ssm_parameter" "vpc_id" {
  name = "/oficina/shared/vpc/id"
}

data "aws_ssm_parameter" "subnets_privadas" {
  name = "/oficina/shared/vpc/subnets_privadas"
}

data "aws_ssm_parameter" "node_sg" {
  name = "/oficina/shared/eks/node_sg_id"
}

data "aws_ssm_parameter" "lambda_sg" {
  name = "/oficina/shared/lambda/sg_id"
}

locals {
  nome             = "${var.projeto}-${var.ambiente}"
  subnets_privadas = split(",", data.aws_ssm_parameter.subnets_privadas.value)
}

# `special = false`: a senha entra numa DSN de URL; caracteres especiais
# exigiriam escape em todo consumidor.
resource "random_password" "db" {
  length  = 32
  special = false
}

# ── Rede do banco ─────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "db" {
  name       = local.nome
  subnet_ids = local.subnets_privadas
}

# 5432 aberto SOMENTE para quem precisa. Nunca 0.0.0.0/0.
resource "aws_security_group" "db" {
  name        = "${local.nome}-rds"
  description = "Acesso ao PostgreSQL gerenciado"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
}

resource "aws_vpc_security_group_ingress_rule" "nos_eks" {
  security_group_id            = aws_security_group.db.id
  description                  = "Nos do EKS"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_ssm_parameter.node_sg.value
}

resource "aws_vpc_security_group_ingress_rule" "lambda" {
  security_group_id            = aws_security_group.db.id
  description                  = "Lambda de autenticacao"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_ssm_parameter.lambda_sg.value
}

# ── Instância ─────────────────────────────────────────────────────────────────
resource "aws_db_instance" "db" {
  identifier = local.nome

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = 20
  max_allocated_storage = 100 # autoscaling de storage — evita disco cheio na demo
  storage_type          = "gp3"

  # Ativar criptografia depois exige recriar a instância. É agora ou nunca.
  storage_encrypted = true

  db_name  = var.db_nome
  username = var.db_usuario
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]

  multi_az            = false
  publicly_accessible = false # NUNCA true

  backup_retention_period = 1
  skip_final_snapshot     = true # ambiente de desafio, destruído após a entrega
  deletion_protection     = false
  apply_immediately       = true

  # "Gargalo em tempo real" que o enunciado pede, sem custo no nível free.
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true
}

# ── Credenciais ───────────────────────────────────────────────────────────────
# O state não é cofre: quem consome a senha lê daqui.
resource "aws_secretsmanager_secret" "db" {
  name                    = "oficina/${var.ambiente}/db"
  recovery_window_in_days = 0 # permite recriar com o mesmo nome após um destroy
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = aws_db_instance.db.username
    password = random_password.db.result
    host     = aws_db_instance.db.address
    port     = aws_db_instance.db.port
    dbname   = aws_db_instance.db.db_name
  })
}

# ── Contrato SSM ──────────────────────────────────────────────────────────────
resource "aws_ssm_parameter" "endpoint" {
  name  = "/oficina/${var.ambiente}/db/endpoint"
  type  = "String"
  value = aws_db_instance.db.endpoint
}

resource "aws_ssm_parameter" "host" {
  name  = "/oficina/${var.ambiente}/db/host"
  type  = "String"
  value = aws_db_instance.db.address
}

resource "aws_ssm_parameter" "secret_arn" {
  name  = "/oficina/${var.ambiente}/db/secret_arn"
  type  = "String"
  value = aws_secretsmanager_secret.db.arn
}
