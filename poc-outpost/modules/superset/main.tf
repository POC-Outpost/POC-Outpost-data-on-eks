
#---------------------------------------------------------------

locals {
  name   = var.name
  region = var.region
  oidc_provider_arn    = var.oidc_provider_arn
  cluster_version = var.cluster_version
  cluster_endpoint = var.cluster_endpoint
  main_domain = var.main_domain
  cluster_issuer_name = var.cluster_issuer_name

  private_subnets_cidr = var.private_subnets_cidr
  vpc_id = var.vpc_id
  db_subnet_group_name = var.db_subnet_group_name
  ec_subnet_group_name = var.ec_subnet_group_name
  security_group_id = var.security_group_id

  superset_namespace = "superset"
  superset_name = "supersetalb4"

  trino_password = var.trino_password
  trino_url = var.trino_url

  secret_keycloak_superset = var.secret_keycloak_superset
  client_keycloak_superset = var.client_keycloak_superset
  keycloak_orange_issuer_url = var.keycloak_orange_issuer_url
  url_part    = split("/", local.keycloak_orange_issuer_url)
  realName = local.url_part[length(local.url_part) - 1]

  tags = var.tags
}

