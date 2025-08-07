package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/spf13/cobra"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

var (
	namespace    string
	saName       string
	bucketStr    string
	bucketList   []string
	oidcProvider string
	region       string
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "irsa-tool",
		Short: "Configure IRSA roles for a given service account and Outposts S3 buckets",
		Run:   run,
	}

	rootCmd.Flags().StringVar(&namespace, "namespace", "", "Kubernetes namespace")
	rootCmd.Flags().StringVar(&saName, "service-account", "", "Kubernetes ServiceAccount name")
	rootCmd.Flags().StringVar(&bucketStr, "buckets", "", "Comma-separated list of Outpost bucket ARNs")
	rootCmd.Flags().StringVar(&oidcProvider, "oidc-provider", "", "OIDC provider URL (e.g., oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED)") // Required
	rootCmd.Flags().StringVar(&region, "region", "us-west-2", "AWS region")

	rootCmd.MarkFlagRequired("namespace")
	rootCmd.MarkFlagRequired("service-account")
	rootCmd.MarkFlagRequired("buckets")
	rootCmd.MarkFlagRequired("oidc-provider")

	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}

func run(cmd *cobra.Command, args []string) {
	ctx := context.TODO()
	bucketList = strings.Split(bucketStr, ",")

	// Charger config Kubernetes
	configk8s, err := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		clientcmd.NewDefaultClientConfigLoadingRules(),
		&clientcmd.ConfigOverrides{}).ClientConfig()
	if err != nil {
		log.Fatalf("failed to get Kubernetes config: %v", err)
	}

	clientset, err := kubernetes.NewForConfig(configk8s)
	if err != nil {
		log.Fatalf("failed to create Kubernetes client: %v", err)
	}

	// Récupérer ServiceAccount
	saClient := clientset.CoreV1().ServiceAccounts(namespace)
	svcAccount, err := saClient.Get(ctx, saName, metav1.GetOptions{})
	if err != nil {
		log.Fatalf("failed to get service account: %v", err)
	}

	var roleName string
	roleArnFromSA := ""
	if svcAccount.Annotations != nil {
		roleArnFromSA = svcAccount.Annotations["eks.amazonaws.com/role-arn"]
	}

	if roleArnFromSA != "" {
		// Extraire le nom du role IAM depuis l'ARN
		roleName = extractRoleNameFromArn(roleArnFromSA)
		log.Printf("Using existing IAM role from ServiceAccount annotation: %s", roleName)
	} else {
		// Pas d'ARN existant, on crée un nouveau roleName
		roleName = fmt.Sprintf("irsa-%s-%s", namespace, saName)
		log.Printf("No IAM role found in annotation, will create or update role: %s", roleName)
	}

	// Charge config AWS
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		log.Fatalf("unable to load AWS SDK config: %v", err)
	}

	iamClient := iam.NewFromConfig(cfg)

	trustPolicy := buildTrustPolicy(oidcProvider, namespace, saName)
	roleArn := createOrUpdateIAMRole(ctx, iamClient, roleName, trustPolicy)

	policyDoc := buildS3Policy(bucketList)
	attachInlinePolicy(ctx, iamClient, roleName, policyDoc)

	// Met à jour l'annotation du SA avec le bon ARN (au cas où nouveau rôle créé)
	if svcAccount.Annotations == nil {
		svcAccount.Annotations = map[string]string{}
	}
	svcAccount.Annotations["eks.amazonaws.com/role-arn"] = roleArn
	_, err = saClient.Update(ctx, svcAccount, metav1.UpdateOptions{})
	if err != nil {
		log.Fatalf("failed to update service account annotation: %v", err)
	}

	log.Printf("Service account %s updated with role ARN: %s", saName, roleArn)
}

func extractRoleNameFromArn(roleArn string) string {
	// Un ARN de rôle IAM a ce format :
	// arn:aws:iam::123456789012:role/role-name
	// On veut extraire la partie après "role/"
	parts := strings.Split(roleArn, ":")
	if len(parts) < 6 {
		return ""
	}
	// La partie "role/role-name" est à l'index 5
	resource := parts[5]
	if strings.HasPrefix(resource, "role/") {
		return strings.TrimPrefix(resource, "role/")
	}
	return ""
}

// Génère la policy de trust pour IRSA
func buildTrustPolicy(oidcProviderURL, namespace, sa string) string {
	provider := fmt.Sprintf("arn:aws:iam::%s:oidc-provider/%s", extractAccountID(oidcProviderURL), oidcProviderURL)
	subject := fmt.Sprintf("system:serviceaccount:%s:%s", namespace, sa)

	return fmt.Sprintf(`{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "%s"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "%s:sub": "%s",
                    "%s:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}`, provider, oidcProviderURL, subject, oidcProviderURL)
}

func buildS3Policy(bucketArns []string) string {
	type Statement struct {
		Sid      string      `json:"Sid,omitempty"`
		Effect   string      `json:"Effect"`
		Action   interface{} `json:"Action"`
		Resource interface{} `json:"Resource"`
	}

	type PolicyDocument struct {
		Version   string      `json:"Version"`
		Statement []Statement `json:"Statement"`
	}

	var statements []Statement

	for _, bucketArn := range bucketArns {
		bucketArn = strings.TrimSpace(bucketArn)
		if bucketArn == "" {
			continue
		}

		// Parse components of the ARN
		parts := strings.Split(bucketArn, "/")
		if len(parts) < 4 {
			log.Fatalf("Invalid bucket ARN: %s", bucketArn)
		}

		// Extract the access point name from the bucket name
		bucketName := parts[len(parts)-1]
		outpostArn := strings.Join(parts[:len(parts)-2], "/") // Remove '/bucket/...'
		accessPointArn := fmt.Sprintf("%s/accesspoint/%s-ap", outpostArn, bucketName)

		actions := []string{
			"s3-outposts:PutObject",
			"s3-outposts:ListBucket",
			"s3-outposts:GetObject",
			"s3-outposts:DeleteObject",
		}

		// Access point policy
		statements = append(statements, Statement{
			Effect: "Allow",
			Action: actions,
			Resource: []string{
				accessPointArn + "/*",
				accessPointArn,
			},
		})

		// Bucket policy
		statements = append(statements, Statement{
			Effect: "Allow",
			Action: actions,
			Resource: []string{
				bucketArn + "/*",
				bucketArn,
			},
		})
	}

	// CloudWatch logs permissions
	logActions := []string{
		"logs:PutLogEvents",
		"logs:DescribeLogStreams",
		"logs:DescribeLogGroups",
		"logs:CreateLogStream",
		"logs:CreateLogGroup",
	}

	logStatement := Statement{
		Effect:   "Allow",
		Action:   logActions,
		Resource: "arn:aws:logs:us-west-2:012046422670:log-group:*",
	}

	statements = append(statements, logStatement)

	// Final policy
	policy := PolicyDocument{
		Version:   "2012-10-17",
		Statement: statements,
	}

	// Marshal
	policyJSON, err := json.MarshalIndent(policy, "", "    ")
	if err != nil {
		log.Fatalf("Failed to marshal policy JSON: %v", err)
	}

	return string(policyJSON)
}

func createOrUpdateIAMRole(ctx context.Context, client *iam.Client, name string, trustPolicy string) string {
	_, err := client.GetRole(ctx, &iam.GetRoleInput{RoleName: aws.String(name)})
	if err != nil {
		log.Printf("Role does not exist, creating: %s", name)
		_, err := client.CreateRole(ctx, &iam.CreateRoleInput{
			RoleName:                 aws.String(name),
			AssumeRolePolicyDocument: aws.String(trustPolicy),
		})
		if err != nil {
			log.Fatalf("failed to create role: %v", err)
		}
	} else {
		log.Printf("Updating trust policy on existing role: %s", name)
		_, err := client.UpdateAssumeRolePolicy(ctx, &iam.UpdateAssumeRolePolicyInput{
			RoleName:       aws.String(name),
			PolicyDocument: aws.String(trustPolicy),
		})
		if err != nil {
			log.Fatalf("failed to update trust policy: %v", err)
		}
	}

	out, _ := client.GetRole(ctx, &iam.GetRoleInput{RoleName: aws.String(name)})
	return *out.Role.Arn
}

func attachInlinePolicy(ctx context.Context, client *iam.Client, roleName string, policy string) {
	_, err := client.PutRolePolicy(ctx, &iam.PutRolePolicyInput{
		RoleName:       aws.String(roleName),
		PolicyName:     aws.String("s3-outposts-access-gopgm"),
		PolicyDocument: aws.String(policy),
	})
	if err != nil {
		log.Fatalf("failed to attach policy: %v", err)
	}
	log.Printf("Inline policy attached to role: %s", roleName)
}

func updateServiceAccountAnnotation(namespace, sa, roleArn string) {
	config, err := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		clientcmd.NewDefaultClientConfigLoadingRules(),
		&clientcmd.ConfigOverrides{}).ClientConfig()
	if err != nil {
		log.Fatalf("failed to get Kubernetes config: %v", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("failed to create Kubernetes client: %v", err)
	}

	saClient := clientset.CoreV1().ServiceAccounts(namespace)
	svcAccount, err := saClient.Get(context.TODO(), sa, metav1.GetOptions{})
	if err != nil {
		log.Fatalf("failed to get service account: %v", err)
	}

	if svcAccount.Annotations == nil {
		svcAccount.Annotations = map[string]string{}
	}

	svcAccount.Annotations["eks.amazonaws.com/role-arn"] = roleArn
	_, err = saClient.Update(context.TODO(), svcAccount, metav1.UpdateOptions{})
	if err != nil {
		log.Fatalf("failed to update service account annotation: %v", err)
	}

	log.Printf("Service account %s updated with role ARN: %s", sa, roleArn)
}

func extractAccountID(oidc string) string {
	// OIDC string format: oidc.eks.<region>.amazonaws.com/id/<id>
	// Account ID must be extracted from IAM caller or hardcoded if needed
	// For now, return a dummy or environment-injected value
	return "012046422670" // <-- Remplace avec une détection ou une variable d'env
}
