variable "regiao" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "projeto" {
  description = "Prefixo dos recursos"
  type        = string
  default     = "oficina"
}

variable "ambiente" {
  description = "Ambiente único da Fase 3 (corte 10)"
  type        = string
  default     = "prod"
}

variable "engine_version" {
  description = "Versão maior do PostgreSQL. '15' acompanha o patch mais recente e casa com o postgres:15.7 do ambiente local"
  type        = string
  default     = "15"
}

# db.t4g.micro: Graviton, ~20% mais barato que t3.micro e coberto pelo
# free tier de 750 h/mês do RDS.
variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_nome" {
  description = "Nome do banco"
  type        = string
  default     = "oficina"
}

variable "db_usuario" {
  description = "Usuário master"
  type        = string
  default     = "oficina"
}
