# GitOps Lab Validation Script
# This script helps students validate their GitOps setup

param(
    [Parameter(Mandatory=$true)]
    [string]$StudentAlias,
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterType = "dev", # dev or prod
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

if ($Help) {
    Write-Host @"
GitOps Lab Validation Script

Usage:
    .\validate-lab.ps1 -StudentAlias "your-alias" [-ClusterType "dev"]

Parameters:
    -StudentAlias : Your unique identifier (required)
    -ClusterType  : Which cluster to validate: dev or prod (default: dev)
    -Help         : Show this help message

Examples:
    .\validate-lab.ps1 -StudentAlias "john"
    .\validate-lab.ps1 -StudentAlias "jane" -ClusterType "prod"
"@
    exit 0
}

if (-not $StudentAlias) {
    Write-Error "StudentAlias is required. Use -Help for usage information."
    exit 1
}

# Set variables
$ResourceGroup = "rg-aks-gitops-$StudentAlias"
if ($ClusterType -eq "prod") {
    $ClusterName = "aks-prod-$StudentAlias"
} else {
    $ClusterName = "aks-dev-$StudentAlias"
}

Write-Host "🔍 GitOps Lab Validation" -ForegroundColor Green
Write-Host "Student: $StudentAlias | Cluster: $ClusterName" -ForegroundColor Cyan

$validationResults = @()

# Function to add validation result
function Add-ValidationResult {
    param($Test, $Status, $Message, $Details = "")
    $validationResults += [PSCustomObject]@{
        Test = $Test
        Status = $Status
        Message = $Message
        Details = $Details
    }
}

# Test 1: Check if Azure CLI is authenticated
Write-Host "`n1️⃣  Checking Azure CLI authentication..." -ForegroundColor Yellow
try {
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if ($azAccount) {
        Add-ValidationResult "Azure CLI" "✅ PASS" "Authenticated as $($azAccount.user.name)"
    } else {
        Add-ValidationResult "Azure CLI" "❌ FAIL" "Not authenticated"
    }
} catch {
    Add-ValidationResult "Azure CLI" "❌ FAIL" "Azure CLI not found or not authenticated"
}

# Test 2: Check if resource group exists
Write-Host "2️⃣  Checking resource group..." -ForegroundColor Yellow
try {
    $rg = az group show --name $ResourceGroup 2>$null | ConvertFrom-Json
    if ($rg) {
        Add-ValidationResult "Resource Group" "✅ PASS" "Resource group '$ResourceGroup' exists in $($rg.location)"
    } else {
        Add-ValidationResult "Resource Group" "❌ FAIL" "Resource group '$ResourceGroup' not found"
    }
} catch {
    Add-ValidationResult "Resource Group" "❌ FAIL" "Failed to check resource group"
}

# Test 3: Check if AKS cluster exists and is running
Write-Host "3️⃣  Checking AKS cluster status..." -ForegroundColor Yellow
try {
    $cluster = az aks show --resource-group $ResourceGroup --name $ClusterName 2>$null | ConvertFrom-Json
    if ($cluster) {
        if ($cluster.provisioningState -eq "Succeeded") {
            Add-ValidationResult "AKS Cluster" "✅ PASS" "Cluster '$ClusterName' is running" "Kubernetes version: $($cluster.kubernetesVersion)"
        } elseif ($cluster.provisioningState -eq "Creating") {
            Add-ValidationResult "AKS Cluster" "⏳ PENDING" "Cluster '$ClusterName' is still being created"
        } else {
            Add-ValidationResult "AKS Cluster" "❌ FAIL" "Cluster '$ClusterName' is in state: $($cluster.provisioningState)"
        }
    } else {
        Add-ValidationResult "AKS Cluster" "❌ FAIL" "Cluster '$ClusterName' not found"
    }
} catch {
    Add-ValidationResult "AKS Cluster" "❌ FAIL" "Failed to check cluster status"
}

# Test 4: Check kubectl connectivity
Write-Host "4️⃣  Checking kubectl connectivity..." -ForegroundColor Yellow
try {
    # Try to get cluster credentials first
    az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing --output none 2>$null
    
    $nodes = kubectl get nodes --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $nodes) {
        $nodeCount = ($nodes | Measure-Object).Count
        Add-ValidationResult "kubectl" "✅ PASS" "Connected to cluster with $nodeCount nodes"
    } else {
        Add-ValidationResult "kubectl" "❌ FAIL" "Cannot connect to cluster"
    }
} catch {
    Add-ValidationResult "kubectl" "❌ FAIL" "kubectl not available or cluster not accessible"
}

# Test 5: Check if Flux extension is installed
Write-Host "5️⃣  Checking Flux extension..." -ForegroundColor Yellow
try {
    $fluxExtension = az k8s-extension show --cluster-name $ClusterName --resource-group $ResourceGroup --name flux --cluster-type managedClusters 2>$null | ConvertFrom-Json
    if ($fluxExtension -and $fluxExtension.installState -eq "Installed") {
        Add-ValidationResult "Flux Extension" "✅ PASS" "Flux extension is installed and ready"
    } elseif ($fluxExtension -and $fluxExtension.installState -eq "Installing") {
        Add-ValidationResult "Flux Extension" "⏳ PENDING" "Flux extension is being installed"
    } else {
        Add-ValidationResult "Flux Extension" "❌ FAIL" "Flux extension not found or failed to install"
    }
} catch {
    Add-ValidationResult "Flux Extension" "❌ FAIL" "Failed to check Flux extension"
}

# Test 6: Check Flux system pods
Write-Host "6️⃣  Checking Flux system pods..." -ForegroundColor Yellow
try {
    $fluxPods = kubectl get pods -n flux-system --no-headers 2>$null
    if ($LASTEXITCODE -eq 0 -and $fluxPods) {
        $readyPods = ($fluxPods | Where-Object { $_ -match "Running" } | Measure-Object).Count
        $totalPods = ($fluxPods | Measure-Object).Count
        if ($readyPods -eq $totalPods -and $totalPods -gt 0) {
            Add-ValidationResult "Flux Pods" "✅ PASS" "All $totalPods Flux pods are running"
        } else {
            Add-ValidationResult "Flux Pods" "⚠️  WARN" "$readyPods/$totalPods Flux pods are ready"
        }
    } else {
        Add-ValidationResult "Flux Pods" "❌ FAIL" "No Flux pods found in flux-system namespace"
    }
} catch {
    Add-ValidationResult "Flux Pods" "❌ FAIL" "Failed to check Flux pods"
}

# Test 7: Check GitOps configuration
Write-Host "7️⃣  Checking GitOps configuration..." -ForegroundColor Yellow
try {
    $fluxConfig = az k8s-configuration flux show --cluster-name $ClusterName --resource-group $ResourceGroup --name aks-store-config --cluster-type managedClusters 2>$null | ConvertFrom-Json
    if ($fluxConfig -and $fluxConfig.complianceState -eq "Compliant") {
        Add-ValidationResult "GitOps Config" "✅ PASS" "GitOps configuration is compliant"
    } elseif ($fluxConfig -and $fluxConfig.complianceState -eq "Pending") {
        Add-ValidationResult "GitOps Config" "⏳ PENDING" "GitOps configuration is being applied"
    } elseif ($fluxConfig) {
        Add-ValidationResult "GitOps Config" "❌ FAIL" "GitOps configuration state: $($fluxConfig.complianceState)"
    } else {
        Add-ValidationResult "GitOps Config" "❌ FAIL" "GitOps configuration not found"
    }
} catch {
    Add-ValidationResult "GitOps Config" "❌ FAIL" "Failed to check GitOps configuration"
}

# Test 8: Check application pods
Write-Host "8️⃣  Checking application deployment..." -ForegroundColor Yellow
try {
    $appPods = kubectl get pods --no-headers 2>$null | Where-Object { $_ -notmatch "flux-system" }
    if ($appPods) {
        $runningPods = ($appPods | Where-Object { $_ -match "Running" } | Measure-Object).Count
        $totalPods = ($appPods | Measure-Object).Count
        if ($runningPods -eq $totalPods) {
            Add-ValidationResult "Application Pods" "✅ PASS" "All $totalPods application pods are running"
        } else {
            Add-ValidationResult "Application Pods" "⚠️  WARN" "$runningPods/$totalPods application pods are ready"
        }
    } else {
        Add-ValidationResult "Application Pods" "❌ FAIL" "No application pods found"
    }
} catch {
    Add-ValidationResult "Application Pods" "❌ FAIL" "Failed to check application pods"
}

# Test 9: Check services
Write-Host "9️⃣  Checking services..." -ForegroundColor Yellow
try {
    $services = kubectl get services --no-headers 2>$null
    if ($services) {
        $serviceCount = ($services | Measure-Object).Count
        $loadBalancers = ($services | Where-Object { $_ -match "LoadBalancer" } | Measure-Object).Count
        Add-ValidationResult "Services" "✅ PASS" "$serviceCount services found ($loadBalancers LoadBalancers)"
    } else {
        Add-ValidationResult "Services" "❌ FAIL" "No services found"
    }
} catch {
    Add-ValidationResult "Services" "❌ FAIL" "Failed to check services"
}

# Display results
Write-Host "`n📊 Validation Results:" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Gray

$passCount = ($validationResults | Where-Object { $_.Status -like "*PASS*" } | Measure-Object).Count
$failCount = ($validationResults | Where-Object { $_.Status -like "*FAIL*" } | Measure-Object).Count
$warnCount = ($validationResults | Where-Object { $_.Status -like "*WARN*" } | Measure-Object).Count
$pendingCount = ($validationResults | Where-Object { $_.Status -like "*PENDING*" } | Measure-Object).Count

foreach ($result in $validationResults) {
    Write-Host "$($result.Status) $($result.Test): $($result.Message)" -ForegroundColor White
    if ($result.Details) {
        Write-Host "    $($result.Details)" -ForegroundColor Gray
    }
}

Write-Host "`n📈 Summary:" -ForegroundColor Yellow
Write-Host "✅ Passed: $passCount" -ForegroundColor Green
Write-Host "❌ Failed: $failCount" -ForegroundColor Red
Write-Host "⚠️  Warnings: $warnCount" -ForegroundColor Yellow
Write-Host "⏳ Pending: $pendingCount" -ForegroundColor Cyan

if ($failCount -eq 0 -and $pendingCount -eq 0) {
    Write-Host "`n🎉 All validations passed! Your GitOps setup is working correctly." -ForegroundColor Green
} elseif ($pendingCount -gt 0) {
    Write-Host "`n⏳ Some components are still being set up. Wait a few minutes and run validation again." -ForegroundColor Cyan
} else {
    Write-Host "`n🔧 Some issues were found. Check the failed tests and refer to the lab documentation." -ForegroundColor Yellow
}

# Additional information commands
if ($passCount -gt 5) {
    Write-Host "`n🔍 Useful commands for monitoring:" -ForegroundColor Yellow
    Write-Host "kubectl get pods -A" -ForegroundColor Cyan
    Write-Host "kubectl get services" -ForegroundColor Cyan
    Write-Host "kubectl get gitrepository,kustomization -A" -ForegroundColor Cyan
    Write-Host "kubectl logs -n flux-system deployment/kustomize-controller" -ForegroundColor Cyan
}