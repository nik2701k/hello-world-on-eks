# ─────────────────────────────────────────────────────────────────────────────
# DEV environment — the values used for the ENTIRE project.
# Apply with:  terraform apply -var-file=tfvars/dev.tfvars
# ─────────────────────────────────────────────────────────────────────────────

# --- General ---
region             = "ap-south-1"
aws_profile        = "project"
cluster_name       = "hello-world-eks"
kubernetes_version = "1.32"

# --- Existing network (created manually via AWS CLI) ---
vpc_id = "vpc-0406ef03cbd3dab63"

private_subnet_ids = [
  "subnet-06080b290e0e2772b", # hello-world-private-ap-south-1a (10.0.128.0/20)
  "subnet-005cd8840ec62a3c9", # hello-world-private-ap-south-1b (10.0.144.0/20)
]

public_subnet_ids = [
  "subnet-0e628d737e0f1ea40", # hello-world-public-ap-south-1a (10.0.0.0/20)
  "subnet-05d9449b27ab98024", # hello-world-public-ap-south-1b (10.0.16.0/20)
]

# --- Node group ---
nodes_in_public_subnets = true # public => no NAT Gateway needed
node_instance_type      = "t4g.large"
node_ami_type           = "AL2023_ARM_64_STANDARD"
node_capacity_type      = "ON_DEMAND"
node_disk_size          = 20
node_min_size           = 1
node_desired_size       = 1
node_max_size           = 2
