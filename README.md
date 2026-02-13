# minishop-platform

**minishop-platform** is a production-style, educational demo that shows a complete DevOps flow:

Terraform → EC2 (Free Tier) → k3s (single-node Kubernetes) → Helm → App deployment

The demo deploys a tiny FastAPI backend and an nginx web frontend to a single `t2.micro` instance.

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
|  t2.micro        |----|  (single node)   |----|   Services       |
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
export AWS_DEFAULT_REGION=us-east-1
```

**Terraform variables**

```
cd minishop-platform/terraform
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars` with:
- `ssh_key_name`: your EC2 key pair name
- `ssh_cidr`: your public IP in CIDR notation (e.g., `203.0.113.10/32`)

**Docker Compose (local lab)**

Copy the example environment file:
```
cd minishop-platform
cp .env.example .env
```

You can override:
- `API_IMAGE`, `API_TAG` for the backend image
- `API_PORT`, `WEB_PORT` for local ports

## Learning Lab: What Each Layer Teaches You

- **Terraform (IaC)**: Reproducible infrastructure. You define *what* you want (EC2, security group) and Terraform makes it real, reliably and repeatably.
- **EC2 (Compute)**: A real VM where Kubernetes will run. This mirrors how teams often bootstrap clusters on raw compute.
- **k3s (Kubernetes)**: A lightweight, production-grade Kubernetes distribution that fits a single Free Tier instance.
- **Helm (Packaging)**: A standard way to package and deploy Kubernetes apps with configurable values.
- **App (FastAPI + nginx)**: A minimal but realistic two-tier application that demonstrates service discovery and internal routing.

## Step-by-Step Deployment

### Step 1 — Configure AWS credentials

Set up your AWS credentials so Terraform can create resources.

```
export AWS_ACCESS_KEY_ID=YOUR_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
export AWS_DEFAULT_REGION=us-east-1
```

### Step 2 — Terraform init / apply

```
cd minishop-platform/terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your key pair name and IP
terraform init
terraform apply
```

Terraform will output the EC2 public IP after apply.

### Step 3 — SSH into instance

```
ssh -i /path/to/your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

### Step 4 — Install k3s

```
cd minishop-platform/bootstrap
./install_k3s.sh
```

### Step 5 — Install Helm

```
./install_helm.sh
```

### Step 6 — Deploy Helm chart

Build and push the API image (example):

```
cd minishop-platform/app/api
# docker build -t ghcr.io/your-org/minishop-api:latest .
# docker push ghcr.io/your-org/minishop-api:latest
```

Then deploy the chart:

```
cd minishop-platform/helm/minishop-chart
helm install minishop . \
  --set api.image.repository=ghcr.io/your-org/minishop-api \
  --set api.image.tag=latest
```

The web service is exposed via NodePort `30080` by default.

### Step 7 — Access the application

In your browser:

```
http://<EC2_PUBLIC_IP>:30080
```

Click **Fetch message** to call the API.

## Local Lab: Run Everything with Docker Compose

This is a quick way to test the app locally before deploying to AWS.

```
cd minishop-platform
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

```
cd minishop-platform/terraform
terraform destroy
```

## Cost-Safety Notes (Free Tier)

- This project uses **one `t2.micro`** instance and the default VPC.
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
