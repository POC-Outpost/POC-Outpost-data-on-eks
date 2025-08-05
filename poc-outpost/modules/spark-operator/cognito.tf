resource "aws_cognito_user_pool_client" "shs" {
  name                   = "shs-client"
  user_pool_id           = local.cognito_user_pool_id
  generate_secret        = true
  allowed_oauth_flows    = ["code"]
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_scopes   = ["openid", "email"]
  callback_urls          = ["https://${local.spark_history_server_name}.${local.main_domain}/callback"]
  allowed_oauth_flows_user_pool_client = true

  access_token_validity  = 60     # minutes
  id_token_validity      = 60     # minutes
  refresh_token_validity = 30     # days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# using keycloak instead of Cognito
resource "helm_release" "oauth2_proxy" {
  name             = "oauth2-proxy"
  namespace        = local.spark_history_server_namespace
  create_namespace = true
  repository       = "https://oauth2-proxy.github.io/manifests"
  chart            = "oauth2-proxy"
  version          = "7.15.0"

  values = [
    yamlencode({
          # annotations = {
          #   "sidecar.istio.io/inject" = "false"
          # }
          config = {

            clientID       = "${local.client_keycloak_spark_history}"
            clientSecret   = "${local.secret_keycloak_spark_history}"
            cookie_secret = "${base64encode(random_password.cookie_secret.result)}"
            cookieSecure   = true
            oidcIssuerURL  = "${local.keycloak_orange_issuer_url}"
            cookie_samesite = "lax"

          }
          service = {
            type = "ClusterIP"
          }
          extraArgs = {
            "cookie-secure" = "true"
            "cookie-samesite" = "lax"
            "skip-provider-button" = true
            "ssl-insecure-skip-verify" = false
          }
        }),

    <<-EOT
      config:
        configFile: |
          provider = "oidc"
          oidc_issuer_url = "${local.keycloak_orange_issuer_url}"
          redirect_url = "https://${local.spark_history_server_name}.${local.main_domain}/oauth2/callback"
          email_domains = [ "*" ]
          scope = "openid email profile"
          cookie_samesite = "lax"
          upstreams = [ "http://spark-history-server.${local.spark_history_server_namespace}.svc.cluster.local:80" ]
          pass_access_token = true
          pass_authorization_header = true
          pass_user_headers = true
          set_authorization_header = true

          cookie_domains = "${local.spark_history_server_name}.${local.main_domain}"
          cookie_refresh = "2m"
          cookie_expire = "24h"

      service:
        type: ClusterIP
    EOT
      ]
    }

resource "random_password" "cookie_secret" {
  length  = 16
  special = false
}