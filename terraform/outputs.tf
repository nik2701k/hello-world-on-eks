output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN (for IRSA-based roles)."
  value       = module.eks.oidc_provider_arn
}

output "cluster_iam_role_arn" {
  description = "IAM role assumed by the EKS control plane."
  value       = module.eks.cluster_iam_role_arn
}

output "node_group_iam_role_arn" {
  description = "IAM role attached to the managed node group's instances."
  value       = try(module.eks.eks_managed_node_groups["default"].iam_role_arn, null)
}

output "ebs_csi_role_arn" {
  description = "IAM role used by the EBS CSI driver (via Pod Identity)."
  value       = aws_iam_role.ebs_csi.arn
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --profile ${var.aws_profile}"
}
