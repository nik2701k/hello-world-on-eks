locals {
  node_subnet_ids = var.nodes_in_public_subnets ? var.public_subnet_ids : var.private_subnet_ids
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids

  enable_irsa = true

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent          = true
      configuration_values = jsonencode({ replicaCount = 1 })
    }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    aws-ebs-csi-driver = {
      most_recent          = true
      configuration_values = jsonencode({ controller = { replicaCount = 1 } })
    }
    metrics-server = {
      most_recent = true
      # Default add-on port is 10251, which the EKS node security group does not
      # open from the control plane, so API aggregation/discovery times out and
      # the HPA reports cpu <unknown>. 4443 is already opened by the EKS-managed
      # node SG rule for metrics-server.
      configuration_values = jsonencode({ replicas = 1, containerPort = 4443 })
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = var.node_ami_type
      instance_types = [var.node_instance_type]
      capacity_type  = var.node_capacity_type
      disk_size      = var.node_disk_size

      subnet_ids = [local.node_subnet_ids[0]]

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      labels = {
        workload = "hello-world"
      }
    }
  }
}
