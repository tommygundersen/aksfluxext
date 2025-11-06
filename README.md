# GitOps with Azure Kubernetes Service (AKS) and Flux Extension Lab

## Overview
This hands-on lab will teach you how to implement GitOps workflows using Azure Kubernetes Service (AKS) and the Flux extension. You'll deploy a complex microservices application (AKS Store Demo) using GitOps principles with Kustomize for environment-specific configurations.

## Learning Objectives
By the end of this lab, you will:
- Understand GitOps principles and how they apply to Kubernetes
- Create and configure AKS clusters with managed identity
- Install and configure the Flux extension for AKS
- Implement Kustomize with base and overlay patterns
- Deploy applications using GitOps workflows
- Manage environment-specific configurations (dev/prod)
- Observe automatic deployments triggered by Git changes

## Prerequisites
- Azure subscription with contributor access
- Azure CLI installed and configured
- Git installed
- GitHub account
- Basic knowledge of Kubernetes concepts
- Familiarity with YAML syntax

## Architecture Overview
The AKS Store Demo application consists of several microservices:
- **store-front**: React-based web frontend
- **order-service**: Node.js service handling orders
- **product-service**: Go service managing product catalog
- **makeline-service**: Python service for order processing
- **store-admin**: Administrative interface
- **virtual-customer**: Load testing simulation
- **virtual-worker**: Worker simulation
- **mongodb**: Database for order storage
- **rabbitmq**: Message queue for service communication

## Lab Structure
```
aks-store-<student-alias>/
├── base/
│   ├── kustomization.yaml
│   ├── mongodb.yaml
│   ├── rabbitmq.yaml
│   ├── order-service.yaml
│   ├── product-service.yaml
│   ├── makeline-service.yaml
│   ├── store-front.yaml
│   ├── store-admin.yaml
│   ├── virtual-customer.yaml
│   └── virtual-worker.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patches/
    └── prod/
        ├── kustomization.yaml
        └── patches/
            ├── order-service-replicas.yaml
            ├── product-service-replicas.yaml
            └── store-front-replicas.yaml
```

---

## Step 1: Create Development AKS Cluster

Let's start by creating a development AKS cluster. We'll use managed identity for secure access and the `--no-wait` flag to run the creation in the background.

### 1.1 Set Environment Variables
First, set up your environment variables. Replace `<your-alias>` with your unique identifier:

```bash
# Set your unique alias (use your name/initials)
STUDENT_ALIAS="<your-alias>"

# Set resource group and cluster names
RESOURCE_GROUP="rg-aks-gitops-${STUDENT_ALIAS}"
DEV_CLUSTER_NAME="aks-dev-${STUDENT_ALIAS}"
PROD_CLUSTER_NAME="aks-prod-${STUDENT_ALIAS}"
LOCATION="swedencentral"
```

### 1.2 Create Resource Group
```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### 1.3 Create Development Cluster
Create the development cluster with 3 nodes and managed identity:

```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $DEV_CLUSTER_NAME \
  --node-count 3 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --location $LOCATION \
  --no-wait
```

**What's happening here?**
- `--enable-managed-identity`: Uses Azure Managed Identity for secure authentication without storing credentials
- `--node-count 3`: Creates a 3-node cluster suitable for running our microservices
- `--generate-ssh-keys`: Automatically generates SSH keys for node access
- `--no-wait`: Starts cluster creation in background, allowing us to continue with other tasks

### 1.4 Check Cluster Creation Status
You can monitor the cluster creation progress:
```bash
az aks list --resource-group $RESOURCE_GROUP --output table
```

---

## Step 2: Create GitHub Repository and Personal Access Token

While the AKS cluster is being created, let's set up our Git repository and access tokens.

### 2.1 Create GitHub Repository
1. Go to [GitHub](https://github.com) and sign in
2. Click the "+" icon and select "New repository"
3. Name your repository: `aks-store-<your-alias>` (replace `<your-alias>` with your identifier)
4. Choose **Private** for better security (we'll configure authentication for Flux)
5. Initialize with a README
6. Click "Create repository"

### 2.2 Clone Repository Locally
```bash
git clone https://github.com/<your-github-username>/aks-store-<your-alias>.git
cd aks-store-<your-alias>
```

### 2.3 Create Personal Access Token (PAT)
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: "AKS GitOps Lab"
4. Set expiration to 30 days (sufficient for the lab)
5. Select these scopes:
   - `repo` (Full control of private repositories)
   - `write:packages` (if you plan to use GitHub packages)
6. Click "Generate token"
7. **IMPORTANT**: Copy the token immediately and store it securely

### 2.4 Store PAT Securely
```bash
# Store your PAT in an environment variable (replace with your actual token)
export GITHUB_TOKEN="ghp_your_token_here"
export GITHUB_USER="your-github-username"
export GITHUB_REPO="aks-store-${STUDENT_ALIAS}"
```

**Security Note**: Never commit your PAT to Git. Using private repositories with authentication provides better security than public repositories. In production scenarios, consider using Azure Key Vault or managed identity for even more secure authentication.

**Private Repository Benefits**:
- Enhanced security - your code isn't publicly visible
- Better access control - only authorized users can access the repository
- Compliance - meets enterprise security requirements
- Audit trail - track who has access to your GitOps configurations

---

## Step 3: Create Kustomize Structure

Now let's create the Kustomize directory structure and split the monolithic YAML into manageable components.

### 3.1 Create Directory Structure
```bash
mkdir -p base overlays/dev overlays/prod/patches
```

### 3.2 Create Base Components
We'll split the original `aks-store-all-in-one.yaml` into logical components for better maintainability.

Create `base/mongodb.yaml`:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: mongodb
          image: mcr.microsoft.com/mirror/docker/library/mongo:4.2
          ports:
            - containerPort: 27017
              name: mongodb
          resources:
            requests:
              cpu: 5m
              memory: 75Mi
            limits:
              cpu: 25m
              memory: 1024Mi
          livenessProbe:
            exec:
              command:
                - mongosh
                - --eval
                - db.runCommand('ping').ok
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
spec:
  ports:
    - port: 27017
  selector:
    app: mongodb
  type: ClusterIP
```

**Continue with the remaining base components...**

### 3.3 Create Complete Kustomize Structure
Since creating all the individual YAML files manually would be time-consuming, copy the complete structure from the lab materials:

```bash
# Copy the kustomize-structure directory from the lab materials to your repository
cp -r /path/to/lab/kustomize-structure/* .
```

Or manually create all the files using the provided examples in the `kustomize-structure` directory of this lab.

### 3.4 Create Development Overlay
Create `overlays/dev/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
  - ../../base

commonLabels:
  environment: dev
```

**Important Note**: We don't use `namePrefix` because it would change service names (e.g., `order-service` → `dev-order-service`), breaking internal service discovery. Services are hardcoded to communicate using the original names.

### 3.5 Create Production Overlay
Create `overlays/prod/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
  - ../../base

commonLabels:
  environment: prod

commonLabels:
  environment: prod

patches:
  - path: patches/order-service-replicas.yaml
    target:
      kind: Deployment
      name: order-service
  - path: patches/product-service-replicas.yaml
    target:
      kind: Deployment
      name: product-service
  - path: patches/store-front-replicas.yaml
    target:
      kind: Deployment
      name: store-front
```

Create the replica patches in `overlays/prod/patches/`:

`order-service-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 2
```

`product-service-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 2
```

`store-front-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 2
```

### 3.6 Commit and Push to GitHub
**IMPORTANT**: Before configuring Flux, you must commit and push your Kustomize structure to GitHub so Flux can access it:

```bash
# Add all files to git
git add .

# Commit with a descriptive message
git commit -m "Add initial Kustomize structure with base and overlays

- Base manifests for all AKS Store Demo services
- Development overlay with dev- prefix
- Production overlay with scaled replicas (2 replicas)
- Ready for GitOps deployment with Flux"

# Push to GitHub
git push origin main
```

**Verify your repository structure**:
Your GitHub repository should now contain:
```
aks-store-<your-alias>/
├── README.md
├── base/
│   ├── kustomization.yaml
│   ├── mongodb.yaml
│   ├── rabbitmq.yaml
│   ├── order-service.yaml
│   ├── product-service.yaml
│   ├── makeline-service.yaml
│   ├── store-front.yaml
│   ├── store-admin.yaml
│   ├── virtual-customer.yaml
│   └── virtual-worker.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        ├── kustomization.yaml
        └── patches/
            ├── order-service-replicas.yaml
            ├── product-service-replicas.yaml
            └── store-front-replicas.yaml
```

**GitOps Principle**: Remember, Git is your source of truth. Flux will pull from this repository, so all your Kubernetes manifests must be committed and pushed before Flux can deploy them.

---

## Step 4: Install Flux Extension on Development Cluster

Once your development cluster is ready and your manifests are pushed to GitHub, install the Flux extension.

### 4.1 Check Cluster Status
```bash
az aks show --resource-group $RESOURCE_GROUP --name $DEV_CLUSTER_NAME --query provisioningState
```

Wait until the status shows "Succeeded".

### 4.2 Get Cluster Credentials
```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $DEV_CLUSTER_NAME
```

### 4.3 Install Flux Extension
```bash
az k8s-extension create \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --cluster-type managedClusters \
  --extension-type microsoft.flux \
  --name flux
```

**What's happening?**
- Installs Flux controllers in the `flux-system` namespace
- Sets up GitOps operators for source, kustomize, and helm controllers
- Enables automatic synchronization between Git and cluster state

### 4.4 Verify Flux Installation
```bash
kubectl get pods -n flux-system
```

You should see pods like:
- `source-controller`
- `kustomize-controller`
- `helm-controller`
- `notification-controller`

---

## Step 5: Configure Flux GitOps

Now we'll configure Flux to monitor our Git repository and automatically deploy changes.

### 5.1 Create Flux Configuration
Since we're using a private repository, we need to configure authentication for Flux to access it:

```bash
az k8s-configuration flux create \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-config \
  --namespace default \
  --scope cluster \
  --cluster-type managedClusters \
  --url https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
  --branch main \
  --https-user ${GITHUB_USER} \
  --https-key ${GITHUB_TOKEN} \
  --kustomization name=dev path=./overlays/dev prune=true interval=1m
```

**Configuration Explanation:**
- `--namespace default`: Deploys applications to the default namespace
- `--scope cluster`: Gives Flux cluster-wide permissions
- `--url`: Your GitHub repository URL
- `--branch main`: Monitors the main branch
- `--https-user`: Your GitHub username for authentication
- `--https-key`: Your GitHub Personal Access Token for authentication
- `--kustomization`: Tells Flux to apply the dev overlay
- `prune=true`: Removes resources that are no longer in Git

### 5.2 Verify Configuration
```bash
az k8s-configuration flux show \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-config \
  --cluster-type managedClusters
```

### 5.3 Monitor GitOps Sync
```bash
kubectl get gitrepository,kustomization -A
```

**Understanding GitOps:**
GitOps follows the principle of "Git as the single source of truth." Any changes to your application configuration in Git will automatically be applied to your Kubernetes cluster. This ensures:
- **Declarative**: Entire system state is described in Git
- **Versioned**: All changes are tracked with Git history
- **Immutable**: Deployments are reproducible
- **Auditable**: Complete audit trail of who changed what and when

---

## Step 5.5: Troubleshooting GitOps Deployment

If your deployment isn't working as expected, follow these troubleshooting steps:

### 5.5.1 Check Flux System Status
First, verify that Flux controllers are running properly:

```bash
# Check Flux system pods
kubectl get pods -n flux-system

# Check for any failed pods
kubectl get pods -n flux-system | grep -v Running
```

All pods should be in "Running" status. If any are failing, check their logs:
```bash
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
```

### 5.5.2 Check GitRepository and Kustomization Status
```bash
# Check if Git repository is accessible
kubectl get gitrepository -A

# Check kustomization status
kubectl get kustomization -A

# Get detailed status (look for error messages)
kubectl describe gitrepository -n flux-system aks-store-config
kubectl describe kustomization -n flux-system aks-store-config-dev
```

**Common Issues and Solutions:**

#### Issue: GitRepository shows "authentication failed"
**Solution:** Check your GitHub credentials:
```bash
# Verify your environment variables are set
echo $GITHUB_USER
echo $GITHUB_TOKEN

# If empty, reset them:
export GITHUB_TOKEN="your_token_here"
export GITHUB_USER="your_username"

# Delete and recreate the Flux configuration
az k8s-configuration flux delete \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-config \
  --cluster-type managedClusters \
  --yes

# Recreate with correct credentials
az k8s-configuration flux create \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-config \
  --namespace default \
  --scope cluster \
  --cluster-type managedClusters \
  --url https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
  --branch main \
  --https-user ${GITHUB_USER} \
  --https-key ${GITHUB_TOKEN} \
  --kustomization name=dev path=./overlays/dev prune=true interval=1m
```

#### Issue: Kustomization shows "path not found" or "no matches for kind"
**Solution:** This usually means your manifests have issues:
```bash
# Test your kustomization locally first
kubectl kustomize overlays/dev

# Check for syntax errors in your YAML files
# Fix any issues in your repository, then commit and push:
git add .
git commit -m "Fix YAML syntax errors"
git push origin main
```

### 5.5.3 Force Flux Reconciliation
By default in this lab, both Git polling and Kustomization sync happen every 1 minute, but you can force immediate reconciliation:

```bash
# First, identify which namespace contains your GitRepository and Kustomization
kubectl get gitrepository,kustomization -A

# The GitRepository is typically in the default namespace when created via Azure CLI
# Force GitRepository to sync immediately (use --overwrite if annotation exists)
kubectl annotate gitrepository -n default aks-store-config reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Force Kustomization to reconcile immediately (also typically in default namespace)
kubectl annotate kustomization -n default aks-store-config-dev reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Watch the reconciliation process
kubectl get gitrepository,kustomization -A -w
```

**Note**: The Azure CLI typically creates GitRepository and Kustomization resources in the `default` namespace, not `flux-system`. Always check with `kubectl get gitrepository,kustomization -A` first.

### 5.5.4 Update Repository and Force Sync Workflow
If you need to make changes to fix deployment issues:

```bash
# 1. Make changes to your manifests locally
# 2. Test changes locally (optional but recommended)
kubectl kustomize overlays/dev | kubectl apply --dry-run=client -f -

# 3. Commit and push changes
git add .
git commit -m "Fix deployment configuration"
git push origin main

# 4. Force immediate reconciliation (use correct namespace and overwrite flag)
kubectl annotate gitrepository -n default aks-store-config reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# 5. Monitor the deployment
kubectl get pods -w
```

### 5.5.5 Check Application Status
Once Flux is working, verify your application pods are starting:

```bash
# Check all pods in default namespace
kubectl get pods

# Check specific deployments
kubectl get deployments

# Check services
kubectl get services

# Check for events that might indicate issues
kubectl get events --sort-by=.metadata.creationTimestamp

# Check specific pod logs if something is failing
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### 5.5.6 Complete Reset (if needed)
If things are completely broken, you can start fresh:

```bash
# Delete all application resources
kubectl delete all --all

# Delete Flux configuration
az k8s-configuration flux delete \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-config \
  --cluster-type managedClusters \
  --yes

# Wait a moment, then recreate
# (Use the flux create command from Step 5.1)
```

**💡 Pro Tip:** Keep the Flux documentation handy: https://fluxcd.io/docs/troubleshooting/

---

## Step 6: Create Production Cluster

While observing the dev deployment, let's create the production cluster.

### 6.1 Create Production Cluster
```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $PROD_CLUSTER_NAME \
  --node-count 3 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --location $LOCATION \
  --no-wait
```

---

## Step 7: Create Production Overlay

While the production cluster is being created, let's prepare the production-specific configurations.

### 7.1 Create Production Kustomization
Create `overlays/prod/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
  - ../../base

patches:
  - path: patches/order-service-replicas.yaml
    target:
      kind: Deployment
      name: order-service
  - path: patches/product-service-replicas.yaml
    target:
      kind: Deployment
      name: product-service
  - path: patches/store-front-replicas.yaml
    target:
      kind: Deployment
      name: store-front
```

### 7.2 Create Replica Patches
Create `overlays/prod/patches/order-service-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 2
```

Create `overlays/prod/patches/product-service-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 2
```

Create `overlays/prod/patches/store-front-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 2
```

**Kustomize Patches Explained:**
- JSON Patch format for precise modifications
- `op: replace`: Replaces the value at the specified path
- `path: /spec/replicas`: Targets the replica count in the deployment spec
- `value: 2`: Sets production replica count to 2 for high availability

### 7.3 Commit Changes
```bash
git add .
git commit -m "Add production overlay with scaled replicas"
git push origin main
```

---

## Step 8: Configure Production Flux

Once the production cluster is ready, configure it for GitOps.

### 8.1 Check Production Cluster Status
```bash
az aks show --resource-group $RESOURCE_GROUP --name $PROD_CLUSTER_NAME --query provisioningState
```

### 8.2 Switch to Production Context
```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $PROD_CLUSTER_NAME --context prod-context
kubectl config use-context prod-context
```

### 8.3 Install Flux on Production
```bash
az k8s-extension create \
  --cluster-name $PROD_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --cluster-type managedClusters \
  --extension-type microsoft.flux \
  --name flux
```

### 8.4 Configure Production GitOps
```bash
az k8s-configuration flux create \
  --cluster-name $PROD_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-config \
  --namespace default \
  --scope cluster \
  --cluster-type managedClusters \
  --url https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
  --branch main \
  --https-user ${GITHUB_USER} \
  --https-key ${GITHUB_TOKEN} \
  --kustomization name=prod path=./overlays/prod prune=true interval=1m
```

**Production Considerations:**
- Uses the same Git repository but different overlay path
- Production overlay includes replica scaling for high availability
- Separate cluster ensures environment isolation
- Same GitOps principles apply: Git is the source of truth

---

## Step 9: Test GitOps Updates

Now let's test the GitOps workflow by updating replica counts and observing automatic deployments.

### 9.1 Verify Current Production Deployment
Before making changes, let's confirm that the production environment is running with the expected 2 replicas for our scaled services:

```bash
# Switch to production cluster context
kubectl config use-context prod-context

# Check current replica counts for scaled services
kubectl get deployments

# Specifically check the three services we're scaling
kubectl get deployment order-service -o wide
kubectl get deployment product-service -o wide
kubectl get deployment store-front -o wide

# Count running pods for each service
echo "=== Current Production Pod Counts ==="
echo "Order Service pods:"
kubectl get pods -l app=order-service | grep Running | wc -l
echo "Product Service pods:"
kubectl get pods -l app=product-service | grep Running | wc -l
echo "Store Front pods:"
kubectl get pods -l app=store-front | grep Running | wc -l
```

**Expected Output**: You should see 2 replicas for each of the three services (order-service, product-service, store-front), while other services should have 1 replica.

**If you don't see 2 replicas**: 
- Check that your production GitOps configuration is working
- Verify that the production overlay patches were applied correctly
- Use the troubleshooting steps from Step 5.5 if needed

### 9.2 Update Production Replicas to Scale Further
Now that we've confirmed the current state, let's scale from 2 to 3 replicas:

Update `overlays/prod/patches/order-service-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 3
```

Update `overlays/prod/patches/product-service-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 3
```

Update `overlays/prod/patches/store-front-replicas.yaml`:
```yaml
- op: replace
  path: /spec/replicas
  value: 3
```

### 9.3 Commit and Push Changes
```bash
git add overlays/prod/patches/
git commit -m "Scale production services to 3 replicas"
git push origin main
```

### 9.4 Observe Automatic Deployment
Monitor the changes being applied automatically:

```bash
# Switch to production context (if not already there)
kubectl config use-context prod-context

# FIRST: Force reconciliation to speed up the process
kubectl annotate gitrepository -n default aks-store-config reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Monitor Flux reconciliation in real-time (open separate terminals for these)
# Terminal 1: Watch GitRepository sync status
kubectl get gitrepository -A -w

# Terminal 2: Watch Kustomization reconciliation logs
kubectl logs -n flux-system deployment/kustomize-controller -f

# Terminal 3: Watch source controller logs (Git polling)
kubectl logs -n flux-system deployment/source-controller -f

# Terminal 4: Watch deployment changes in real-time
kubectl get deployments -w

# Check if Flux has detected your changes
kubectl describe gitrepository -n default aks-store-config | grep -A5 -B5 "revision\|status"

# Check kustomization status for any errors
kubectl describe kustomization -n default aks-store-config-prod | grep -A10 -B5 "status\|conditions"

# Check specific deployment status
kubectl rollout status deployment/order-service
kubectl rollout status deployment/product-service
kubectl rollout status deployment/store-front
```

**Troubleshooting if replicas aren't increasing:**

1. **Check if Git changes were detected:**
```bash
# Should show your latest commit SHA
kubectl get gitrepository -n default aks-store-config -o jsonpath='{.status.artifact.revision}'

# Compare with your Git commit
git log --oneline -1
```

2. **Check kustomization errors:**
```bash
# Look for error messages
kubectl get kustomization -n default aks-store-config-prod -o yaml | grep -A10 -B10 conditions

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
```

3. **Force reconciliation if needed:**
```bash
kubectl annotate kustomization -n default aks-store-config-prod reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

4. **Check reconciliation cycle timing:**
```bash
# See configured intervals (both should now be 1m)
kubectl get gitrepository aks-store-config -o jsonpath='{.spec.interval}' && echo " (Git polling interval)"
kubectl get kustomization aks-store-config-prod -o jsonpath='{.spec.interval}' && echo " (Kustomization sync interval)"

# Check when last reconciliation occurred
echo "Last Git sync: $(kubectl get gitrepository aks-store-config -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')"
echo "Last Kustomization apply: $(kubectl get kustomization aks-store-config-prod -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')"

# Monitor timing in real-time
kubectl get gitrepository aks-store-config -w
```

**GitOps Magic in Action:**
1. You pushed changes to Git
2. Flux detected the changes (usually within 1 minute via GitRepository)
3. **Flux applies changes quickly (1-minute Kustomization interval)**
4. Flux automatically applied the new replica counts
5. Kubernetes rolled out the changes with zero manual intervention

⏰ **Timing Note**: Changes should appear within 1-2 minutes since we configured both Git polling and Kustomization sync to 1-minute intervals.

### 9.5 Verify Scaling
```bash
# Check that all services now have 3 replicas
echo "=== Final Production Pod Counts ==="
echo "Order Service pods:"
kubectl get pods -l app=order-service | grep Running | wc -l
echo "Product Service pods:"
kubectl get pods -l app=product-service | grep Running | wc -l
echo "Store Front pods:"
kubectl get pods -l app=store-front | grep Running | wc -l

# Alternative: See all pods with labels
kubectl get pods -l app=order-service
kubectl get pods -l app=product-service
kubectl get pods -l app=store-front
```

You should now see **3 pods** for each service instead of 2. This demonstrates the complete GitOps workflow:
- **Step 9.1**: Verified 2 replicas were running
- **Step 9.2**: Updated configuration to 3 replicas
- **Step 9.3**: Committed changes to Git
- **Step 9.4**: Observed automatic deployment
- **Step 9.5**: Confirmed scaling to 3 replicas

---

## Step 10: Monitoring and Validation

Let's validate that our GitOps setup is working correctly and explore monitoring capabilities.

### 10.1 Check Application Status
```bash
# Get all pods
kubectl get pods

# Check service endpoints
kubectl get services

# Get ingress/load balancer status
kubectl get services store-front
kubectl get services store-admin
```

### 10.2 Access the Application
Get the external IP of the store-front service:
```bash
kubectl get service store-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Open a browser to the external IP to see the running application.

### 10.3 Monitor Flux Status
```bash
# Check GitRepository sync status
kubectl get gitrepository -A

# Check Kustomization status
kubectl get kustomization -A

# View Flux logs
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
```

### 10.4 Compare Environments
Switch between contexts to compare dev and prod deployments:

```bash
# Check dev environment
kubectl config use-context <dev-context-name>
kubectl get deployments

# Check prod environment
kubectl config use-context prod-context
kubectl get deployments
```

Notice how dev has 1 replica per service while prod has 3 replicas.

---

## Conclusion and Best Practices

Congratulations! You've successfully implemented a complete GitOps workflow with AKS and Flux. Here's what you've accomplished:

### ✅ What You've Learned
- **GitOps Principles**: Git as the single source of truth for infrastructure and applications
- **Kustomize Patterns**: Base configurations with environment-specific overlays
- **Flux Extension**: Automated GitOps for AKS clusters
- **Environment Management**: Separate dev and prod configurations
- **Automated Deployments**: Zero-touch deployments triggered by Git commits

### 🚀 Best Practices Implemented
1. **Managed Identity**: Secure authentication without storing credentials
2. **Environment Isolation**: Separate clusters for dev and prod
3. **Infrastructure as Code**: All configurations stored in Git
4. **Declarative Management**: Desired state defined in YAML
5. **Automated Reconciliation**: Flux ensures cluster state matches Git state

### 🔧 Production Considerations
For production deployments, consider these additional practices:

1. **Monitoring**: Implement Prometheus and Grafana for observability
2. **Security**: Use private Git repositories and secure webhook configurations
3. **Backup**: Regular cluster and application backups
4. **Disaster Recovery**: Multi-region deployments
5. **Access Control**: RBAC and pod security policies
6. **Secrets Management**: Azure Key Vault integration
7. **Network Security**: Network policies and private clusters

### 🎯 Next Steps
- Explore Flux notifications for Slack/Teams integration
- Implement Helm charts for complex application deployments
- Add image automation for automatic container updates
- Set up monitoring and alerting with Azure Monitor
- Implement progressive delivery with Flagger

### 📚 Additional Resources
- [Flux Documentation](https://fluxcd.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [AKS GitOps Best Practices](https://docs.microsoft.com/azure/aks/gitops)
- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)

---

## Step 11: Extra Material - Deploy with Helm Chart (Alternative Approach)

In this bonus section, we'll explore how to deploy the same AKS Store Demo application using Helm charts instead of Kustomize. This demonstrates an alternative GitOps approach and provides experience with Helm package management.

### 11.1 Understanding Helm vs Kustomize

**Helm Benefits:**
- **Template Engine**: Dynamic value substitution and conditional logic
- **Package Management**: Versioned releases with rollback capabilities  
- **Dependency Management**: Manage chart dependencies centrally
- **Community Ecosystem**: Large repository of pre-built charts

**When to Use Helm:**
- Complex applications with many configuration variations
- Need for dynamic configuration generation
- Package distribution and versioning requirements
- Integration with external chart repositories

### 11.2 Understanding Helm vs Kustomize

**Helm Benefits:**
- **Template Engine**: Dynamic value substitution and conditional logic
- **Package Management**: Versioned releases with rollback capabilities  
- **Dependency Management**: Manage chart dependencies centrally
- **Community Ecosystem**: Large repository of pre-built charts

**When to Use Helm:**
- Complex applications with many configuration variations
- Need for dynamic configuration generation
- Package distribution and versioning requirements
- Integration with external chart repositories

### 11.3 GitOps with Helm and Flux

Now let's integrate Helm charts with Flux for GitOps automation. First, create the directory structure:

```bash
mkdir -p helm-gitops/{dev,prod}
```

Create `helm-gitops/dev/helmrelease.yaml`:
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: aks-store-helm-dev
  namespace: default
spec:
  interval: 1m
  targetNamespace: helm-demo
  chart:
    spec:
      chart: aks-store-demo
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: azure-samples
        namespace: flux-system
      interval: 1m
  values:
    # Development values inline
    namespace: helm-demo
    storeFront:
      replicas: 1
      service:
        type: LoadBalancer
    storeAdmin:
      replicas: 1
      service:
        type: LoadBalancer  
    orderService:
      replicas: 1
    productService:
      replicas: 1
    makelineService:
      replicas: 1
    aiService:
      create: false
    mongodb:
      persistence:
        enabled: false
      resources:
        requests:
          memory: "128Mi"
          cpu: "50m"
    rabbitmq:
      resources:
        requests:
          memory: "128Mi"
          cpu: "50m"
```

Create `helm-gitops/prod/helmrelease.yaml`:
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: aks-store-helm-prod
  namespace: default
spec:
  interval: 1m
  targetNamespace: helm-demo
  chart:
    spec:
      chart: aks-store-demo
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: azure-samples
        namespace: flux-system
      interval: 1m
  values:
    # Production values inline
    namespace: helm-demo
    storeFront:
      replicas: 3
      service:
        type: LoadBalancer
      resources:
        requests:
          memory: "256Mi"
          cpu: "100m"
        limits:
          memory: "512Mi"
          cpu: "250m"
    storeAdmin:
      replicas: 2
      service:
        type: LoadBalancer
      resources:
        requests:
          memory: "256Mi"
          cpu: "100m"
        limits:
          memory: "512Mi"
          cpu: "250m"
    orderService:
      replicas: 3
      resources:
        requests:
          memory: "256Mi"
          cpu: "100m"
        limits:
          memory: "512Mi"
          cpu: "250m"
    productService:
      replicas: 3
      resources:
        requests:
          memory: "256Mi"
          cpu: "100m"
        limits:
          memory: "512Mi"
          cpu: "250m"
    makelineService:
      replicas: 2
      resources:
        requests:
          memory: "256Mi"
          cpu: "100m"
        limits:
          memory: "512Mi"
          cpu: "250m"
    aiService:
      create: false
    mongodb:
      persistence:
        enabled: true
        size: 10Gi
      resources:
        requests:
          memory: "512Mi"
          cpu: "200m"
        limits:
          memory: "1Gi"
          cpu: "500m"
    rabbitmq:
      persistence:
        enabled: true
        size: 5Gi
      resources:
        requests:
          memory: "512Mi"
          cpu: "200m"
        limits:
          memory: "1Gi"
          cpu: "500m"
```

Create `helm-gitops/helmrepository.yaml`:
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: azure-samples-charts
  namespace: flux-system
spec:
  interval: 1h
  url: https://github.com/Azure-Samples/aks-store-demo
  ref:
    branch: main
```

**Understanding Chart Sources:**

This GitRepository resource points to the **Azure Samples GitHub repository** that contains Helm chart source code. Unlike a traditional HelmRepository (which serves packaged charts), this references a Git repository containing chart source files.

**Azure Samples Repository Structure:**
- **Repository URL**: `https://github.com/Azure-Samples/aks-store-demo`
- **Actual Structure**: The repository contains chart source code in the `/charts/` directory
- **Chart Location**: `/charts/aks-store-demo/` directory in the repository
- **Layout**:
  ```
  https://github.com/Azure-Samples/aks-store-demo/
  ├── charts/
  │   └── aks-store-demo/
  │       ├── Chart.yaml              # Chart metadata
  │       ├── values.yaml             # Default values
  │       └── templates/              # Kubernetes templates
  │           ├── deployment.yaml
  │           ├── service.yaml
  │           └── ...
  └── ...
  ```

**How Flux Resolves the Chart:**
When you reference the chart in a HelmRelease, Flux:
1. **Clones** the repository from the GitRepository URL
2. **Locates** the chart using the path specified in the HelmRelease `chart.spec.chart` field
3. **Renders** templates with your values
4. **Applies** the generated manifests to Kubernetes

**Chart Reference in HelmRelease:**
```yaml
chart:
  spec:
    chart: aks-store-demo              # This specifies the chart path/name
    sourceRef:
      kind: GitRepository             # Points to the repository
      name: aks-store-demo-charts
```

**Important**: The `chart: aks-store-demo` field tells Flux to look for the chart at `/charts/aks-store-demo/` directory in the repository. This follows the standard Helm chart repository convention where charts are stored in a `/charts/` subdirectory.


**Azure Samples Convention:**
The Azure Samples repository follows a common convention of storing charts under `/charts/`, but this is **not automatic**. Flux only knows to look there because:
- The chart name `aks-store-demo` matches the directory `/charts/aks-store-demo/`
- The repository is structured to support this naming pattern

**Traditional Helm Repository vs Source Repository:**
- **Traditional**: Contains `index.yaml` and pre-packaged `.tgz` files
- **Source Repository** (like Azure Samples): Contains raw chart source code
- **Flux Advantage**: Can work with both approaches seamlessly

**If you wanted to create your own source-based chart repository:**
1. **Chart Source**: Store chart source in `./charts/my-chart/` directory
2. **Host Repository**: Serve via GitHub Pages or web server  
3. **Reference**: Point HelmRepository to your hosted URL

For this lab, we're using the Azure Samples source repository to demonstrate how Flux can consume charts directly from source code.

**⚠️ IMPORTANT: Resource Conflicts Warning**

Before proceeding with Helm-based GitOps, you need to understand that **both approaches will conflict** if deployed simultaneously:

**Resource Conflicts:**
- Both Kustomize and Helm will try to create the same Kubernetes resources
- Same resource names in the same namespace will cause conflicts
- Flux will report errors when trying to apply duplicate resources

**Conflict Resolution Options:**

1. **Use Different Namespaces** (Recommended for this lab):
```yaml
# In HelmRelease, use different namespace
metadata:
  name: aks-store-helm
  namespace: helm-demo  # Different namespace

spec:
  targetNamespace: helm-demo  # Deploy to different namespace
```

2. **Delete Existing Kustomize Deployment** (Alternative):
```bash
# Remove existing Kustomize-based deployment first
az k8s-configuration flux delete \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-config \
  --cluster-type managedClusters \
  --yes

# Wait for resources to be cleaned up
kubectl delete all -l app.kubernetes.io/managed-by=kustomize-controller
```

3. **Different Resource Names** (Advanced):
```yaml
# In Helm values, use different name prefixes
nameOverride: "helm-aks-store"
fullnameOverride: "helm-aks-store-demo"
```

**Recommendation for This Lab:**
- **Keep your existing Kustomize deployment** running in the `default` namespace
- **Deploy Helm version** to a separate `helm-demo` namespace  
- **Compare both approaches** side by side
- **Clean up one before production** use

This allows you to see both GitOps approaches working without conflicts.

### 11.4 Configure Flux for Helm-based GitOps

Commit the Helm GitOps files to your repository:

```bash
# Add Helm GitOps files
git add helm-gitops/ helm-values/
git commit -m "Add Helm-based GitOps configuration

- HelmRepository for Azure Samples charts
- HelmRelease for dev and prod environments  
- Helm values files for manual deployment
- Alternative GitOps approach using Helm instead of Kustomize"

git push origin main
```

Update your Flux configuration to use Helm:

```bash
# Development cluster - switch to Helm approach
kubectl config use-context dev-context

# Delete existing Kustomize-based configuration
az k8s-configuration flux delete \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-config \
  --cluster-type managedClusters \
  --yes

# Create new Helm-based Flux configuration  
az k8s-configuration flux create \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-helm-config \
  --namespace default \
  --scope cluster \
  --cluster-type managedClusters \
  --url https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
  --branch main \
  --https-user ${GITHUB_USER} \
  --https-key ${GITHUB_TOKEN} \
  --kustomization name=helm-dev path=./helm-gitops/dev prune=true interval=1m
```

### 11.5 Monitor Helm-based GitOps Deployment

```bash
# Check HelmRepository sync
kubectl get helmrepository -A

# Check HelmRelease status
kubectl get helmrelease -A

# Watch Helm controller logs
kubectl logs -n flux-system deployment/helm-controller -f

# Check deployment status with Helm
helm list --all-namespaces

# Verify pods are running
kubectl get pods
```

### 11.6 Update Application with Helm GitOps

Let's test updating replicas using the Helm approach:

Update `helm-gitops/prod/helmrelease.yaml` to scale further:
```yaml
# Change replica counts in the values section
storeFront:
  replicas: 5  # Changed from 3 to 5
orderService:
  replicas: 5  # Changed from 3 to 5  
productService:
  replicas: 5  # Changed from 3 to 5
```

Commit and observe:
```bash
git add helm-gitops/prod/helmrelease.yaml
git commit -m "Scale production services to 5 replicas using Helm"
git push origin main

# Monitor the Helm-based deployment
kubectl get helmrelease aks-store-prod -w
helm history aks-store-prod
kubectl get pods -l app=store-front
```

### 11.7 Helm vs Kustomize Comparison

**Helm Advantages:**
- **Templates**: Dynamic value substitution (`{{ .Values.replicas }}`)
- **Release Management**: Built-in versioning, rollbacks, upgrades
- **Charts Ecosystem**: Reusable packages from community
- **Conditional Logic**: `{{ if .Values.feature.enabled }}`
- **Dependency Management**: Chart dependencies with version constraints

**Kustomize Advantages:**
- **Template-Free**: Pure YAML without templating complexity
- **Patch-Based**: Surgical modifications to base configurations
- **Git-Friendly**: Easy to read diffs and review changes
- **Kubernetes Native**: Built into kubectl
- **Simpler**: Less learning curve for YAML-familiar teams

**Use Helm When:**
- Managing complex applications with many configuration options
- Need packaging and distribution capabilities
- Require dynamic configuration generation
- Working with community charts

**Use Kustomize When:**
- Prefer declarative, template-free approach
- Need simple environment-specific modifications
- Want git-friendly configuration management
- Have straightforward application requirements

### 11.8 Cleanup Helm Deployment

If you want to clean up the Helm deployment:

```bash
# Delete Flux Helm configuration
az k8s-configuration flux delete \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --name aks-store-helm-config \
  --cluster-type managedClusters \
  --yes

# Verify cleanup
kubectl get helmrelease -A
kubectl get helmrepository -A
```

## Step 11 Summary

You've successfully explored Helm as an alternative to Kustomize for GitOps deployments! Key takeaways:

- **Helm Charts**: Provide templating and package management capabilities
- **GitOps Integration**: Flux supports both Kustomize and Helm workflows
- **HelmRelease CRD**: Enables declarative Helm deployments in GitOps
- **Values Management**: Environment-specific configuration through values files
- **Release Management**: Built-in versioning, rollback, and upgrade capabilities

Both approaches (Kustomize and Helm) are valid for GitOps and can be chosen based on your team's needs and application complexity.

---

## Cleanup (Optional)

When you're done with the lab, clean up the resources:

```bash
# Delete resource group (removes all resources)
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Delete local repository
cd ..
rm -rf aks-store-<your-alias>
```

Remember to also delete your GitHub repository if you no longer need it.

---

**Great job completing the GitOps with AKS and Flux lab!** You now have hands-on experience with modern Kubernetes deployment practices using GitOps principles.