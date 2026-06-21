# hello-world-on-eks

A small Hello World service running on Amazon EKS. The repository holds the Terraform that provisions the cluster, the Go application, and the Helm chart used to deploy it.

## Running end-to-end

The stack is brought up in the order below; each step is detailed in the section that follows (and in [terraform/README.md](terraform/README.md) and [monitoring/README.md](monitoring/README.md)). All AWS commands use the `project` profile and region `ap-south-1`.

**Prerequisites** — provisioned out of band (not in this Terraform): a VPC with public and private subnets, an ECR repository, the S3 bucket used for Terraform state, the GitHub Actions OIDC IAM role with an EKS access entry, and the `app` namespace.

1. **Provision the cluster:** `cd terraform && terraform init && terraform apply -var-file=tfvars/dev.tfvars`
2. **Point kubectl at the cluster:** `aws eks update-kubeconfig --name hello-world-eks --region ap-south-1 --profile project`
3. **Build and push the image** to ECR — `docker buildx build --platform linux/arm64 ...` — or push to `main` and let CI build it.
4. **Deploy the app:** `helm upgrade --install hello-world helm/hello-world-eks -n app -f helm/hello-world-eks/values/dev.yaml`
5. **Install monitoring:** follow [monitoring/README.md](monitoring/README.md).

After the initial setup, a push to `main` triggers CI (build + push to ECR) and then CD (`helm upgrade`) automatically.

## Terraform (EKS infrastructure)

The `terraform/` directory provisions the EKS cluster and everything the workload needs to run on it. Resources are created in region `ap-south-1` using the `project` AWS named profile.

### What it provisions

- An EKS cluster (Kubernetes `1.35`), built on the `terraform-aws-modules/eks/aws` module, with both public and private API endpoint access enabled.
- One EKS managed node group (`default`) running ARM Graviton `t4g.large` instances on the `AL2023_ARM_64_STANDARD` AMI, on-demand capacity, with a 20 GiB root volume. It scales between a minimum of 1 and a maximum of 2 nodes (desired 1).
- The cluster IAM role for the control plane and the node IAM role for the managed node group (both created by the module).
- Cluster add-ons: CoreDNS, kube-proxy, VPC CNI, the EKS Pod Identity agent, the AWS EBS CSI driver, and metrics-server (the last three run a single replica for this dev setup). The EBS CSI driver gets a dedicated IAM role (`ebs-csi.tf`) that is bound to the `kube-system/ebs-csi-controller-sa` service account through an EKS Pod Identity association.

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

The `helm/hello-world-eks/` chart deploys the application into the `app` namespace. There is no default `values.yaml`; environment values live under `values/` and must be passed explicitly with `-f`.

### What it deploys

- **Deployment** — runs the app image with liveness, readiness, and startup probes (all HTTP `GET /healthz`).
- **Service** — type `LoadBalancer`, which provisions an internet-facing AWS Classic Load Balancer and exposes the app on port 80.
- **ServiceAccount** for the pods.
- **HorizontalPodAutoscaler** — scales the Deployment between 1 and 2 replicas at 80% CPU (relies on metrics-server, which the Terraform installs as a cluster add-on).
- **PodDisruptionBudget** — keeps at least one pod available during voluntary disruptions.
- **Ingress** — included but disabled by default.

### Per-environment values

`values/dev.yaml` and `values/prod.yaml` are complete, in-sync values files (namespace, image, resources, probes, autoscaling, PDB). The image `tag` is a `<VERSION>` placeholder that the deploy workflow replaces with the built commit SHA. Pass one with `-f`.

### Usage

```bash
helm upgrade --install hello-world helm/hello-world-eks \
  -n app -f helm/hello-world-eks/values/dev.yaml
```

## CI/CD

Two GitHub Actions workflows authenticate to AWS with **GitHub OIDC** (no long-lived keys) by assuming the IAM role `arn:aws:iam::826784631306:role/github-actions-hello-world-eks`. The OIDC trust is scoped to this repository (`repo:nik2701k/hello-world-on-eks:*`, audience `sts.amazonaws.com`). The role can push to the `hello-world` ECR repository and has `eks:DescribeCluster` plus an EKS access entry granting `edit` (`AmazonEKSEditPolicy`) in the `app` namespace. The role ARN, ECR registry, and repository come from repository **secrets** (`AWS_ROLE_ARN`, `ECR_REGISTRY`, `ECR_REPOSITORY`).

### CI — `build.yaml`

On merge to `main` (changes under `app/`, `helm/`, or the workflow) or manual `workflow_dispatch`: assume the role → log in to ECR → build the `linux/arm64` image (QEMU + Buildx) → push tags `<git-sha>` and `latest`.

### CD — `deploy.yaml`

Runs automatically after a successful `build-and-push` run (`workflow_run` trigger): assume the role → `aws eks update-kubeconfig` → substitute the image tag (replace the `<VERSION>` placeholder in `values/dev.yaml` with the built commit SHA) → `helm upgrade --install` into the `app` namespace and wait for the rollout.

## Monitoring

Prometheus and Grafana monitoring is documented in [monitoring/README.md](monitoring/README.md).

## Known limitations and notes

- **Out-of-band resources.** The VPC and subnets, the internet gateway and route tables, the ECR repository, the S3 bucket used for Terraform state, and the GitHub Actions OIDC IAM role with its EKS access entry are created manually via the AWS CLI — they are not managed by this Terraform. The Terraform assumes they already exist (the VPC and subnet IDs are set in `tfvars`), and the `app` namespace is created manually before deploying. A from-scratch run must create these first.
- **Cost-optimized, not highly available.** A single `t4g.large` node pinned to one Availability Zone; `metrics-server`, the EBS CSI controller, and CoreDNS each run a single replica; worker nodes run in public subnets without a NAT gateway (they receive public IPs, and the node security group is restricted).
- **HTTP only (no TLS).** The application and Grafana are exposed via Classic Load Balancers over HTTP, chosen for this short-lived demo. A production setup would terminate HTTPS (an ACM certificate) on an ALB or NLB.
- **CD scope.** The deploy workflow assumes the cluster and `app` namespace already exist; it deploys the application but does not create the cluster or namespace.
- **CD environments.** GitHub Actions CD currently deploys to dev only; a feature to deploy to prod — gated by a required manual approval — will be added.
