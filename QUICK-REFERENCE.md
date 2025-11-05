# GitOps with AKS and Flux - Quick Reference

## Quick Commands Cheat Sheet

### Environment Setup
```bash
# Set your variables
STUDENT_ALIAS="your-alias"
RESOURCE_GROUP="rg-aks-gitops-${STUDENT_ALIAS}"
DEV_CLUSTER_NAME="aks-dev-${STUDENT_ALIAS}"
PROD_CLUSTER_NAME="aks-prod-${STUDENT_ALIAS}"
LOCATION="eastus"
GITHUB_USER="your-github-username"
GITHUB_REPO="aks-store-${STUDENT_ALIAS}"
```

### Cluster Creation
```bash
# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create dev cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $DEV_CLUSTER_NAME \
  --node-count 3 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --location $LOCATION \
  --no-wait

# Create prod cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $PROD_CLUSTER_NAME \
  --node-count 3 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --location $LOCATION \
  --no-wait
```

### Flux Extension Installation
```bash
# Install Flux extension
az k8s-extension create \
  --cluster-name $DEV_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --cluster-type managedClusters \
  --extension-type microsoft.flux \
  --name flux
```

### GitOps Configuration
```bash
# Configure Flux for dev (with private repo authentication)
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

# Production cluster GitOps configuration
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

### Git Workflow (Essential!)
```bash
# IMPORTANT: Always commit and push before configuring Flux!

# Add all files
git add .

# Commit changes
git commit -m "Add Kustomize structure for GitOps deployment"

# Push to GitHub
git push origin main

# Update configurations (after initial setup)
git add .
git commit -m "Scale production services to 3 replicas"
git push origin main
```

### Monitoring Commands
```bash
# Check cluster status
az aks show --resource-group $RESOURCE_GROUP --name $DEV_CLUSTER_NAME --query provisioningState

# Get cluster credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $DEV_CLUSTER_NAME

# Check pods
kubectl get pods

# Check services
kubectl get services

# Check Flux status
kubectl get gitrepository,kustomization -A

# Watch deployments
kubectl get deployments -w

# Check specific deployment rollout
kubectl rollout status deployment/order-service
```

## Useful Commands

### kubectl Context Management
```bash
# Switch between clusters
kubectl config use-context dev-context
kubectl config use-context prod-context

# Check current context
kubectl config current-context
```

### Flux Commands
```bash
# Check GitRepository status
kubectl get gitrepository -A

# Check Kustomization status
kubectl get kustomization -A

# Describe specific resources
kubectl describe gitrepository aks-store-config
kubectl describe kustomization aks-store-config-dev

# Force reconciliation (when you want immediate sync)
kubectl annotate gitrepository -n default aks-store-config reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl annotate kustomization -n default aks-store-config-prod reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

### Flux Reconciliation Timing
```bash
# Check reconciliation intervals (how often Flux checks for changes)
kubectl get gitrepository -A -o custom-columns="NAME:.metadata.name,NAMESPACE:.metadata.namespace,INTERVAL:.spec.interval,LAST-SYNC:.status.conditions[?(@.type=='Ready')].lastTransitionTime"
kubectl get kustomization -A -o custom-columns="NAME:.metadata.name,NAMESPACE:.metadata.namespace,INTERVAL:.spec.interval,LAST-APPLIED:.status.conditions[?(@.type=='Ready')].lastTransitionTime"

# Check specific resource timing details
kubectl get gitrepository aks-store-config -o yaml | grep -A2 -B2 interval
kubectl get kustomization aks-store-config-prod -o yaml | grep -A2 -B2 interval

# Monitor reconciliation timing in detail
kubectl describe gitrepository aks-store-config | grep -E "Interval|Last Transition Time|Ready"
kubectl describe kustomization aks-store-config-prod | grep -E "Interval|Last Transition Time|Ready"

# Check when last reconciliation occurred
kubectl get gitrepository aks-store-config -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}'
kubectl get kustomization aks-store-config-prod -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}'

# Current vs desired state timing
kubectl get gitrepository aks-store-config -o jsonpath='{.status.artifact.lastUpdateTime}'
kubectl get kustomization aks-store-config-prod -o jsonpath='{.status.lastAppliedRevision}'
```

### Flux Monitoring & Debugging
```bash
# Watch Flux controllers in real-time (use separate terminals)
kubectl logs -n flux-system deployment/kustomize-controller -f
kubectl logs -n flux-system deployment/source-controller -f
kubectl get gitrepository -A -w
kubectl get kustomization -A -w

# Check last reconciliation status
kubectl get gitrepository -o jsonpath='{.items[0].status.artifact.revision}'
kubectl get kustomization -o jsonpath='{.items[0].status.lastAppliedRevision}'

# Troubleshooting commands
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
kubectl describe kustomization -A | grep -A10 -B5 conditions
```

### Troubleshooting
```bash
# Check Flux system status
kubectl get pods -n flux-system
kubectl get gitrepository,kustomization -A

# Check detailed status
kubectl describe gitrepository -n flux-system aks-store-config
kubectl describe kustomization -n flux-system aks-store-config-dev

# Check Flux logs
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller

# Force reconciliation (make Flux sync immediately)
# First check which namespace contains your resources:
kubectl get gitrepository,kustomization -A
# Then use the correct namespace (typically 'default' with Azure CLI):
kubectl annotate gitrepository -n default aks-store-config reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl annotate kustomization -n default aks-store-config-dev reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Test kustomization locally
kubectl kustomize overlays/dev

# Check application status
kubectl get pods
kubectl get deployments
kubectl get services

# Check events for errors
kubectl get events --sort-by=.metadata.creationTimestamp

# Check node status
kubectl get nodes

# Check resource usage
kubectl top nodes
kubectl top pods
```

## Common Issues and Solutions

### Issue: GitRepository authentication failed
**Solution**: Check and reset your GitHub credentials
```bash
# Verify credentials
echo $GITHUB_USER
echo $GITHUB_TOKEN

# Reset if needed
export GITHUB_TOKEN="your_token_here"
export GITHUB_USER="your_username"

# Delete and recreate Flux configuration
az k8s-configuration flux delete --cluster-name $DEV_CLUSTER_NAME --resource-group $RESOURCE_GROUP --name aks-store-config --cluster-type managedClusters --yes
# Then recreate with correct credentials (see main README for full command)
```

### Issue: Flux can't find manifests or shows "path not found"
**Solution**: Make sure you've committed and pushed your Kustomize structure to GitHub
```bash
# Check if files are committed
git status

# If not committed, add and push them
git add .
git commit -m "Add missing manifests"
git push origin main

# Force Flux to reconcile immediately (use correct namespace)
kubectl annotate gitrepository -n default aks-store-config reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

### Issue: Services can't find each other (connection refused, host not found)
**Solution**: Check if you accidentally used namePrefix in kustomization.yaml
```bash
# This breaks service discovery:
# namePrefix: dev-    # REMOVE THIS!

# Services expect original names like 'order-service', not 'dev-order-service'
# Remove namePrefix from overlays/dev/kustomization.yaml and overlays/prod/kustomization.yaml
# Then commit and push the fix:
git add .
git commit -m "Remove namePrefix to fix service discovery"
git push origin main

# Force reconciliation
kubectl annotate gitrepository -n default aks-store-config reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

### Issue: Cluster creation timeout
**Solution**: Check Azure quotas and try different regions
```bash
az vm list-usage --location $LOCATION --output table
```

### Issue: Flux not syncing
**Solutions**:
1. Check repository access and PAT permissions
2. Verify the repository URL and branch
3. Check Flux controller logs

### Issue: Pods stuck in Pending
**Solutions**:
1. Check node resources: `kubectl describe nodes`
2. Check pod events: `kubectl describe pod <pod-name>`
3. Verify resource requests and limits

### Issue: Services not accessible
**Solutions**:
1. Check service endpoints: `kubectl get endpoints`
2. Verify LoadBalancer external IP: `kubectl get svc`
3. Check Azure Load Balancer configuration

## Best Practices Reminders

### **⏰ Flux Timing Expectations**
- **GitRepository Interval**: `1m0s` (Git polling)
- **Kustomization Interval**: `1m0s` (applying changes - configured in lab)
- **Expected Delay**: 1-2 minutes for automatic deployment
- **Quick Fix**: Use force reconciliation for immediate sync

### **General Best Practices**
1. **Never commit secrets to Git** - Use Azure Key Vault or sealed secrets
2. **Use resource limits** - Prevent resource starvation
3. **Implement health checks** - Readiness and liveness probes
4. **Monitor applications** - Use Azure Monitor or Prometheus
5. **Regular backups** - Backup cluster state and persistent data
6. **Security scanning** - Scan container images for vulnerabilities
7. **Network policies** - Implement network segmentation
8. **RBAC** - Use least privilege access principles

## Additional Resources

- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)