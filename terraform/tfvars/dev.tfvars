region             = "ap-south-1"
aws_profile        = "project"
cluster_name       = "hello-world-eks"
kubernetes_version = "1.35"

# Network config
vpc_id = "vpc-0406ef03cbd3dab63"

private_subnet_ids = [
  "subnet-06080b290e0e2772b",
  "subnet-005cd8840ec62a3c9",
]

public_subnet_ids = [
  "subnet-0e628d737e0f1ea40",
  "subnet-05d9449b27ab98024",
]

# Node group
nodes_in_public_subnets = true
node_instance_type      = "t4g.large"
node_ami_type           = "AL2023_ARM_64_STANDARD"
node_capacity_type      = "ON_DEMAND"
node_disk_size          = 20
node_min_size           = 1
node_desired_size       = 1
node_max_size           = 2

# Tags
tags = {
  Project     = "hello-world-on-eks"
  Environment = "dev"
  ManagedBy   = "terraform"
}
