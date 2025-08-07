## 

Permet de créer un rôle (ou de le mettre à jour) avec les policies adéquates dans AWS et d'annoter au besoin le SA dans le namespae cible

Utilisé pour donné un accès des pods (utilisant un SA donné dans EKS) à un ou des buckets sur l'outpost.

Usage : 
```bash
Usage:
  irsa-tool [flags]

Flags:
      --buckets string           Comma-separated list of Outpost bucket ARNs
  -h, --help                     help for irsa-tool
      --namespace string         Kubernetes namespace
      --oidc-provider string     OIDC provider URL (e.g., oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED)
      --region string            AWS region (default "us-west-2")
      --service-account string   Kubernetes ServiceAccount name
```

Pour récupérer l'OIDC provider, avec votre compte AWS : 
```bash
aws eks describe-cluster --name poc-orange-doeks-otl4 --region us-west-2 --query "cluster.identity.oidc.issuer" --output text
```

Prévoir avant le lancement :

* D'être sur le bon contexte Kubernetes
* D'avoir bien exporté les variables AWS "AWS_ACCESS_KEY_ID","AWS_SECRET_ACCESS_KEY" et "AWS_SESSION_TOKEN"

Une version linux et windows de ce code sont dans le répertoire binaries