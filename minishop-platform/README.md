# minishop-platform

**minishop-platform** is a production-style, educational demo that shows a complete DevOps flow:

Terraform → EC2 (Free Tier) → k3s (single-node Kubernetes) → Helm → App deployment

The demo deploys a tiny FastAPI backend and an nginx web frontend to a single `t2.micro` instance.

**What you get**
- AWS infrastructure created by Terraform
- A k3s Kubernetes cluster on EC2
- Helm-based application deployment
- A simple web page calling an internal API

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
