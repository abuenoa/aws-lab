# minishop-platform

**minishop-platform** is a production-style, educational demo that shows a complete DevOps flow:

Terraform → EC2 (Free Tier) → k3s (single-node Kubernetes) → Helm → App deployment

The demo deploys a tiny FastAPI backend and an nginx web frontend to a single `t3.micro` instance.

**What you get**
- AWS infrastructure created by Terraform
- A k3s Kubernetes cluster on EC2
- Helm-based application deployment
- A simple web page calling an internal API
- A local Docker Compose option for quick testing

## Architecture (ASCII)

```
                      +-----------------------+
                      |     Your Browser      |
                      +-----------+-----------+
                                  |
                                  | NodePort :30080
                                  v
+------------------+    +---------+---------+    +------------------+
|   AWS EC2        |    |  k3s Node        |    |   Kubernetes     |
|  t3.micro        |----|  (single node)   |----|   Services       |
|  Security Group  |    |                 |    |                  |
+------------------+    |  Web (nginx)    |    |  ClusterIP API   |
                         |  API (FastAPI) |    +------------------+
                         +----------------+
```

## Prerequisites

- AWS account with Free Tier eligibility
- An existing EC2 key pair
- Terraform installed
- SSH client
- Docker and Docker Compose (for local testing)
- (Optional) AWS CLI installed for `aws configure`

## Execution Model (Local vs EC2)

To avoid confusion, the lab is split into two execution environments:

- **Local machine**: Configure AWS credentials, run `terraform init/apply/destroy`, and (optionally) build/push the API image.
- **EC2 instance**: Install k3s, install Helm, and run `helm install/upgrade` + `kubectl` commands.
- **Image registry**: The API image must be stored in a registry that the EC2 instance can pull from (Docker Hub, GHCR, or ECR).

## Configuration (Externalized Inputs)

This lab avoids hardcoded credentials or IPs. You provide them via environment variables and `.tfvars` files.

**AWS credentials (for Terraform)**  
Use one of these options:

Option A — AWS CLI:
```
aws configure
```

Option B — Environment variables:
```
export AWS_ACCESS_KEY_ID=YOUR_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
export AWS_DEFAULT_REGION=eu-west-1
```

**Terraform variables**

```
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars` with:
- `ssh_key_name`: your EC2 key pair name
- `ssh_cidr`: your public IP in CIDR notation (e.g., `203.0.113.10/32`)
- `instance_type`: instance size (default `t3.micro`)
- `aws_region`: AWS region (e.g., `eu-west-1`)

**Docker Compose (local lab)**

Copy the example environment file:
```
cd <YOUR_REPO>
cp .env.example .env
```

You can override:
- `API_IMAGE`, `API_TAG` for the backend image
- `API_PORT`, `WEB_PORT` for local ports

## Step-by-Step Deployment (Detailed)

### Step 1 — Log in to AWS (Credentials)

You need valid AWS credentials on your machine so Terraform can create resources.
This step gives Terraform permission to provision EC2 and networking.

**Option A: AWS CLI (recommended)**
```
aws configure
```

It will prompt for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `eu-west-1`)
- Output format (you can leave it blank)

**Option B: Environment variables**
```
export AWS_ACCESS_KEY_ID=YOUR_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
export AWS_DEFAULT_REGION=eu-west-1
```

### Step 2 — Set Terraform Variables

Copy the example file and edit it. This tells Terraform which region, key pair,
and instance type to use.
```
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Update these fields in `terraform.tfvars`:
- `aws_region`: region for the EC2 instance
- `ssh_key_name`: the exact name of your EC2 key pair
- `ssh_cidr`: your public IP in CIDR notation (e.g., `X.X.X.X/32`)
- `instance_type`: defaults to `t3.micro` (Free Tier eligible)

### Step 3 — Provision Infrastructure

```
terraform init
terraform apply
```

Terraform will output:
- `instance_public_ip`
- `instance_public_dns`

At this point, the EC2 instance and security group exist, but Kubernetes is not installed yet.

### Step 4 — SSH into the EC2 Instance

```
ssh -i /path/to/your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

If you get a permission error, ensure your `.pem` has correct permissions:
```
chmod 400 /path/to/your-key.pem
```

### Step 4.1 — Clone the repository on the EC2 instance

Install Git and clone the repo (Amazon Linux). This gives the EC2 instance the
bootstrap scripts and Helm chart.
```
sudo yum install -y git
git clone https://github.com/<YOUR_ORG>/<YOUR_REPO>.git
cd <YOUR_REPO>
```

### Step 5 — Install k3s (on the EC2 instance, Amazon Linux 2)

```
cd bootstrap
./install_k3s.sh
```

Verify:
```
kubectl get nodes
```

This installs a single-node Kubernetes cluster so you can run Helm deployments.

This script is Amazon Linux 2 friendly. It:
- Skips the SELinux RPM to avoid `container-selinux` conflicts
- Creates the `kubectl` symlink
- Exports `KUBECONFIG` for the current user

## Troubleshooting (Amazon Linux 2)

If you see errors like:
```
k3s-selinux ... Needs: container-selinux < 2:2.164.2
k3s-selinux ... Needs: container-selinux >= 2:2.107-3
```

**Why it happens**  
k3s tries to install the `k3s-selinux` RPM. Amazon Linux 2 often has a
`container-selinux` version mismatch, which causes the install to fail.

**What this lab does**  
The bootstrap script skips the SELinux RPM on Amazon Linux 2. k3s still works
for this lab, and this avoids the dependency conflict.

**Manual workaround (if needed)**
```
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -
```

If `kubectl` is missing:
```
sudo ln -s /usr/local/bin/k3s /usr/local/bin/kubectl
```

If kubeconfig permissions or env are missing:
```
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```

### Step 6 — Install Helm

```
./install_helm.sh
helm version
```

Helm is the package manager we use to deploy the app to Kubernetes.

### Step 7 — Deploy the Application with Helm

**Option A (Recommended for class): Use a public prebuilt image**

This avoids installing Docker on the EC2 instance.
```
cd helm/minishop-chart
helm install minishop . \
  --set api.image.repository=ghcr.io/abuenoa/minishop-api \
  --set api.image.tag=latest
```

**Option B (Advanced): Build and push your own image**

Build on your **local machine**, then push to Docker Hub or GHCR:
```
cd app/api
# docker build -t ghcr.io/your-org/minishop-api:latest .
# docker push ghcr.io/your-org/minishop-api:latest
```

Then deploy from the EC2 instance:
```
cd helm/minishop-chart
helm install minishop . \
  --set api.image.repository=ghcr.io/your-org/minishop-api \
  --set api.image.tag=latest
```

### Step 8 — Access the Application

Open in your browser:
```
http://<EC2_PUBLIC_IP>:30080
```

Click **Fetch message** to call the backend.

## Common Errors & How to Fix Them

1. **InvalidKeyPair.NotFound**

Error:
```
InvalidKeyPair.NotFound: The key pair 'minishop-key' does not exist
```

Cause: The EC2 key pair name in `terraform.tfvars` does not exist in the selected AWS region. Key pairs are region-specific.

Fix:
```
aws ec2 describe-key-pairs --region <YOUR_REGION>
```
If missing, create it:
```
aws ec2 create-key-pair \
  --region <YOUR_REGION> \
  --key-name minishop-key \
  --query 'KeyMaterial' \
  --output text > minishop-key.pem
chmod 400 minishop-key.pem
```
Ensure the name in `terraform.tfvars` matches exactly.

2. **Instance Type Not Free Tier Eligible**

Error:
```
The specified instance type is not eligible for Free Tier
```

Cause: The chosen instance type is not marked as Free Tier eligible in your AWS region.

Fix:
```
aws ec2 describe-instance-types \
  --region <YOUR_REGION> \
  --filters Name=free-tier-eligible,Values=true \
  --query "InstanceTypes[].InstanceType"
```
Use `t3.micro` (commonly eligible) in `terraform.tfvars`.

3. **Terraform: "No configuration files"**

Error:
```
Error: No configuration files
```

Cause: Terraform was executed in a directory without `.tf` files.

Fix:
```
cd terraform
terraform init
terraform apply
```

4. **k3s Installation Fails (Amazon Linux 2 SELinux Conflict)**

Error:
```
k3s-selinux requires container-selinux ...
```

Cause: Amazon Linux 2 may have incompatible `container-selinux` versions.

Fix:
```
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -
```

5. **kubectl Command Not Found**

Error:
```
kubectl: command not found
```

Cause: k3s installs kubectl internally but does not always expose it in PATH.

Fix:
```
sudo ln -s /usr/local/bin/k3s /usr/local/bin/kubectl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```

6. **Helm: Chart.yaml file is missing**

Error:
```
INSTALLATION FAILED: Chart.yaml file is missing
```

Cause: Helm was executed in the parent folder instead of the chart directory.

Fix:
```
cd helm/minishop-chart
helm install minishop .
```

7. **ErrImagePull (API Pod Fails)**

Error:
```
ErrImagePull
```

Cause: The Docker image specified in `values.yaml` does not exist, is private, or has a wrong tag.

Fix:
```
helm upgrade minishop . \
  --set api.image.repository=tiangolo/uvicorn-gunicorn-fastapi \
  --set api.image.tag=python3.11
```
Verify:
```
kubectl get pods
```

8. **kubectl get pods -w never ends**

Cause: `-w` means *watch* and keeps streaming updates.

Fix: Press `Ctrl+C` to stop watching, then run `kubectl get pods` again.

## Learning Lab: What Each Layer Teaches You

- **Terraform (IaC)**: Reproducible infrastructure. You define *what* you want (EC2, security group) and Terraform makes it real, reliably and repeatably.
- **EC2 (Compute)**: A real VM where Kubernetes will run. This mirrors how teams often bootstrap clusters on raw compute.
- **k3s (Kubernetes)**: A lightweight, production-grade Kubernetes distribution that fits a single Free Tier instance.
- **Helm (Packaging)**: A standard way to package and deploy Kubernetes apps with configurable values.
- **App (FastAPI + nginx)**: A minimal but realistic two-tier application that demonstrates service discovery and internal routing.

## Local Lab: Run Everything with Docker Compose

This is a quick way to test the app locally before deploying to AWS.

```
cd <YOUR_REPO>
cp .env.example .env
docker compose up --build
```

Access:
- Web: `http://localhost:30080`
- API health: `http://localhost:8000/health`
- API message: `http://localhost:8000/message`

Stop:

```
docker compose down
```

## How to Test (AWS + Kubernetes)

Once deployed on EC2, use these checks to validate each layer.

### 1) Validate Kubernetes is Running

```
kubectl get nodes
kubectl get pods -A
```

Expected: your node is `Ready` and system pods are running.

### 2) Validate Helm Deployment

```
helm list
kubectl get deployments
kubectl get services
```

Expected:
- `minishop-api` and `minishop-web` deployments are available
- `minishop-web` has type `NodePort`

### 3) Validate API Internally

```
kubectl port-forward svc/minishop-api 18000:8000
curl http://localhost:18000/health
curl http://localhost:18000/message
```

Expected: JSON response from `/health` and `/message`.

### 4) Validate End-to-End (Browser)

```
http://<EC2_PUBLIC_IP>:30080
```

Click **Fetch message**. This tests:
- Public NodePort access
- Web-to-API routing through ClusterIP
- API response payload

## Cleanup (Destroy All Resources)

Run this **locally** where you executed Terraform:
```
cd terraform
terraform destroy
```

Verify cleanup:
- AWS Console: no running EC2 instance
- Security group removed
- Key pair remains (delete it manually only if you want)

## Cost-Safety Notes (Free Tier)

- This project uses **one `t3.micro`** instance and the default VPC.
- Keep the instance running only while you are practicing.
- Always run `terraform destroy` when finished.

## What This Teaches You

- How Terraform provisions AWS infrastructure safely and repeatably
- How a Kubernetes cluster (k3s) runs on a small EC2 instance
- How Helm packages and deploys multi-service applications
- How frontend-to-backend communication works inside a cluster

This is a compact, real-world DevOps workflow designed for cloud students.

## End-to-End Lab Execution (Summary)

Use this checklist when teaching or validating the lab:

1. Configure AWS credentials (`aws configure` or env vars).
1. Set `terraform.tfvars` with `ssh_key_name` and `ssh_cidr`.
1. `terraform init` and `terraform apply`.
1. SSH into the instance.
1. Run `./install_k3s.sh` and verify `kubectl get nodes`.
1. Run `./install_helm.sh` and verify `helm version`.
1. Build/push API image, then `helm install`.
1. Open `http://<EC2_PUBLIC_IP>:30080` and click **Fetch message**.
