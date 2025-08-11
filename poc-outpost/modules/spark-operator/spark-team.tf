locals {
  teams = var.spark_teams
}

resource "kubernetes_namespace_v1" "spark_team" {
  for_each = toset(local.teams)

  metadata {
    name = each.value
  }

  lifecycle {
    ignore_changes = [metadata]
    prevent_destroy = true
  }
}

resource "kubernetes_service_account_v1" "spark_team" {
  for_each = toset(local.teams)

  metadata {
    name        = each.value
    namespace   = kubernetes_namespace_v1.spark_team[each.key].metadata[0].name
    annotations = { "eks.amazonaws.com/role-arn" : module.spark_team_irsa[each.key].iam_role_arn }
  }

  automount_service_account_token = true
}

resource "kubernetes_secret_v1" "spark_team" {
  for_each = toset(local.teams)

  metadata {
    name      = "${each.value}-secret"
    namespace = kubernetes_namespace_v1.spark_team[each.key].metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name"      = kubernetes_service_account_v1.spark_team[each.key].metadata[0].name
      "kubernetes.io/service-account.namespace" = kubernetes_namespace_v1.spark_team[each.key].metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "aws_iam_policy" "spark" {
  description = "IAM role policy for Spark Job execution"
  name_prefix = "${local.name}-spark-irsa"
  policy      = data.aws_iam_policy_document.spark_operator.json
}

resource "aws_iam_policy" "spark_team_data" {
  for_each = toset(local.teams)
  description = "IAM role policy for Spark Job execution"
  name_prefix = "${local.name}-spark-data-irsa"
  policy      = data.aws_iam_policy_document.spark_operator_data_team[each.value].json
}

resource "aws_iam_policy" "spark_team_utility" {
  for_each = toset(local.teams)
  description = "IAM role policy for Spark Job execution"
  name_prefix = "${local.name}-spark-utility-irsa"
  policy      = data.aws_iam_policy_document.spark_operator_utility_team[each.value].json
}

resource "aws_iam_policy" "s3tables" {
  description = "IAM role policy for S3 Tables Access from Spark Job execution"
  name_prefix = "${local.name}-s3tables-irsa"
  policy      = data.aws_iam_policy_document.s3tables_policy.json
}

resource "kubernetes_cluster_role" "spark_role" {
  metadata {
    name = "spark-cluster-role"
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["namespaces", "nodes", "persistentvolumes"]
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "deletecollection", "annotate", "patch", "label"]
    api_groups = [""]
    resources  = ["serviceaccounts", "services", "configmaps", "events", "pods", "pods/log", "persistentvolumeclaims"]
  }

  rule {
    verbs      = ["create", "patch", "delete", "watch"]
    api_groups = [""]
    resources  = ["secrets"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
    api_groups = ["extensions"]
    resources  = ["ingresses"]
  }

  rule {
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "deletecollection", "annotate", "patch", "label"]
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
  }

  depends_on = [module.spark_team_irsa]
}

resource "kubernetes_cluster_role_binding" "spark_role_binding" {
  for_each = toset(local.teams)

  metadata {
    name = "spark-cluster-role-bind-${each.value}"
  }

  subject {
    kind      = "ServiceAccount"
    name      = each.value
    namespace = each.value
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.spark_role.id
  }

  depends_on = [module.spark_team_irsa]
}

module "spark_team_irsa" {
  for_each = toset(local.teams)

  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.1"

  create_release = false
  create_role    = true
  role_name      = "${local.name}-${each.value}"
  create_policy  = false
  role_policies = {
    spark_team_policy = aws_iam_policy.spark.arn,
    spark_team_data_policy = aws_iam_policy.spark_team_data[each.value].arn
    spark_team_utility_policy = aws_iam_policy.spark_team_utility[each.value].arn
    s3tables_policy   = aws_iam_policy.s3tables.arn
  }

  oidc_providers = {
    this = {
      provider_arn    = local.oidc_provider_arn
      namespace       = each.value
      service_account = each.value
    }
  }

}

#---------------------------------------------------------------
# S3 bucket for Spark data
#---------------------------------------------------------------
#tfsec:ignore:*
module "s3_bucket_data_team" {
  for_each = toset(local.teams)
  source  = "../s3-bucket-outpost"

  bucket_name = "${local.name}-spark-data-${each.value}"
  vpc-id      = local.vpc_id
  outpost_name = local.outpost_name
  output_subnet_id = local.output_subnet_id
  vpc_id = local.vpc_id

  tags = local.tags
}

#---------------------------------------------------------------
# IAM policy for Spark data team
#---------------------------------------------------------------
data "aws_iam_policy_document" "spark_operator_data_team" {
  for_each = toset(local.teams)
  statement {
    sid       = ""
    effect    = "Allow"
    resources = [
      "${module.s3_bucket_data_team[each.key].s3_access_arn}",
      "${module.s3_bucket_data_team[each.key].s3_access_arn}/*",
    ]

    actions = [
      "s3-outposts:GetObject",
      "s3-outposts:PutObject",
      "s3-outposts:DeleteObject",
      "s3-outposts:ListBucket"
    ]
  }
  statement {
    sid       = ""
    effect    = "Allow"
    resources = [
      "${module.s3_bucket_data_team[each.key].s3_bucket_arn}",
      "${module.s3_bucket_data_team[each.key].s3_bucket_arn}/*"
    ]

    actions = [
      "s3-outposts:GetObject",
      "s3-outposts:PutObject",
      "s3-outposts:DeleteObject",
      "s3-outposts:ListBucket"
    ]
  }
}

#---------------------------------------------------------------
# S3 bucket for Spark team utility (jar, conf, ..)
#---------------------------------------------------------------
#tfsec:ignore:*
module "s3_bucket_utility_team" {
  for_each = toset(local.teams)
  source  = "../s3-bucket-outpost"

  bucket_name = "${local.name}-spark-util-${each.value}"
  vpc-id      = local.vpc_id
  outpost_name = local.outpost_name
  output_subnet_id = local.output_subnet_id
  vpc_id = local.vpc_id

  tags = local.tags
}

#---------------------------------------------------------------
# IAM policy for Spark team utility (jar, conf, ..)
#---------------------------------------------------------------
data "aws_iam_policy_document" "spark_operator_utility_team" {
  for_each = toset(local.teams)
  statement {
    sid       = ""
    effect    = "Allow"
    resources = [
      "${module.s3_bucket_utility_team[each.key].s3_access_arn}",
      "${module.s3_bucket_utility_team[each.key].s3_access_arn}/*",
    ]

    actions = [
      "s3-outposts:GetObject",
      "s3-outposts:PutObject",
      "s3-outposts:DeleteObject",
      "s3-outposts:ListBucket"
    ]
  }
  statement {
    sid       = ""
    effect    = "Allow"
    resources = [
      "${module.s3_bucket_utility_team[each.key].s3_bucket_arn}",
      "${module.s3_bucket_utility_team[each.key].s3_bucket_arn}/*"
    ]

    actions = [
      "s3-outposts:GetObject",
      "s3-outposts:PutObject",
      "s3-outposts:DeleteObject",
      "s3-outposts:ListBucket"
    ]
  }
}

resource "kubectl_manifest" "s3_user_client" {
  for_each = toset(local.teams)
  yaml_body = templatefile("${path.module}/helm-values/s3.yaml", {
    sa_name = kubernetes_service_account_v1.spark_team[each.key].metadata[0].name
    namespace = kubernetes_namespace_v1.spark_team[each.key].metadata[0].name
    s3_bucket_name = module.s3_bucket_data_team[each.key].s3_bucket_id
  })

}