variable "region" {
  description = "AWS region (all resources)."
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI/SDK named profile to use for every call."
  type        = string
  default     = "project"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "hello-world-eks"
}

variable "kubernetes_version" {
  description = "EKS control-plane Kubernetes version. Use a current STANDARD-support version to avoid the extended-support surcharge."
  type        = string
  default     = "1.32"
}

# --- Existing network (created manually via AWS CLI, NOT managed by this Terraform) ---

variable "vpc_id" {
  description = "ID of the pre-existing VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (2 AZs). Control-plane ENIs span both; the node group is pinned to the first one (single AZ) so the future Prometheus EBS PVC can always re-attach."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (2 AZs). Not used directly by EKS here; reserved for the internet-facing ALB later (already tagged kubernetes.io/role/elb)."
  type        = list(string)
}

# --- Managed node group ---

variable "nodes_in_public_subnets" {
  description = "true => node group runs in the PUBLIC subnets (egress via IGW, NO NAT Gateway needed, nodes get public IPs). false => PRIVATE subnets (requires a manually-created NAT Gateway before apply)."
  type        = bool
  default     = true
}

variable "node_instance_type" {
  description = "Worker instance type. t4g.large = ARM Graviton, 2 vCPU / 8 GiB (cheapest viable for the full stack)."
  type        = string
  default     = "t4g.large"
}

variable "node_ami_type" {
  description = "EKS node AMI type. Must match the instance architecture (ARM => AL2023_ARM_64_STANDARD)."
  type        = string
  default     = "AL2023_ARM_64_STANDARD"
}

variable "node_capacity_type" {
  description = "ON_DEMAND (stable, recommended for an always-on 5-day demo) or SPOT (cheaper, can be reclaimed)."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_disk_size" {
  description = "Root EBS volume size (GiB) per node."
  type        = number
  default     = 20
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  description = "Max nodes. 2 leaves headroom for a rolling node replacement; the steady state is 1."
  type        = number
  default     = 2
}
