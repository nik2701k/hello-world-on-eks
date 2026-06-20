# Terraform — EKS cluster (Phase 1)

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

## Node egress — public (default) vs private+NAT

**Default (`nodes_in_public_subnets = true`): no NAT Gateway, apply-ready.** Nodes run in
the public subnets and egress through the existing IGW (the public subnets have
auto-assign public IPv4 on, which AWS requires for managed nodes in public subnets). The
EKS-managed node security group opens nothing to `0.0.0.0/0`, so the public IP is low-risk
for a demo. Extra cost: ~$0.005/hr per node public IPv4 (~$0.60 / 5 days).

**Only if you set `nodes_in_public_subnets = false`** (private nodes) must you create a NAT
Gateway manually **before `apply`** (kept out of Terraform to avoid early cost):

```sh
# place the NAT in the ap-south-1a PUBLIC subnet (matches the node's AZ -> no cross-AZ data)
EIP=$(aws ec2 allocate-address --domain vpc --profile project --region ap-south-1 --query AllocationId --output text)
NAT=$(aws ec2 create-nat-gateway --subnet-id subnet-0e628d737e0f1ea40 --allocation-id "$EIP" \
      --profile project --region ap-south-1 --query NatGateway.NatGatewayId --output text)
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT" --profile project --region ap-south-1
aws ec2 create-route --route-table-id rtb-020509562d21d5ced --destination-cidr-block 0.0.0.0/0 \
      --nat-gateway-id "$NAT" --profile project --region ap-south-1
```

(NAT cost ≈ $0.045/hr + data ≈ ~$5–6 over 5 days.)

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

## Cost (within the $100 credit; ~$0 out of pocket)

- EKS control plane: **$0.10/hr (~$73/mo)** — bills 24×7 while the cluster exists.
- Node `t4g.large` on-demand: ~$0.0448/hr.
- NAT (manual): ~$0.045/hr. EBS volumes: gp3 $0.08/GiB-mo.
- **5-day estimate ≈ $23–25**, fully covered by the $100 signup credit.

## Teardown (run on day 5)

```sh
# delete Ingress/LoadBalancer Services + EBS PVCs FIRST (so AWS LBs/volumes deprovision)
AWS_PROFILE=project terraform destroy -var-file=tfvars/dev.tfvars
# then, IF you created a NAT Gateway (private mode), delete it + release its EIP; (optionally) the VPC
```

State is **local** (`terraform.tfstate`, gitignored). For team use, switch to an
S3 + DynamoDB backend in `versions.tf`.
