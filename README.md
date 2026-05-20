```text
# Lab Architecture Overview

Terraform  → Provision VPC + EKS Cluster
Ansible    → Post-provision config + Kyverno policies
Helm       → Package deployments (ArgoCD, Kyverno, Prometheus, etc.)
ArgoCD     → GitOps continuous delivery + App-of-Apps
Kyverno    → Policy enforcement (STIGs, security)
Trivy      → Image + config scanning (CI + Operator)
Lula       → Compliance-as-Code (cATO simulation)
Prometheus + Grafana → Observability

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

Conclusion → Why it matters for ATO → Tool/Technique → Example

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

To automate CLI installs, run cli-prerequisite.sh

---
```

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
curl -LO "https://dl.k8s.io/release/$ (curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
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

### Install Trivy

```bash
mkdir -p ~/.local/bin
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
sh -s -- -b ~/.local/bin
trivy --version

```

### Install Lula

```bash
curl -L -o lula https://github.com/defenseunicorns/lula/releases/download/v0.11.0/lula_v0.11.0_Linux_amd64
chmod +x lula
sudo mv lula /usr/local/bin/

```

---

# AWS Credentials

```bash
aws configure

```

---

# Verify Installed Tools

```bash
kubectl version --client
terraform version
helm version
argocd version
ansible --version

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
git clone [https://github.com/kodekloudhub/amazon-elastic-kubernetes-service-course](https://github.com/kodekloudhub/amazon-elastic-kubernetes-service-course)

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
* Cluster authentication mode: `EKS API and ConfigMap`

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
[https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2022-12-23/amazon-eks-nodegroup.yaml](https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2022-12-23/amazon-eks-nodegroup.yaml)

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

Modify Security Group for `eks-cluster-stack-NodeSecurityGroup`
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
  [eks.amazonaws.com/role-arn=arn:aws:iam::$](https://eks.amazonaws.com/role-arn=arn:aws:iam::$){ACCOUNT_ID}:role/EKSExternalSecretsRole

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

If PortType is ClusterIP, change it to NodePort:

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
apiVersion: https://monitoring.coreos.com/v1
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
apiVersion: https://monitoring.coreos.com/v1
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
apiVersion: https://monitoring.coreos.com/v1
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

Update `deployment.yaml`:

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

What Exactly Blocked It?
The Port 80 Block: Standard Linux kernels restrict ports 1–1023 to the root user. By dropping ALL capabilities and running non-root, the container physically does not have permission to bind to port 80. Moving to 8080 satisfies the kernel.

The Cache Block: Even the unprivileged version of Nginx needs to write temporary data. When readOnlyRootFilesystem is active, directories like /var/cache/nginx become read-only blocks.

The Solution (emptyDir): An emptyDir volume creates a fresh, writable directory that lives purely in the Pod's temporary storage (RAM/node disk space). It isolates the writes to just those three specific folders while keeping the rest of the entire system strictly locked down.

```

**Push** and verify pods still start successfully.

#### **Phase 4.2: Add Container-level securityContext**

Update to this version:

```yaml
spec:
      serviceAccountName: nginx-hardened-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 101

      containers:
      - name: nginx
        image: nginxinc/nginx-unprivileged:1.27-alpine-slim
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080 # High port required for non-root / dropped capabilities
        
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

        # Mount the ephemeral scratch spaces into the container
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: run-volume
          mountPath: /var/run
        - name: cache-volume
          mountPath: /var/cache/nginx

      # Define the temporary memory-backed storage spaces
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: run-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}

```

**Push again** and check if pods are still healthy.

### **Step 5: Add a Non-Blocking Kyverno Policy**

Create a **simple audit-only policy** first (it will **not block** deployments):

**policies/audit-hardening.yaml**

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

```bash
kubectl apply -f policies/audit-hardening.yaml

```

Check policy status:

```bash
kubectl get clusterpolicy
kubectl get policyreport -A

```

---

### **Step 6: Move to Enforcement Mode (Gradually)**

Now that we have a working base, let's switch the Kyverno policy to **Enforce** mode.

#### Update the policy to enforcement:

**policies/enforce-hardening.yaml** (replace the previous audit one)

### Installing Kyverno (Requires Helm)

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace

```

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-hardening-baseline
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  # Rule 1: Checks that runAsNonRoot is active at either Pod OR Container level safely
  - name: enforce-non-root
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "DoD STIG: Pods or containers must be configured to run as a non-root user."
      anyPattern:
      # Pattern A: Configured at the entire Pod level
      - spec:
          securityContext:
            runAsNonRoot: true
      # Pattern B: Explicitly configured on every individual container
      - spec:
          containers:
          - securityContext:
              runAsNonRoot: true

  # Rule 2: Loops through all containers and enforces readOnlyRootFilesystem
  - name: enforce-readonly-rootfs
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "DoD Hardening: Root filesystem must be read-only for all containers."
      pattern:
        spec:
          containers:
          # The element pattern checks every container in the array
          - securityContext:
              readOnlyRootFilesystem: true

```

Apply the new policy:

```bash
kubectl apply -f policies/enforce-hardening.yaml

```

---

```text
With the enforcement of Kyverno Policy, will actively blocking any deployment that doesn't explicitly declare your hardening rules. Can be fix by passing the proper security context parameters directly into the helm install command using --set flags. Such as:

```

```bash
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace \
  --set trivy.ignoreUnfixed=true \
  --set operator.scanJobTimeout=5m \
  --set podSecurityContext.runAsNonRoot=true \
  --set podSecurityContext.runAsUser=10000 \
  --set podSecurityContext.runAsGroup=10000 \
  --set securityContext.runAsNonRoot=true \
  --set securityContext.readOnlyRootFilesystem=true

```

---

### **Step 7: Add Full SecurityContext to Deployment**

Now update **k8s/deployment.yaml** to the full hardened version:

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
        runAsGroup: 101 # Added group consistency
        fsGroup: 101

      containers:
      - name: nginx
        # 1. Switched back to the unprivileged image to handle non-root seamlessly
        image: nginxinc/nginx-unprivileged:1.27-alpine-slim
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080 # 2. Shifted to unprivileged port
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
            port: 8080 # 3. Updated probe to match the container port
          initialDelaySeconds: 5
          periodSeconds: 10

        # 4. Mounted temporary writable storage so readOnlyRootFilesystem doesn't choke Nginx
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: run-volume
          mountPath: /var/run
        - name: cache-volume
          mountPath: /var/cache/nginx

      # 5. Declared the memory-backed volumes required by the mounts above
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: run-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}

```

**Commit and push**:

```bash
git add k8s/deployment.yaml
git commit -m "Add full securityContext + Kyverno enforcement"
git push

```

---

### **Step 8: Verify Everything**

Run these commands and check the status:

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

```bash
kubectl port-forward svc/nginx-hardened 8080:80 -n production

```

Open your browser: **[http://localhost:8080](https://www.google.com/search?q=http://localhost:8080)**

You should see the Nginx welcome page.

---

# PHASE 4: Advanced Security & Compliance Validation (Trivy, Policy Dashboards, & Lula)

## **Part 1: Integrate Trivy**

### 1.1 Install Trivy Operator (Recommended for Kubernetes)

```bash
# Add Helm repo
helm repo add aqua [https://aquasecurity.github.io/helm-charts/](https://aquasecurity.github.io/helm-charts/)
helm repo update

# Install Trivy Operator
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace \
  --set trivy.ignoreUnfixed=true \
  --set operator.scanJobTimeout=5m \
  --set podSecurityContext.runAsNonRoot=true \
  --set podSecurityContext.runAsUser=10000 \
  --set podSecurityContext.runAsGroup=10000 \
  --set securityContext.runAsNonRoot=true \
  --set securityContext.readOnlyRootFilesystem=true

```

Verify:

```bash
kubectl get pods -n trivy-system
kubectl get vulnerabilityreports -n production

```

### 1.2 Manual Scan (Quick)

```bash
# Scan the nginx image
trivy image nginxinc/nginx-unprivileged:1.27-alpine-slim --severity HIGH,CRITICAL

# Scan your running deployment
trivy k8s --report summary deployment/nginx-hardened -n production

```

---

## **Part 2: Advanced Visualization and Dynamic Scanning**

### **1. Deploy Trivy Operator + Policy Reporter (Nice Dashboards)**

```bash
# 2. Install Policy Reporter (for beautiful dashboards)
helm repo add policy-reporter https://kyverno.github.io/policy-reporter
helm repo update

helm install policy-reporter policy-reporter/policy-reporter \
  --namespace policy-reporter \
  --create-namespace \
  --set ui.enabled=true

```

```bash
# 3. Modify service policy-reporter-ui to NodePort to Access UI
kubectl patch svc policy-reporter \
  -n policy-reporter-ui \
  -p '{"spec": {"type": "NodePort"}}'

```

**Access Dashboards**:

* Policy Reporter UI: `kubectl port-forward svc/policy-reporter 8080:8080 -n policy-reporter`
* Open: [http://localhost:8080](https://www.google.com/search?q=http://localhost:8080)

---

### **2. Kyverno Policy: Block HIGH/CRITICAL Vulnerabilities**

**policies/block-vulnerable-images.yaml**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-high-critical-vulnerabilities
spec:
  validationFailureAction: Enforce
  background: false
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
      - key: "{{request.subResource || ''}}"
        operator: NotEquals
        value: "status"
    validate:
      message: "Admission blocked by DoD Policy. One or more images exceed vulnerability thresholds."
      foreach:
      - list: "request.object.spec.containers"
        context:
        - name: imageVulnerabilities
          apiCall:
            urlPath: /apis/aquasecurity.github.io/v1alpha1/namespaces/{{request.namespace}}/vulnerabilityreports
            jmesPath: "items[?status.artifact.repository=='{{element.image}}'].status.summary | [0]"
        deny:
          conditions:
            all:
            - key: "{{ imageVulnerabilities.critical || '0' }}"
              operator: GreaterThan
              value: "0"
            - key: "{{ imageVulnerabilities.high || '0' }}"
              operator: GreaterThan
              value: "5"

```

Apply it:

```bash
kubectl apply -f policies/block-vulnerable-images.yaml

```

> **Note**: This policy works best when combined with **Trivy Operator** (it reads vulnerability reports). For pure admission-time scanning without Operator, we usually use Cosign attestations.

---

### 2.1 Validate Kyverno Policy

Method 1: The "Chaos" Test (Recommended)
The absolute best way to prove a security gate works is to try and break it. Attempt to run an intentionally highly vulnerable image (like nginx:1.19) that Trivy has almost certainly scanned and flagged with dozens of Critical and High vulnerabilities.

```bash
kubectl run vulnerable-test --image=nginx:1.19 --namespace=production

```

What should happen:
If the policy is working and Trivy has an existing report for it, the command will fail instantly in your terminal, and you will see a message like this:

`Error from server (Forbidden): admission webhook "validate.kyverno.svc-fail" denied the request: Admission blocked by DoD Policy. One or more images exceed vulnerability thresholds...`

Method 2: Check Kyverno's Policy Reports
Kyverno continuously generates clean, human-readable dashboards directly inside Kubernetes using a custom resource called a PolicyReport (polr) or ClusterPolicyReport (cpolr).

You can inspect these reports to see exactly which workloads are passing or failing your new rule:

```bash
# 1. Get a summary of all policy evaluations across the cluster
kubectl get clusterpolicyreports

```

```bash
# 2. Look at a specific namespace report (like your production space)
kubectl get policyreports -n production

```

The output will give you a quick scorecard showing how many resources are compliant:

```bash
NAME                 PASS   FAIL   WARN   ERROR   SKIP   AGE
polr-production      12     2      0      0       0      5m

```

To see the exact details of which specific pods failed and why, you can output the report to YAML or JSON and filter for the results:

```bash
kubectl get policyreport -n production -o yaml | grep -A 5 -B 2 "status: fail"

```

Method 3: Watch the Kyverno Logs
If you want to watch the evaluation happen in real-time, you can stream the logs from the Kyverno admission controller pod while you attempt to create a deployment:

```bash
# Find your engine pod name first
kubectl get pods -n kyverno

# Stream the logs filtering for your rule name
kubectl logs -n kyverno -l app.kubernetes.io/component=kyverno-admission-controller --tail=100 -f | grep "block-critical-vulns"

```

If a pod gets blocked, you'll see a clean log entry tracking the inbound admission webhook request and the resulting deny action!

---

### **3. ArgoCD Pre-Sync Hook with Trivy Scan**

Create this hook in your Git repo (e.g., under hooks/ folder):

**hooks/trivy-presync-scan.yaml**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: trivy-presync-scan
  namespace: production # Make sure this matches your target namespace
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    argocd.argoproj.io/sync-wave: "-1"
spec:
  template:
    spec:
      # 1. Satisfy the enforce-non-root Kyverno policy rule
      securityContext:
        runAsNonRoot: true
        runAsUser: 10000
        runAsGroup: 10000
        fsGroup: 10000

      containers:
      - name: trivy
        # Pinning a specific stable version instead of volatile 'latest'
        image: aquasec/trivy:0.51.1
        imagePullPolicy: IfNotPresent
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "=== Running Trivy Pre-Sync Scan ==="
          # Point the cache directory explicitly to our writable emptyDir mount
          trivy --cache-dir /tmp/.cache/trivy image --exit-code 1 --severity CRITICAL nginx:1.27-alpine-slim
          echo "✅ Pre-sync scan passed"
        
        # 2. Satisfy the enforce-readonly-rootfs Kyverno policy rule
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]

        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi

        # 3. Mount an in-memory scratch space so Trivy can write its DB downloads
        volumeMounts:
        - name: cache-volume
          mountPath: /tmp

      volumes:
      - name: cache-volume
        emptyDir: {}

      restartPolicy: Never
  backoffLimit: 0 # Set to 0 so ArgoCD registers a security failure immediately instead of retrying

```

**Add this to your ArgoCD Application** (or use App of Apps).

---

## **Part 3: Integrate Lula (Compliance Validation)**

### 3.1 Create OSCAL Component Definition + Lula Manifest

### Initialize Lula

```bash
./lula ocm init

```

Create a new folder:

```bash
mkdir -p compliance

```

**compliance/nginx-component.yaml**

```yaml
apiVersion: oscal.mitre.org/v1alpha1
kind: ComponentDefinition
metadata:
  name: nginx-hardened-component
spec:
  title: "Hardened Nginx Application - Defense Unicorns Lab"
  description: "Sample application with Kyverno enforcement and STIG validation"
  components:
    - uuid: "e04b7b30-2223-4b6d-a7b2-123456789abc"
      name: nginx-deployment
      type: software
      description: "Nginx deployment protected by Kyverno"
      control-implementations:
        - uuid: "9b1deb4d-3b7d-4bad-9bdd-abcdef123456"
          source: "NIST-800-53"
          description: "Container Security Controls mapped to STIG rules"
          implemented-requirements:
            
            # --- Mapped Control 1: CM-7 (Covers Non-Root & Read-Only STIGs) ---
            - uuid: "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
              control-id: "cm-7"
              description: "Least Functionality - Enforcing STIG-Container-001 and STIG-Container-002"
              remarks:
                lula:
                  domain: kubernetes
                  provider:
                    type: oopa
                    manifest: |
                      validate:
                        # Test STIG-Container-001: Verifies Kyverno is blocking root containers
                        - name: STIG-Container-001-non-root
                          resource: clusterpolicy/enforce-hardening-baseline
                          field: spec.rules[?(@.name=='enforce-non-root')].validationFailureAction
                          value: Enforce

                        # Test STIG-Container-002: Verifies Kyverno is blocking writable root filesystems
                        - name: STIG-Container-002-readonly-rootfs
                          resource: clusterpolicy/enforce-hardening-baseline
                          field: spec.rules[?(@.name=='enforce-readonly-rootfs')].validationFailureAction
                          value: Enforce

            # --- Mapped Control 2: SC-7 ---
            - uuid: "f1e2d3c4-b5a6-9f8e-7d6c-5b4a3f2e1d0c"
              control-id: "sc-7"
              description: "Boundary Protection"
              remarks:
                lula:
                  domain: kubernetes
                  provider:
                    type: oopa
                    manifest: |
                      validate:
                        - name: check-production-namespace-status
                          resource: namespaces/production
                          field: status.phase
                          value: Active

```

---

### 3.2 Run Lula Validation

```bash
# Validate compliance
./lula validate -f compliance/lula-assessment.yaml

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

```