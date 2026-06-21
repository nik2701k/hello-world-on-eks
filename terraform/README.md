# Terraform — EKS cluster

Provisions the EKS control plane + one managed node group (nodes in the **private**
subnets) into the **pre-existing, manually-created VPC** (`vpc-0406ef03cbd3dab63`,
ap-south-1). Uses the `project` AWS profile only.

## What this creates

- **EKS cluster** `hello-world-eks` (public + private API endpoint).
- **EKS cluster IAM role** (`AmazonEKSClusterPolicy`) and the **node IAM role**
  (`AmazonEKSWorkerNodePolicy` + `AmazonEKS_CNI_Policy` + `AmazonEC2ContainerRegistryReadOnly`)
  — both via the EKS module.
- **One managed node group**: `1× t4g.large` (ARM/AL2023), `ON_DEMAND`, pinned to a
  single subnet/AZ (so the future Prometheus EBS volume can always re-attach).
  **Default placement = PUBLIC subnets** (`nodes_in_public_subnets = true`) → egress via
  the IGW, **no NAT Gateway needed**.
- **Add-ons**: `coredns`, `kube-proxy`, `vpc-cni`, `eks-pod-identity-agent`, and
  **`aws-ebs-csi-driver`** (needed later by Prometheus/Grafana storage).
- **EBS CSI IAM role** bound via **EKS Pod Identity** (`AmazonEBSCSIDriverPolicy`).
- OIDC provider (IRSA), cluster security group — via the module.

## Environments

Inputs live in `tfvars/`:

- `tfvars/dev.tfvars` — the values used for this project.
- `tfvars/prod.tfvars` — a blank template mirroring `dev` (fill in before use).

Files in `tfvars/` are not auto-loaded, so pass one explicitly with `-var-file`.

## Usage

```sh
cd terraform
AWS_PROFILE=project terraform init
AWS_PROFILE=project terraform plan  -var-file=tfvars/dev.tfvars   # control plane ~$0.10/hr
AWS_PROFILE=project terraform apply -var-file=tfvars/dev.tfvars   # ~10–15 min
$(AWS_PROFILE=project terraform output -raw configure_kubectl)    # set up kubectl
kubectl get nodes
```

## Remote state

State is stored in **S3** with **native S3 state locking** (`use_lockfile = true`, no DynamoDB),
configured in `backend.tf`:

- Bucket: `terraform-state-826784631306` (ap-south-1, versioned + encrypted), created out of band.
- Key: `hello-world-eks/terraform.tfstate`.

`terraform init` reads the backend automatically.
