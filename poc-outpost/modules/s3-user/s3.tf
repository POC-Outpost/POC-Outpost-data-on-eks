locals {
  s3_user_namespace = "s3-user"
  s3_user_sa        = "s3-user-sa"
  s3_user_name       = "s3-user"
  oidc_provider_arn = var.oidc_provider_arn
}

resource "kubernetes_namespace_v1" "s3_user" {

  metadata {
    name = local.s3_user_namespace
  }

  lifecycle {
    ignore_changes = [metadata]
    prevent_destroy = true
  }
}

resource "kubernetes_service_account_v1" "s3_user" {

  metadata {
    name        = local.s3_user_sa
    namespace   = kubernetes_namespace_v1.s3_user.metadata[0].name
    annotations = { "eks.amazonaws.com/role-arn" : module.s3_user.iam_role_arn }
  }

  automount_service_account_token = true
}

resource "kubernetes_secret_v1" "s3_user" {

  metadata {
    name      = "${local.s3_user_name}-secret"
    namespace = kubernetes_namespace_v1.s3_user.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name"      = kubernetes_service_account_v1.s3_user.metadata[0].name
      "kubernetes.io/service-account.namespace" = kubernetes_namespace_v1.s3_user.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

module "s3_user" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0" # ensure to update this to the latest/desired version

  # IAM role for service account (IRSA)
  create_release = false
  create_policy  = true

  create_role = true
  role_name   = local.s3_user_name

  role_policies = { S3OutpostsFullAccess = "arn:aws:iam::aws:policy/AmazonS3OutpostsFullAccess" }

  oidc_providers = {
    this = {
      provider_arn    = local.oidc_provider_arn
      namespace       = local.s3_user_namespace
      service_account = local.s3_user_sa
    }
  }
}

resource "kubectl_manifest" "s3_user_client" {
  yaml_body = templatefile("${path.module}/helm-values/s3.yaml", {
    sa_name   = local.s3_user_sa
    namespace = local.s3_user_namespace
  })
}