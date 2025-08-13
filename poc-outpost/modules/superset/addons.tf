resource "random_password" "secret_key" {
  length  = 64
  special = false
  upper            = true
  lower            = true
  numeric          = true
}

module "eks_data_addons" {
  source  = "aws-ia/eks-data-addons/aws"
  version = "~> 1.31.5" # ensure to update this to the latest/desired version

  oidc_provider_arn = local.oidc_provider_arn

  #---------------------------------------
  # AWS Apache Superset Add-on
  #---------------------------------------
  enable_superset = true
  superset_helm_config = {

    name             = "superset"
    repository       = "https://apache.github.io/superset"
    chart            = "superset"
    version = "0.14.2"
    values = [
      templatefile("${path.module}/helm-values/superset-values.yaml", {

        db_user = local.superset_name
        db_pass = try(sensitive(aws_secretsmanager_secret_version.postgres.secret_string), "")
        db_name = try(module.db.db_instance_name, "")
        db_host = try(element(split(":", module.db.db_instance_endpoint), 0), "")

        redis_user = local.superset_name
        redis_host = try(module.elasticache.cluster_cache_nodes[0].address, "failed")

        secret_key = random_password.secret_key.result
        clientID       = "${local.client_keycloak_superset}"
        clientSecret   = "${local.secret_keycloak_superset}"
        oidcIssuerURL  = "${local.keycloak_orange_issuer_url}"

        #connecteurs
        trino_password = local.trino_password
        trino_url = local.trino_url


      })
    ]
  }
}

#---------------------------------------------------------------
# Spark history server Virtual Service qui remplace l'Ingress
#---------------------------------------------------------------

module "virtual_service" {
  source = "../virtualService"

  cluster_issuer_name = local.cluster_issuer_name
  virtual_service_name = local.superset_name
  dns_name = "${local.superset_name}.${local.main_domain}"
  service_name = "superset"
  service_port = 8088
  namespace = local.superset_namespace

  tags = local.tags

  depends_on = [module.eks_data_addons]
}
