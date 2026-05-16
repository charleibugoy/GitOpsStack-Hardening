## Must-Know DoD Terms
- Iron Bank: Hardened signed images
- Platform One / Big Bang: DoD DevSecOps platform
- cATO: Continuous Authority to Operate
- Lula: Defense Unicorns compliance tool
- STIG: Security Technical Implementation Guides

## Hardening Principles
- Minimal base (slim/distroless)
- Non-root user + readOnlyRootFilesystem
- Patch + clean caches
- Sign images (Cosign)
- Scan with Trivy in CI

## Key Kyverno Policies
- Restrict registries → Iron Bank only
- Disallow root
- readOnlyRootFilesystem: true
- Default-Deny NetworkPolicy (auto-generate)

## Troubleshooting Order (BLUF)
1. kubectl describe pod
2. kubectl logs
3. Events + Probes
4. NetworkPolicy / CNI
5. Resources / Quotas

## Interview BLUF Formula
Conclusion → Why it matters for ATO → Tool/Technique → Example

## Tools Stack
- IaC: Ansible + Terraform + Helm
- GitOps: ArgoCD / Flux
- Security: Kyverno + Trivy + Cosign + Lula
- Observability: Prometheus + Grafana + Loki + Jaeger

Lab Architecture Overview

Terraform → Provision VPC + EKS Cluster
Ansible → Post-provision config + Kyverno policies
Helm → Package deployments (ArgoCD, Kyverno, Prometheus, etc.)
ArgoCD → GitOps continuous delivery + app of apps
Kyverno → Policy enforcement (STIGs, security)
Trivy → Image + config scanning (CI + Operator)
Lula → Compliance-as-Code (cATO simulation)
Prometheus + Grafana → Observability

Pre-requisites:
ArgoCD CLI:
    wget https://github.com/argoproj/argo-cd/releases/download/v2.4.11/argocd-linux-amd64
    mv argocd-linux-amd64 argocd
    chmod +x argocd
    mv argocd /usr/local/bin/
    argocd
AWS CLI
Kubectl CLI
Ansible
Docker
Terraform
Git
Lula


# Install tools
brew install terraform kubectl helm awscli argocd  # macOS
# or use apt / chocolatey on Linux/Windows

# AWS credentials
aws configure

# Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin



1. Deploy EKS Cluster Role CloudFormation:

aws cloudformation create-stack \
  --stack-name eks-cluster-role \
  --template-body file://eks-cluster-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM

1.5. Finding VPC and Subnet

# Find Default VPC
aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text

# List subnets in that VPC (look for private ones)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].{
    SubnetId: SubnetId, 
    AZ: AvailabilityZone, 
    AutoAssignPublicIP: MapPublicIpOnLaunch, 
    CIDR: CidrBlock
  }' \
  --output table

2. Deploy EKS Cluster (if using Terraform)
    1. git clone https://github.com/kodekloudhub/amazon-elastic-kubernetes-service-course
    2. cd amazon-elastic-kubernetes-service-course/eks
    3. terraform init -> terraform plan -> terraform apply -auto-approve
    4. After successful note the output values for NodeAutoScalingGroup, NodeInstanceRole, and NodeSecurityGroup
2.1 Deploy EKS Cluster (if using Console)
    1. From Amazon EKS, Create Cluster
    2. Select Custome configuration
    3. Turn Off "Use EKS Auto Mode"
    4. Cluster Configuration 
        Name: demo-eks
        Cluster IAM role: eksClusterRole
    5. Cluster Access -> Select Allow cluster administrator access
        Cluster authentication mode: EKS API and ConfigMap
    6. Networking
        VPC: select <default-vpc-id>
        Subnet: Select 2-3 default subnet. Take note of the subnet-id
    7. Create Cluster

  3. Using CloudShell
  aws eks update-kubeconfig --region us-east-1 --name demo-eks

  3.1 Verify EKS connection
  kubectl get all -A

  4. Create Key Pair
  Manually create RSA key via EC2 Console 
  or....
  Use AWS CLI
    # 1. Get the Key Pair ID
    KEY_PAIR_ID=$(aws ec2 describe-key-pairs \
  --key-names node-key-pair \
  --query "KeyPairs[0].KeyPairId" \
  --output text)

    # 2. Download the private key as .pem
    aws ssm get-parameter \
  --name "/ec2/keypair/${KEY_PAIR_ID}" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > node-key-pair.pem

    # 3. Secure the file
    chmod 400 node-key-pair.pem

5. Deploy Node Stack (Workers)
Use S3 URL: https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2022-12-23/amazon-eks-nodegroup.yaml

    1. Stack Name: eks-cluster-stack
    2. ClusterName: demo-eks
    3. ClusterControlPlaneSecurityGroup: Click in the box and select the one with a name that contains eks-cluster-sg
    4. NodeGroupName: eks-demo-node
    5. KeyName: (you will likely need to scroll down to find this) - node-key-pair as created above.
    6. VpcId: Click in the box and select the only entry that is there
    7. Subnets you selected for creating the EKS Cluster.
    8. Create stack

# Take note of NodeInstanceRole on the Output Tab.

6. Join Node Stack to EKS Cluster
    1. On the CloudShell, download node ConfigMap
    curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/aws-auth-cm.yaml
    2. Edit aws-auth-cm.yaml and replace the rolearn with the noted NodeInstanceRole. Save and exit
    3. Apply, kubectl apply -f aws-auth-cm.yaml
    4. Verify, kubectl get nodes
    5. Wait until all Nodes are in READY state

8. Install ArgoCD
    1. Create namespace and get install stable manifest from argocd:
        kubectl create namespace argocd
       kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/V2.4.11/manifests/install.yaml
    2. Expose ArgoCD server externally as LoadBalancer and forward Port
        kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
        kubectl port-forward svc/argocd-server -n argocd 8800:443
    or
    2.1 Expose ArgoCD server externally as NodepPort
        kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    3. Verify ArgoCD installation,
        kubectl get all -n argocd
    4. Get ArgoCD Secrets,
        kubectl get secret -n argocd
        4.1 Retrieve secret and output JSON format
        kubectl get secret argocd-inital-admin-secret -n argocd -o json
        4.2 Decode base64 password 
        kubectl get secret argocd-inital-admin-secret -n argocd -o json | jq .data.password -r | base64 -d
    5. Login to ArgoCD UI
        username: admin
        password: <decoded-password>

7. Install Prometheus Stack
    1. Add Prometheus Helm Repo
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
    2. Deploy Promethrus
        kubectl create ns monitoring
        helm install my-kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 40.1.2 -n monitoring
    3. Verify Prometheus
        kubectl -n monitoring get svc
    4. Login to Prometheus UI #Get NodePort IP
    5. Configure ServiceMonitor for ArgoCD
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

    6. Apply, kubectl -n argocd apply -f argocd-service-monitors.yaml
    7. Verify, kubectl -n argocd get servicemonitors
    8. Confirm release of each ServiceMonitor = Prometheus stack install
    kubectl -n monitoring get prometheus.monitoring.coreos.com -o yaml | grep -i servicemonitorselector -A5
8. Setting Up Grafana
    1. Identify Grafana Service and Change to NodePort,
    kubectl -n monitoring edit svc my-kube-prometheus-stack-grafana
    kubectl patch svc my-kube-prometheus-stack-grafana -n monitoring -p '{"spec": {"type": "NodePort"}}'
    2. Get Grafana Password,
    kubectl -n monitoring get secret my-kube-prometheus-stack-grafana -o json | jq -r '.data["admin-password"]' | base64 --decode
    3. Login to Grafana, http://NodeIP:31762
    Username: admin
    Password: <decodedPassword>
    