# hello-world-on-eks

A small Hello World service running on Amazon EKS. The repository holds the Terraform that provisions the cluster, the Go application, and the Helm chart used to deploy it.

## Terraform (EKS infrastructure)

The `terraform/` directory provisions the EKS cluster and everything the workload needs to run on it. Resources are created in region `ap-south-1` using the `project` AWS named profile.

### What it provisions

- An EKS cluster (Kubernetes `1.32`), built on the `terraform-aws-modules/eks/aws` module, with both public and private API endpoint access enabled.
- One EKS managed node group (`default`) running ARM Graviton `t4g.large` instances on the `AL2023_ARM_64_STANDARD` AMI, on-demand capacity, with a 20 GiB root volume. It scales between a minimum of 1 and a maximum of 2 nodes (desired 1).
- The cluster IAM role for the control plane and the node IAM role for the managed node group (both created by the module).
- Cluster add-ons: CoreDNS, kube-proxy, VPC CNI, the EKS Pod Identity agent, and the AWS EBS CSI driver. The EBS CSI driver gets a dedicated IAM role (`ebs-csi.tf`) that is bound to the `kube-system/ebs-csi-controller-sa` service account through an EKS Pod Identity association.

### Node subnet placement

Node placement is configurable through the `nodes_in_public_subnets` variable. When `true` (the default), the node group runs in the public subnets; when `false`, it runs in the private subnets. The control-plane ENIs always span the private subnets.

### Per-environment configuration

Environment-specific values live under `terraform/tfvars/`:

- `dev.tfvars` — the populated development configuration (cluster name `hello-world-eks`, region `ap-south-1`, profile `project`, node sizing, and tags).
- `prod.tfvars` — a template with the same variables left unset, to be filled in for a production environment.

### Usage

```bash
cd terraform

terraform init
terraform apply   -var-file=tfvars/dev.tfvars
terraform destroy -var-file=tfvars/dev.tfvars
```

After apply, the `configure_kubectl` output prints the `aws eks update-kubeconfig` command to point `kubectl` at the new cluster.

## Go application

The `app/` directory holds the Hello World service, written in Go using only the standard library (`net/http`).

### Endpoints

- `GET /` — returns `Hello World`.
- `GET /healthz` — returns HTTP 200; used by the Kubernetes liveness, readiness, and startup probes.

The server listens on port `8080`.

### Container image

`app/Dockerfile` is a multi-stage build:

- The build stage uses the `golang` image to compile a static binary (`CGO_ENABLED=0`), cross-compiled to `linux/arm64` to match the Graviton (`t4g`) worker nodes.
- The final stage is a distroless image (`gcr.io/distroless/static-debian12:nonroot`) containing only the compiled binary — no Go toolchain, shell, or package manager — so the image is small (~14 MB) and runs as a non-root user.

Build the arm64 image:

```bash
docker buildx build --platform linux/arm64 -t <image>:<tag> app/
```
