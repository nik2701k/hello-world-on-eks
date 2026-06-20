################################################################################
# EBS CSI driver permissions (via EKS Pod Identity)
#
# Needed so the aws-ebs-csi-driver add-on can create/attach EBS volumes — required
# in a later phase by the Prometheus (and any Grafana) PersistentVolumeClaim. Without
# it, those PVCs stay Pending.
#
# We use EKS Pod Identity (not IRSA): the role trusts the static service principal
# pods.eks.amazonaws.com, so it does NOT depend on the cluster OIDC output. That
# breaks the dependency cycle with the add-on declared inside module.eks.
################################################################################

resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = {
    Project = "hello-world-on-eks"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Bind the role to the driver's service account (kube-system/ebs-csi-controller-sa).
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}
