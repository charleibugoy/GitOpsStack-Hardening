# Lab Architecture Overview

```text
Terraform  → Provision VPC + EKS Cluster
Ansible    → Post-provision config + Kyverno policies
Helm       → Package deployments (ArgoCD, Kyverno, Prometheus, etc.)
ArgoCD     → GitOps continuous delivery + App-of-Apps
Kyverno    → Policy enforcement (STIGs, security)
Trivy      → Image + config scanning (CI + Operator)
Lula       → Compliance-as-Code (cATO simulation)
Prometheus + Grafana → Observability
```

---

# Must-Know DoD Terms

* Iron Bank: Hardened signed images
* Platform One / Big Bang: DoD DevSecOps platform
* cATO: Continuous Authority to Operate
* Lula: Defense Unicorns compliance tool
* STIG: Security Technical Implementation Guides

---

# Hardening Principles

* Minimal base (slim/distroless)
* Non-root user + `readOnlyRootFilesystem`
* Patch + clean caches
* Sign images (Cosign)
* Scan with Trivy in CI

---

# Key Kyverno Policies

* Restrict registries → Iron Bank only
* Disallow root
* `readOnlyRootFilesystem: true`
* Default-Deny NetworkPolicy (auto-generate)

---

# Troubleshooting Order (BLUF)

1. `kubectl describe pod`
2. `kubectl logs`
3. Events + Probes
4. NetworkPolicy / CNI
5. Resources / Quotas

---

# Interview BLUF Formula

```text
Conclusion → Why it matters for ATO → Tool/Technique → Example
```

---

# Tools Stack

| Category      | Tools                                |
| ------------- | ------------------------------------ |
| IaC           | Ansible + Terraform + Helm           |
| GitOps        | ArgoCD / Flux                        |
| Security      | Kyverno + Trivy + Cosign + Lula      |
| Observability | Prometheus + Grafana + Loki + Jaeger |

---

# Pre-requisites

## Required Tools

* AWS CLI
* Kubectl CLI
* Helm
* ArgoCD CLI
* Ansible
* Docker
* Terraform
* Git
* Lula
* jq

---

# CLI Installation Steps
```text
To automate CLI installs, run cli-prerequisite.sh
```

## macOS (Homebrew)

```bash
brew install terraform kubectl helm awscli argocd ansible git jq
```

### Docker Desktop

Install:

* Docker Desktop for macOS

Start Docker and verify:

```bash
docker version
```

---

## Ubuntu / Debian Linux

### Update Packages

```bash
sudo apt update
sudo apt install -y curl wget unzip gnupg software-properties-common git jq
```

---

### Install AWS CLI (Skip, if using CloudShell)

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

---

### Install kubectl 

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mkdir -p ~/bin
mv ./kubectl ~/bin/kubectl
kubectl version --client
```

---

### Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

---

### Install Terraform from AWS CloudShell

```bash
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
mkdir -p ~/bin
ln -s ~/.tfenv/bin/* ~/bin/
tfenv install 1.5.7
tfenv use 1.5.7

terraform --version
```

---

### Install ArgoCD CLI

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64
mkdir -p ~/bin
mv argocd-linux-amd64 ~/bin/argocd
argocd version --client
```

---

### Install Ansible and Python3

```bash
sudo apt install ansible -y

ansible --version
```

---

### Install Docker (Skip, if using CloudShell)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
docker version
```

> Logout/login may be required after adding your user to the Docker group.

---

### Install Trivy

```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
sh -s -- -b /usr/local/bin

trivy --version
```

---

## Windows

### Install Chocolatey

Open PowerShell as Administrator:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
[System.Net.ServicePointManager]::SecurityProtocol = `
[System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

---

### Install Required CLIs

```powershell
choco install -y awscli kubernetes-cli kubernetes-helm terraform git jq
```

---

### Install ArgoCD CLI

```powershell
choco install argocd-cli -y
```

---

### Install Docker Desktop

Install:

* Docker Desktop for Windows

Verify:

```powershell
docker version
```

---

# AWS Credentials

```bash
aws configure
```

---

# Verify Installed Tools

```bash
aws --version
kubectl version --client
terraform version
helm version
argocd version
docker version
ansible --version
git --version
jq --version
```

---

# 1. Deploy EKS Cluster Role CloudFormation

```bash
aws cloudformation create-stack \
  --stack-name eks-cluster-role \
  --template-body file://eks-cluster-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

---

# 1.5 Finding VPC and Subnet

## Find Default VPC

```bash
aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text
```

---

## List Subnets in that VPC

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text)

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].{
    SubnetId: SubnetId,
    AZ: AvailabilityZone,
    AutoAssignPublicIP: MapPublicIpOnLaunch,
    CIDR: CidrBlock
  }' \
  --output table
```

---

# 2. Deploy EKS Cluster (Terraform)

1. Clone Repository

```bash
git clone https://github.com/kodekloudhub/amazon-elastic-kubernetes-service-course
```

2. Navigate to EKS Directory

```bash
cd amazon-elastic-kubernetes-service-course/eks
```

3. Deploy Infrastructure

```bash
terraform init

terraform plan

terraform apply -auto-approve
```

4. After successful deployment, note the outputs for:

* `NodeAutoScalingGroup`
* `NodeInstanceRole`
* `NodeSecurityGroup`

---

# 2.1 Deploy EKS Cluster (Console)

1. From Amazon EKS → Create Cluster
2. Select **Custom configuration**
3. Turn Off **Use EKS Auto Mode**

---

## Cluster Configuration

| Setting          | Value            |
| ---------------- | ---------------- |
| Name             | `demo-eks`       |
| Cluster IAM Role | `eksClusterRole` |

---

## Cluster Access

* Select **Allow cluster administrator access**
* Cluster authentication mode:

  * `EKS API and ConfigMap`

---

## Networking

| Setting | Value                      |
| ------- | -------------------------- |
| VPC     | Select `<default-vpc-id>`  |
| Subnets | Select 2–3 default subnets |

> Take note of the subnet IDs.

---

# 3. Configure kubectl Access

## Using CloudShell

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name demo-eks
```

---

## 3.1 Verify EKS Connection

```bash
kubectl get all -A
```

---

# 4. Create Key Pair

## Option 1 — EC2 Console

Manually create RSA key pair via EC2 Console.

---

## Option 2 — AWS CLI

### 1. Get the Key Pair ID

```bash
KEY_PAIR_ID=$(aws ec2 describe-key-pairs \
  --key-names node-key-pair \
  --query "KeyPairs[0].KeyPairId" \
  --output text)
```

---

### 2. Download Private Key

```bash
aws ssm get-parameter \
  --name "/ec2/keypair/${KEY_PAIR_ID}" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > node-key-pair.pem
```

---

### 3. Secure the File

```bash
chmod 400 node-key-pair.pem
```

---

# 5. Deploy Node Stack (Workers)

Use S3 URL:

```text
https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2022-12-23/amazon-eks-nodegroup.yaml
```

---

## CloudFormation Parameters

| Setting                          | Value                                 |
| -------------------------------- | ------------------------------------- |
| Stack Name                       | `eks-cluster-stack`                   |
| ClusterName                      | `demo-eks`                            |
| ClusterControlPlaneSecurityGroup | Select SG containing `eks-cluster-sg` |
| NodeGroupName                    | `eks-demo-node`                       |
| KeyName                          | `node-key-pair`                       |
| VpcId                            | Select the only VPC entry             |
| Subnets                          | Select same subnets used for EKS      |

---

## Important

Take note of `NodeInstanceRole` from the **Outputs** tab.

---

# 6. Join Node Stack to EKS Cluster

## 1. Download Node ConfigMap

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/aws-auth-cm.yaml
```

---

## 2. Edit ConfigMap

Replace the `rolearn` with the noted `NodeInstanceRole`.

---

## 3. Apply ConfigMap

```bash
kubectl apply -f aws-auth-cm.yaml
```

---

## 4. Verify Nodes

```bash
kubectl get nodes
```

---

## 5. Wait for READY State

Ensure all nodes are in `READY` state.

---

---

## 6. Accessing NodePort Service

Modify Security Group for eks-cluster-stack-NodeSecurityGroup
Edit Inbound Rule -> Add Rule
  Type: Custom TCP
  Port Range: 30000-32768
  Source: My IP (or Anywhere just for labs)
Save rule

---

# 7. Install ArgoCD

## 1. Create Namespace + Install Manifest

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/V2.4.11/manifests/install.yaml
```

---

## 2. Expose ArgoCD Server

### Option A — LoadBalancer

```bash
kubectl patch svc argocd-server \
  -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

kubectl port-forward svc/argocd-server \
  -n argocd 8800:443
```

---

### Option B — NodePort

```bash
kubectl patch svc argocd-server \
  -n argocd \
  -p '{"spec": {"type": "NodePort"}}'
```

---

## 3. Verify ArgoCD Installation

```bash
kubectl get all -n argocd
```

---

## 4. Retrieve ArgoCD Admin Password

### List Secrets

```bash
kubectl get secret -n argocd
```

---

### Output Secret JSON

```bash
kubectl get secret argocd-inital-admin-secret \
  -n argocd \
  -o json
```

---

### Decode Password

```bash
kubectl get secret argocd-inital-admin-secret \
  -n argocd \
  -o json | jq .data.password -r | base64 -d
```

---

## 5. Login to ArgoCD UI

| Username | Password             |
| -------- | -------------------- |
| `admin`  | `<decoded-password>` |

---

# 8. Install Prometheus Stack

## 1. Add Prometheus Helm Repo

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm repo update
```

---

## 2. Deploy Prometheus Stack

```bash
kubectl create ns monitoring

helm install my-kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --version 40.1.2 \
  -n monitoring
```

---

## 3. Verify Prometheus Services

```bash
kubectl -n monitoring get svc
```

---

## 4. Login to Prometheus UI

Use NodePort IP.

---

## 5. Configure ServiceMonitor for ArgoCD

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  labels:
    release: my-kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
    - port: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  labels:
    release: my-kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
  endpoints:
    - port: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server-metrics
  labels:
    release: my-kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  endpoints:
    - port: metrics
```

---

## 6. Apply ServiceMonitors

```bash
kubectl -n argocd apply -f argocd-service-monitors.yaml
```

---

## 7. Verify ServiceMonitors

```bash
kubectl -n argocd get servicemonitors
```

---

## 8. Confirm Prometheus ServiceMonitor Selector

```bash
kubectl -n monitoring get prometheus.monitoring.coreos.com \
  -o yaml | grep -i servicemonitorselector -A5
```

---

# 9. Setting Up Grafana

## 1. Change Grafana Service to NodePort

```bash
kubectl -n monitoring edit svc my-kube-prometheus-stack-grafana

kubectl patch svc my-kube-prometheus-stack-grafana \
  -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'
```

---

## 2. Retrieve Grafana Password

```bash
kubectl -n monitoring get secret \
  my-kube-prometheus-stack-grafana \
  -o json | jq -r '.data["admin-password"]' | base64 --decode
```

---

## 3. Login to Grafana

```text
http://NodeIP:31762
```

| Username | Password            |
| -------- | ------------------- |
| `admin`  | `<decodedPassword>` |
