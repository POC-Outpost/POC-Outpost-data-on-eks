
variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name of the VPC and EKS Cluster"
  type        = string
  default     = "poc-orange-doeks-otl4"
}

variable "outpost_name" {
  description = "Name of the Outpost"
  type        = string
  default     = "OTL4"
}

# VPC
variable "vpc_cidr" {
  description = "VPC CIDR. This should be a valid private (RFC 1918) CIDR range"
  default     = "10.3.0.0/16"
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.32"
}

variable "default_node_group_type" {
  description = "Default node group type for the EKS cluster"
  type        = string
  default     = "doeks"
}

variable "hosted_zone_id" {
  description = "Hosted Zone ID Route53"
  type        = string
  default     = "Z05779363BJIUL4KDL4V1"
}

# Liste des noms de domaine à enregistrer dans Route53 pointant vers le LB Network ciblant l'ingress controller ISTIO
variable "domaine_name_route53" {
  description = "Liste des noms de domaine a enregistrer dans Route53"
  default = [
    "albtest-otl4.orange-eks.com",
    "trinoalb4.orange-eks.com",
    "airflowalb4.orange-eks.com",
    "nifi2-otl4.orange-eks.com",
    "supersetalb4.orange-eks.com",
    "grafanaalb4.orange-eks.com",
    "sparkhistoryalb4.orange-eks.com",
  ]
  type = list(string)
}

variable "domaine_name_route53_gw_kf" {
  description = "Liste des noms de domaine a enregistrer dans Route53 sur l'ingress gateway Kubeflow"
  default = [
    "kubeflow-otl4.orange-eks.com",
  ]
  type = list(string)
}

variable "enable_amazon_prometheus" {
  description = "Enable Amazon Prometheus for monitoring"
  type        = bool
  default     = false
}

variable "enable_amazon_grafana" {
  description = "Enable Amazon Grafana for monitoring"
  type        = bool
  default     = false
}

variable "enable_airflow" {
  description = "Enable Apache Airflow"
  type        = bool
  default     = true
}

variable "enable_trino" {
  description = "Enable Trino"
  type        = bool
  default     = true
}

variable "enable_kafka" {
  description = "enable Kafka cluster"
  type        = bool
  default     = true
}

variable "enable_spark_operator" {
  description = "Enable Spark Operator"
  type        = bool
  default     = true
}

# Desable Karpenter by default, as it requires more node and outpost does not have enough resources
variable "enable_karpenter" {
  description = "Enable Karpenter for node management"
  type        = bool
  default     = false
}

variable "enable_superset" {
  description = "Enable Apache Superset"
  type        = bool
  default     = true
}

variable "enable_s3_user" {
    description = "Enable S3 User for data access"
    type        = bool
    default     = true
}

variable "cluster_issuer_name" {
  description = "Name of the cluster issuer for cert-manager"
  type        = string
  default     = "letsencrypt-http-private"
}

variable "main_domain" {
  description = "Main domain for the cluster"
  type        = string
  default     = "orange-eks.com"
}

# Access Entries for Cluster Access Control
variable "access_entries" {
  description = <<EOT
Map of access entries to be added to the EKS cluster. This can include IAM users, roles, or groups that require specific access permissions (e.g., admin access, developer access) to the cluster.
The map should follow the structure:
{
  "role_arn": "arn:aws:iam::123456789012:role/AdminRole",
  "username": "admin"
}
EOT
  type        = any
  default     = {}
}

# KMS Key Admin Roles
variable "kms_key_admin_roles" {
  description = <<EOT
A list of AWS IAM Role ARNs to be added to the KMS (Key Management Service) policy. These roles will have administrative permissions to manage encryption keys used for securing sensitive data within the cluster.
Ensure that these roles are trusted and have the necessary access to manage encryption keys.
EOT
  type        = list(string)
  default     = []
}

variable "spark_teams" {
  description = "List of all teams (namespaces) for spark team"
  type        = list(string)
  default     = ["spark-team-a", "spark-team-b", "spark-team-c"]
}

variable "keycloak_url" {
  type        = string
  description = "Url keycloak"
  default     = "keycloak-otl4.orange-eks.com"
}

variable "client_keycloak_nifi" {
  type        = string
  description = "Client keycloak Nifi"
  default     = "nifi2"
}

variable "secret_keycloak_nifi" {
  type        = string
  description = "Secret keycloak Nifi"
}

variable "airflow_oidc_secret" {
  type        = string
  description = "Secret keycloak Airflow"
}

variable "dex_client_secret" {
  type        = string
  description = "Secret pour DEX"
}

variable "apply_nifi2" {
  type        = bool
  description = "Indicate if new nifi2 module must be applied"
  default     = false
}

variable "client_keycloak_spark_history" {
  type        = string
  description = "Client keycloak Spark History Server"
  default     = "sparkhistory"
}

variable "secret_keycloak_spark_history" {
  type        = string
  description = "Secret keycloak Spark History Server"
}

variable "keycloak_orange_issuer_url" {
  type        = string
  description = "Keycloak Orange issuer URL"
  default     = "https://keycloak-otl4.orange-eks.com/realms/orange-eks"
}

variable "secret_keycloak_superset" {
  type        = string
  description = "Secret keycloak Superset"
}

variable "client_keycloak_superset" {
  type        = string
  description = "Client keycloak Superset"
  default     = "superset"
}

variable "secret_keycloak_grafana" {
  type        = string
  description = "Secret keycloak Grafana"
}

variable "client_keycloak_grafana" {
  type        = string
  description = "Client keycloak Grafana"
  default     = "grafana"
}