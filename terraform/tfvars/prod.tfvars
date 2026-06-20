# ─────────────────────────────────────────────────────────────────────────────
# PROD environment — TEMPLATE ONLY (not used in this project; we use dev.tfvars).
# Exact structural replica of dev.tfvars with values left unset (null).
# Fill in every value before using:  terraform apply -var-file=tfvars/prod.tfvars
# ─────────────────────────────────────────────────────────────────────────────

# --- General ---
region             = null
aws_profile        = null
cluster_name       = null
kubernetes_version = null

# --- Existing network (created manually via AWS CLI) ---
vpc_id = null

private_subnet_ids = null

public_subnet_ids = null

# --- Node group ---
nodes_in_public_subnets = null
node_instance_type      = null
node_ami_type           = null
node_capacity_type      = null
node_disk_size          = null
node_min_size           = null
node_desired_size       = null
node_max_size           = null
