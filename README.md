# hello-world-on-eks

A small Hello World service running on Amazon EKS. The repository holds the Terraform that provisions the cluster, the Go application, and the Helm chart used to deploy it.

## Terraform (EKS infrastructure)

The `terraform/` directory provisions the EKS cluster and everything the workload needs to run on it. Resources are created in region `ap-south-1` using the `project` AWS named profile.

### What it provisions

- An EKS cluster (Kubernetes `1.35`), built on the `terraform-aws-modules/eks/aws` module, with both public and private API endpoint access enabled.
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

## Helm chart

The `helm/hello-world-eks/` chart deploys the application to the cluster. There is no default `values.yaml`; environment values live under `values/` and must be passed explicitly with `-f`.

### What it deploys

- **Deployment** — runs the app image with liveness, readiness, and startup probes (all HTTP `GET /healthz`).
- **Service** — type `LoadBalancer`, which provisions an internet-facing AWS Classic Load Balancer and exposes the app on port 80.
- **ServiceAccount** for the pods.
- **HorizontalPodAutoscaler** — scales the Deployment between 1 and 2 replicas at 80% CPU (relies on metrics-server, which the Terraform installs as a cluster add-on).
- **PodDisruptionBudget** — keeps at least one pod available during voluntary disruptions.
- **Ingress** — included but disabled by default.

### Per-environment values

`values/dev.yaml` and `values/prod.yaml` are complete, in-sync values files (image, resources, probes, autoscaling, PDB). Pass one with `-f`.

### Usage

```bash
helm upgrade --install hello-world helm/hello-world-eks \
  -f helm/hello-world-eks/values/dev.yaml
```

## CI/CD

A GitHub Actions workflow (`.github/workflows/build.yaml`) builds the container image and pushes it to ECR on every merge to `main` (it also triggers on changes under `app/` and `helm/`, and supports manual `workflow_dispatch`).

It authenticates to AWS with **GitHub OIDC** — no long-lived AWS keys are stored. The workflow assumes an IAM role via OIDC:

- Role ARN: `arn:aws:iam::826784631306:role/github-actions-hello-world-eks`
- OIDC provider: `token.actions.githubusercontent.com`; trust scoped to this repository (`repo:nik2701k/hello-world-on-eks:*`), audience `sts.amazonaws.com`.
- Permissions: push to the `hello-world` ECR repository (ECR auth + layer upload + PutImage).

The role ARN, ECR registry, and repository are supplied via repository **secrets** — `AWS_ROLE_ARN`, `ECR_REGISTRY`, `ECR_REPOSITORY`.

Steps: assume the role (OIDC) → log in to ECR → build the `linux/arm64` image (QEMU + Buildx) → push tags `<git-sha>` and `latest`. This covers the **CI** (build + publish) half; the CD (deploy) part is not wired up yet.
