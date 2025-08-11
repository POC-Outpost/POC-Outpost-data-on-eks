#---------------------------------------------------------------
# Patch de l'opérateur Spark
#---------------------------------------------------------------
module "clusterissuer_kubeflow" {
  source = "../kustomize"
  # Variables
  overlayfolder= "${path.module}/kustomize"
  helminstallname ="sparkoperatorpatch"
  namespace = "spark-operator"
  createnamespace = false

  providers = {
    kubernetes = kubernetes
    kustomization = kustomization
    helm = helm
  }
  
  depends_on = [module.eks_data_addons]
}