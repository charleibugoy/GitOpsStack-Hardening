
```markdown
# Lab Architecture Overview

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

# Interview BLUF Formula

```text
Conclusion → Why it matters for ATO → Tool/Technique → Example

```

---

# Troubleshooting Order (BLUF)

1. `kubectl describe pod`
2. `kubectl logs`
3. Events + Probes
4. NetworkPolicy / CNI
5. Resources / Quotas

---

# Tools Stack

| Category | Tools |
| --- | --- |
| IaC | Ansible + Terraform + Helm |
| GitOps | ArgoCD / Flux |
| Security | Kyverno + Trivy + Cosign + Lula |
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
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

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
mkdir -p ~/.local/bin
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
sh -s -- -b ~/.local/bin
trivy --version

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

# PHASE 1: Infrastructure Provisioning (EKS Cluster Deployment)

## 1. Deploy EKS Cluster Role CloudFormation

```bash
aws cloudformation create-stack \
  --stack-name eks-cluster-role \
  --template-body file://1.eks-cluster-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM

```
---

## 1.5 Finding VPC and Subnet

### Find Default VPC

```bash
aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text

```

---

### List Subnets in that VPC

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

## 2. Deploy EKS Cluster (Option A: Terraform)

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

## 2.1 Deploy EKS Cluster (Option B: Console)

1. From Amazon EKS → Create Cluster
2. Select **Custom configuration**
3. Turn Off **Use EKS Auto Mode**

---

### Cluster Configuration

| Setting | Value |
| --- | --- |
| Name | `demo-eks` |
| Cluster IAM Role | `eksClusterRole` |

---

### Cluster Access

* Select **Allow cluster administrator access**
* Cluster authentication mode:
* `EKS API and ConfigMap`



---

### Networking

| Setting | Value |
| --- | --- |
| VPC | Select `<default-vpc-id>` |
| Subnets | Select 2–3 default subnets |

> Take note of the subnet IDs.

---

## 3. Configure kubectl Access

### Using CloudShell

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name demo-eks

```

---

### 3.1 Verify EKS Connection

```bash
kubectl get all -A

```

---

## 4. Create Key Pair

### Option 1 — EC2 Console

Manually create RSA key pair via EC2 Console.

---

### Option 2 — AWS CLI

#### 1. Get the Key Pair ID

```bash
KEY_PAIR_ID=$(aws ec2 describe-key-pairs \
  --key-names node-key-pair \
  --query "KeyPairs[0].KeyPairId" \
  --output text)

```

---

#### 2. Download Private Key

```bash
aws ssm get-parameter \
  --name "/ec2/keypair/${KEY_PAIR_ID}" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > node-key-pair.pem

```

---

#### 3. Secure the File

```bash
chmod 400 node-key-pair.pem

```

---

## 5. Deploy Node Stack (Workers)

Use S3 URL:

```text
https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2022-12-23/amazon-eks-nodegroup.yaml

```

---

### CloudFormation Parameters

| Setting | Value |
| --- | --- |
| Stack Name | `eks-cluster-stack` |
| ClusterName | `demo-eks` |
| ClusterControlPlaneSecurityGroup | Select SG containing `eks-cluster-sg` |
| NodeGroupName | `eks-demo-node` |
| KeyName | `node-key-pair` |
| VpcId | Select the only VPC entry |
| Subnets | Select same subnets used for EKS |

---

### Important

Take note of `NodeInstanceRole` from the **Outputs** tab.

---

## 6. Join Node Stack to EKS Cluster

#### 1. Download Node ConfigMap

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/aws-auth-cm.yaml

```

---

#### 2. Edit ConfigMap

Replace the `rolearn` with the noted `NodeInstanceRole`.

---

#### 3. Apply ConfigMap

```bash
kubectl apply -f aws-auth-cm.yaml

```

---

#### 4. Verify Nodes

```bash
kubectl get nodes

```

---

#### 5. Wait for READY State

Ensure all nodes are in `READY` state.

---

#### 6. Accessing NodePort Service

Modify Security Group for eks-cluster-stack-NodeSecurityGroup
Edit Inbound Rule -> Add Rule
Type: Custom TCP
Port Range: 30000-32768
Source: My IP (or Anywhere just for labs)
Save rule

---

# PHASE 2: Core Platform Deployment (GitOps, Secrets, & Observability)

## 7. Install ArgoCD

### 1. Create Namespace + Install Manifest

```bash
kubectl create namespace argocd

kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

```

---

### 2. Expose ArgoCD Server

#### Option A — LoadBalancer

```bash
kubectl patch svc argocd-server \
  -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

kubectl port-forward svc/argocd-server \
  -n argocd 8800:443

```

---

#### Option B — NodePort

```bash
kubectl patch svc argocd-server \
  -n argocd \
  -p '{"spec": {"type": "NodePort"}}'

```

---

### 3. Verify ArgoCD Installation

```bash
kubectl get all -n argocd

```

---

### 4. Retrieve ArgoCD Admin Password

#### List Secrets

```bash
kubectl get secret -n argocd

```

---

#### Output Secret JSON

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o json

```

---

#### Decode Password

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o json | jq .data.password -r | base64 -d

```

---

### 5. Login to ArgoCD UI

| Username | Password |
| --- | --- |
| `admin` | `<decoded-password>` |

---

## 8. Install External Secrets Operator (for AWS Secrets Manager)

### 1. Add Helm Repo and Install ESO

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace

```
### 2. Create IAM Role for Service Account (IRSA)

Create a file `trust-policy.json`:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${OIDC_PROVIDER}:sub": "system:serviceaccount:external-secrets:external-secrets"
                }
            }
        }
    ]
}
```

Then run:
```bash
# Set environment variables
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export OIDC_PROVIDER=$(aws eks describe-cluster --name demo-eks --query "cluster.identity.oidc.issuer" --output text | sed 's~https://~~')

# Substitute variables and create role
sed \
  -e "s|\${ACCOUNT_ID}|${ACCOUNT_ID}|g" \
  -e "s|\${OIDC_PROVIDER}|${OIDC_PROVIDER}|g" \
  trust-policy.json > filled-trust-policy.json
aws iam create-role --role-name EKSExternalSecretsRole --assume-role-policy-document file://filled-trust-policy.json

# Attach the policy to allow reading from Secrets Manager
aws iam attach-role-policy --role-name EKSExternalSecretsRole --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

### 3. Annotate the Service Account
```bash
kubectl annotate serviceaccount external-secrets -n external-secrets \
  eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/EKSExternalSecretsRole
```

---

## 9. Install Prometheus Stack

### 1. Add Prometheus Helm Repo

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm repo update

```

---

### 2. Deploy Prometheus Stack

```bash
kubectl create ns monitoring

helm install my-kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --version 40.1.2 \
  -n monitoring

```

---

### 3. Verify Prometheus Services

```bash
kubectl -n monitoring get svc

```

If PortType is ClusterIP, change it to NodePort

```bash
kubectl patch svc my-kube-prometheus-stack \
  -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'

```

---

### 4. Login to Prometheus UI

```text
Use <NodePort IP>:<NodePort>.

```

### 5. Configure ServiceMonitor for ArgoCD

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

### 6. Apply ServiceMonitors

```bash
kubectl -n argocd apply -f argocd-service-monitors.yaml

```

---

### 7. Verify ServiceMonitors

```bash
kubectl -n argocd get servicemonitors

```

---

### 8. Confirm Prometheus ServiceMonitor Selector

```bash
kubectl -n monitoring get prometheus.monitoring.coreos.com \
  -o yaml | grep -i servicemonitorselector -A5

```

---

## 10. Setting Up Grafana

### 1. Change Grafana Service to NodePort

```bash
kubectl -n monitoring edit svc my-kube-prometheus-stack-grafana

kubectl patch svc my-kube-prometheus-stack-grafana \
  -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'

```

---

### 2. Retrieve Grafana Password

```bash
kubectl -n monitoring get secret \
  my-kube-prometheus-stack-grafana \
  -o json | jq -r '.data["admin-password"]' | base64 --decode

```

---

### 3. Login to Grafana

```text
http://NodeIP:<NodePort>

```

| Username | Password |
| --- | --- |
| `admin` | `<decodedPassword>` |

---

# PHASE 3: Application Deployment & Progressive Hardening

# Key Kyverno Policies (Reference)

* Restrict registries → Iron Bank only
* Disallow root
* `readOnlyRootFilesystem: true`
* Default-Deny NetworkPolicy (auto-generate)

---

## 11. Deploying Application in ArgoCD

### 1. Deploy Base NGINX via UI (Method 1)

* Open ArgoCD UI
* Click **+ New App**
* Fill in:
* Application Name: hardened-app
* Project: default
* Repository URL: your GitHub repo
* Revision: HEAD
* Path: k8s/nginx
* Destination Cluster: https://kubernetes.default.svc
* Destination Namespace: production



### 1.1 Deploy Base NGINX via CLI (Method 2)

```bash
argocd app create hardened-app \
  --repo https://github.com/charleibugoy/GitOpsStack-Hardening.git \
  --path k8s/nginx \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production

```
### 2. Verify NGINX deployment are successful.

```bash
kubectl -n production get all
kubectl -n production get service -o wide

```

```textile
Login to NGINX app using http://<nodeip>:<nodeport>

```

### 3. Implement RBAC for Least Privilege
By default, pods use the `default` service account, which may have broad permissions. We will create a dedicated Service Account for our app with no API permissions.

#### 3.1 Create RBAC manifests
Create a file `k8s/nginx/rbac.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-hardened-sa
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: nginx-hardened-role
  namespace: production
rules: [] # No API permissions needed for a simple NGINX pod
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: nginx-hardened-rb
  namespace: production
subjects:
- kind: ServiceAccount
  name: nginx-hardened-sa
roleRef:
  kind: Role
  name: nginx-hardened-role
  apiGroup: rbac.authorization.k8s.io
```

#### 3.2 Update Deployment to use the Service Account
Add `serviceAccountName: nginx-hardened-sa` to your `deployment.yaml` under `spec.template.spec`:
```yaml
spec:
      serviceAccountName: nginx-hardened-sa
      # === Pod Level SecurityContext ===
      securityContext:
        runAsNonRoot: true
...
```
Push the new `rbac.yaml` and updated `deployment.yaml` to your Git repository. ArgoCD will sync the changes.

### 4. Add SecurityContext Gradually

We'll add security settings **one layer at a time**.

#### **Phase 4.1: Add Pod-level securityContext**

Update deployment.yaml:

YAML

```yaml
spec:
      serviceAccountName: nginx-hardened-sa
      # === Pod Level SecurityContext ===
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        fsGroup: 101

      containers:
      - name: nginx
        image: nginx:latest
        ...
        # No container-level securityContext yet

```
```text
Why it was breaking

The official nginx:*-alpine image runs the master process as root and worker processes as nginx (101). Forcing everything to 101 can cause nginx to fail when it tries to bind ports, write to /var/cache/nginx, or manage PID files.
fsGroup: 101 changes ownership of mounted volumes, which can fail or take time if volumes are large or have wrong permissions.
readOnlyRootFilesystem: true is great for security but often breaks nginx unless you add proper volume mounts.

Because nginx pod is set readOnlyRootFilesystem: true.
Nginx (by default) tries to create/write to these directories at startup:

/var/cache/nginx/
/var/run/
/tmp/

With a read-only root filesystem, it fails.

runAsNonRoot: true
Even though you are using the excellent, minimal alpine-slim variant, the standard official Nginx Docker images are hardcoded to start as the root user because standard Nginx needs root privileges to bind to port 80.

Since Kubernetes catches this, it blocks the container from starting completely.
```

**Push** and verify pods still start successfully.

#### **Phase 4.2: Add Container-level securityContext**

Update to this version:

YAML

```yaml
spec:
      serviceAccountName: nginx-hardened-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        fsGroup: 101

      containers:
      - name: nginx
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "300m"
            memory: "256Mi"

```

**Push again** and check if pods are still healthy.

### **Step 5: Add a Non-Blocking Kyverno Policy**

Create a **simple audit-only policy** first (it will **not block** deployments):

**policies/audit-hardening.yaml**

YAML

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: audit-hardening-baseline
spec:
  validationFailureAction: Audit   # Important: Audit = Warn, not block
  background: true
  rules:
  - name: check-non-root
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "Best practice: Run as non-root (Audit mode)"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true

  - name: check-readonly-rootfs
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "Best practice: Use readOnlyRootFilesystem (Audit mode)"
      pattern:
        spec:
          containers:
          - securityContext:
              readOnlyRootFilesystem: true

```

Apply it:

Bash

```bash
kubectl apply -f policies/audit-hardening.yaml

```

Check policy status:

Bash

```bash
kubectl get clusterpolicy
kubectl get policyreport -A

```

---

### **Action Now:**

1. Update your deployment.yaml with **Phase 4.1** first.
2. Push to Git.
3. Apply the audit-hardening.yaml policy.
4. Run:

Bash

```bash
kubectl get pods -n production
kubectl get policyreport -A

```

---

### **Step 6: Move to Enforcement Mode (Gradually)**

Now that we have a working base, let's switch the Kyverno policy to **Enforce** mode.

#### Update the policy to enforcement:

**policies/enforce-hardening.yaml** (replace the previous audit one)

YAML

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-hardening-baseline
spec:
  validationFailureAction: Enforce     # Now it will block violations
  background: true
  rules:
  - name: enforce-non-root
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "DoD STIG: Pods must run as non-root user"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
          containers:
          - securityContext:
              runAsNonRoot: true

  - name: enforce-readonly-rootfs
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "DoD Hardening: Root filesystem must be read-only"
      pattern:
        spec:
          containers:
          - securityContext:
              readOnlyRootFilesystem: true

```

Apply the new policy:

Bash

```bash
kubectl apply -f policies/enforce-hardening.yaml

```

---

### **Step 7: Add Full SecurityContext to Deployment**

Now update **k8s/deployment.yaml** to the full hardened version:

YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-hardened
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-hardened
  template:
    metadata:
      labels:
        app: nginx-hardened
    spec:
      serviceAccountName: nginx-hardened-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        fsGroup: 101

      containers:
      - name: nginx
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "300m"
            memory: "256Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10

```

**Commit and push**:

Bash

```bash
git add k8s/deployment.yaml
git commit -m "Add full securityContext + Kyverno enforcement"
git push

```

---

### **Step 8: Verify Everything**

Run these commands and check the status:

Bash

```bash
# 1. Check pods
kubectl get pods -n production

# 2. Check Kyverno policies
kubectl get clusterpolicy

# 3. Check if any violations are being reported
kubectl get policyreport -A

# 4. Check ArgoCD sync status
argocd app get nginx-hardened

```

---

### **Step 9: Easy Access via Port Forward**

Bash

```bash
kubectl port-forward svc/nginx-hardened 8080:80 -n production

```

Open your browser: **[http://localhost:8080](https://www.google.com/search?q=http://localhost:8080)**

You should see the Nginx welcome page.

---

# PHASE 4: Advanced Security & Compliance Validation (Trivy, Policy Dashboards, & Lula)

## **Part 1: Integrate Trivy**

### 1.1 Install Trivy Operator (Recommended for Kubernetes)

Bash

```bash
# Add Helm repo
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update

# Install Trivy Operator
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace \
  --set trivy.ignoreUnfixed=true \
  --set operator.scanJobTimeout=5m

```

Verify:

Bash

```bash
kubectl get pods -n trivy-system
kubectl get vulnerabilityreports -n production

```

### 1.2 Manual Scan (Quick)

Bash

```bash
# Scan the nginx image
trivy image nginx:latest --severity HIGH,CRITICAL

# Scan your running deployment
trivy k8s --report summary deployment/nginx-hardened -n production

```

---

## **Part 2: Advanced Visualization and Dynamic Scanning**

### **1. Deploy Trivy Operator + Policy Reporter (Nice Dashboards)**

Bash

```bash
# 1. Install Trivy Operator
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update

helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace \
  --set trivy.ignoreUnfixed=true \
  --set operator.scanJobTimeout=5m \
  --set trivy.severity="CRITICAL,HIGH"

```

Bash

```bash
# 2. Install Policy Reporter (for beautiful dashboards)
helm repo add policy-reporter https://kyverno.github.io/policy-reporter
helm repo update

helm install policy-reporter policy-reporter/policy-reporter \
  --namespace policy-reporter \
  --create-namespace \
  --set ui.enabled=true

```

**Access Dashboards**:

* Policy Reporter UI: `kubectl port-forward svc/policy-reporter 8080:8080 -n policy-reporter`
* Open: [http://localhost:8080](https://www.google.com/search?q=http://localhost:8080)

---

### **2. Kyverno Policy: Block HIGH/CRITICAL Vulnerabilities**

**policies/block-vulnerable-images.yaml**

YAML

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-high-critical-vulnerabilities
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: block-critical-vulns
    match:
      any:
      - resources:
          kinds: ["Pod"]
    preconditions:
      all:
      - key: "{{request.operation}}"
        operator: In
        value: ["CREATE", "UPDATE"]
    validate:
      message: "Image {{element.image}} has HIGH or CRITICAL vulnerabilities and is blocked (DoD Policy)"
      foreach:
      - list: "request.object.spec.containers"
        deny:
          conditions:
            all:
            - key: "{{ vulnerabilities.critical | default(0) }}"
              operator: GreaterThan
              value: 0
            - key: "{{ vulnerabilities.high | default(0) }}"
              operator: GreaterThan
              value: 5   # Allow max 5 HIGH, block more

```

Apply it:

Bash

```bash
kubectl apply -f policies/block-vulnerable-images.yaml

```

> **Note**: This policy works best when combined with **Trivy Operator** (it reads vulnerability reports). For pure admission-time scanning without Operator, we usually use Cosign attestations.

---

### **3. ArgoCD Pre-Sync Hook with Trivy Scan**

Create this hook in your Git repo (e.g., under hooks/ folder):

**hooks/trivy-presync-scan.yaml**

YAML

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: trivy-presync-scan
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    argocd.argoproj.io/sync-wave: "-1"   # Run before main sync
spec:
  template:
    spec:
      containers:
      - name: trivy
        image: aquasec/trivy:latest
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "=== Running Trivy Pre-Sync Scan ==="
          trivy image --exit-code 1 --severity HIGH,CRITICAL nginx:latest
          echo "✅ Pre-sync scan passed"
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
      restartPolicy: Never
  backoffLimit: 1

```

**Add this to your ArgoCD Application** (or use App of Apps).

---

## **Part 3: Integrate Lula (Compliance Validation)**

### 3.1 Create OSCAL Component Definition + Lula Manifest

Create a new folder:

Bash

```bash
mkdir -p compliance

```

**compliance/component-definition.yaml**

YAML

```yaml
apiVersion: oscal.mitre.org/v1alpha1
kind: ComponentDefinition
metadata:
  name: nginx-hardened-component
  namespace: production
spec:
  title: "Hardened Nginx Application - Defense Unicorns Lab"
  description: "Sample application with Kyverno enforcement"
  components:
    - name: nginx-deployment
      type: Service
      description: "Nginx deployment protected by Kyverno"
      control-implementations:
        - source: "NIST-800-53"
          description: "Container Security Controls"
          implemented-requirements:
            - control-id: "CM-7"
              description: "Least Functionality - Non-root + ReadOnly FS"
            - control-id: "SC-7"
              description: "Boundary Protection"

```

**compliance/lula-assessment.yaml**

YAML

```yaml
apiVersion: lula.dev/v1alpha1
kind: Assessment
metadata:
  name: nginx-hardened-assessment
spec:
  target:
    kind: Deployment
    name: nginx-hardened
    namespace: production
  controls:
    - id: STIG-Container-001
      description: "Containers must run as non-root"
      validation:
        type: kyverno
        policy: enforce-hardening-baseline
        rule: enforce-non-root

    - id: STIG-Container-002
      description: "Root filesystem must be read-only"
      validation:
        type: kyverno
        policy: enforce-hardening-baseline
        rule: enforce-readonly-rootfs

```

---

### 3.2 Run Lula Validation

Bash

```bash
# Validate compliance
lula validate --manifest compliance/lula-assessment.yaml

```

You should see a report showing whether your Kyverno policies are being satisfied.

---

## **Part 4: Full Workflow Summary (Recommended Execution)**

1. **Build + Scan with Trivy** (before pushing to Git)
2. **Deploy via ArgoCD**
3. **Kyverno** enforces security at admission time
4. **Trivy Operator** continuously scans running pods
5. **Lula** generates compliance evidence
```