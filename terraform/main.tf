################################################################################
# EKS cluster + one managed node group (nodes in the PRIVATE subnets)
#
# The terraform-aws-modules/eks module provisions, among other things:
#   - the EKS CLUSTER IAM role  (policy: AmazonEKSClusterPolicy)
#   - the NODE/instance IAM role for the managed node group
#       (AmazonEKSWorkerNodePolicy + AmazonEKS_CNI_Policy + AmazonEC2ContainerRegistryReadOnly)
#   - the OIDC provider (enable_irsa), the cluster security group, and the
#     core add-ons (coredns, kube-proxy, vpc-cni).
# So both IAM roles the assignment needs are created here, with the cluster.
#
# Node placement (var.nodes_in_public_subnets, default = true):
#   - PUBLIC subnets (default) => egress via the existing IGW, so NO NAT Gateway is
#     needed and the cluster is apply-ready as-is.
#   - PRIVATE subnets => create a NAT Gateway MANUALLY before `apply` (see README),
#     else nodes can't pull images or join.
# NOT created here (by design): AWS Load Balancer Controller IAM, ECR -> later phases.
################################################################################

locals {
  # Where the worker nodes run:
  #   public  => egress via the IGW, so NO NAT Gateway is needed (saves ~$33/mo)
  #   private => needs a NAT Gateway (created manually) for image pulls / cluster join
  node_subnet_ids = var.nodes_in_public_subnets ? var.public_subnet_ids : var.private_subnet_ids
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Public endpoint => kubectl/helm from this laptop works.
  # Private endpoint => nodes in private subnets reach the API server inside the VPC.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Use the pre-existing, manually-created VPC.
  # Control-plane ENIs need >=2 AZs, so both private subnets are handed to the cluster.
  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids

  # OIDC provider for IRSA (kept on for future use; EBS CSI below uses Pod Identity).
  enable_irsa = true

  # The IAM principal running `terraform apply` (adminUser) is granted cluster-admin
  # via an EKS access entry => kubectl works immediately, no aws-auth editing.
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }

    # EBS CSI driver — REQUIRED later for the Prometheus/Grafana PersistentVolume.
    # Its AWS permissions are granted via the Pod Identity association in ebs-csi.tf
    # (so no service_account_role_arn here, which also avoids a module<->role cycle).
    aws-ebs-csi-driver = { most_recent = true }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = var.node_ami_type
      instance_types = [var.node_instance_type]
      capacity_type  = var.node_capacity_type
      disk_size      = var.node_disk_size

      # Pin the node group to a SINGLE subnet / AZ. The Prometheus EBS volume is
      # AZ-locked; a node replacement in another AZ could not re-attach it.
      # Default = public subnet => IGW egress, no NAT Gateway. (The public subnets have
      # auto-assign public IPv4 enabled, which AWS requires for managed nodes in public
      # subnets.) Flip var.nodes_in_public_subnets to false to use private + NAT.
      subnet_ids = [local.node_subnet_ids[0]]

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      labels = {
        workload = "hello-world"
      }
    }
  }

  tags = {
    Project = "hello-world-on-eks"
  }
}
