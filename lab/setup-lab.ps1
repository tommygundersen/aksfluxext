# GitOps Lab Setup Script
# This script helps students set up their environment for the GitOps lab

param(
    [Parameter(Mandatory=$true)]
    [string]$StudentAlias,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubUser,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipClusterCreation,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateProdCluster,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

if ($Help) {
    Write-Host @"
GitOps Lab Setup Script

Usage:
    .\setup-lab.ps1 -StudentAlias "your-alias" [-Location "eastus"] [-GitHubUser "username"] [-SkipClusterCreation] [-CreateProdCluster]

Parameters:
    -StudentAlias       : Your unique identifier (required)
    -Location          : Azure region (default: eastus)
    -GitHubUser        : Your GitHub username
    -SkipClusterCreation: Skip AKS cluster creation
    -CreateProdCluster : Also create production cluster
    -Help              : Show this help message

Examples:
    .\setup-lab.ps1 -StudentAlias "john" -GitHubUser "johnsmith"
    .\setup-lab.ps1 -StudentAlias "jane" -Location "westus2" -CreateProdCluster
"@
    exit 0
}

# Validate parameters
if (-not $StudentAlias) {
    Write-Error "StudentAlias is required. Use -Help for usage information."
    exit 1
}

# Set environment variables
$ResourceGroup = "rg-aks-gitops-$StudentAlias"
$DevClusterName = "aks-dev-$StudentAlias"
$ProdClusterName = "aks-prod-$StudentAlias"
$GitHubRepo = "aks-store-$StudentAlias"

Write-Host "🚀 Starting GitOps Lab Setup" -ForegroundColor Green
Write-Host "Student Alias: $StudentAlias" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan

# Check if Azure CLI is installed and user is logged in
Write-Host "`n📋 Checking prerequisites..." -ForegroundColor Yellow

try {
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        Write-Error "Please login to Azure CLI first: az login"
        exit 1
    }
    Write-Host "✅ Azure CLI authenticated as: $($azAccount.user.name)" -ForegroundColor Green
} catch {
    Write-Error "Azure CLI not found or not authenticated. Please install Azure CLI and run 'az login'"
    exit 1
}

# Check if kubectl is installed
try {
    kubectl version --client --short 2>$null | Out-Null
    Write-Host "✅ kubectl is installed" -ForegroundColor Green
} catch {
    Write-Warning "kubectl not found. You'll need to install it to manage the cluster."
}

# Check if git is installed
try {
    git --version 2>$null | Out-Null
    Write-Host "✅ git is installed" -ForegroundColor Green
} catch {
    Write-Warning "git not found. You'll need it to work with repositories."
}

# Create resource group
Write-Host "`n🏗️  Creating resource group..." -ForegroundColor Yellow
try {
    az group create --name $ResourceGroup --location $Location --output none
    Write-Host "✅ Resource group '$ResourceGroup' created" -ForegroundColor Green
} catch {
    Write-Error "Failed to create resource group: $_"
    exit 1
}

if (-not $SkipClusterCreation) {
    # Create development cluster
    Write-Host "`n🔧 Creating development AKS cluster..." -ForegroundColor Yellow
    Write-Host "This will take 5-10 minutes. The cluster will be created in the background." -ForegroundColor Cyan
    
    try {
        az aks create `
            --resource-group $ResourceGroup `
            --name $DevClusterName `
            --node-count 3 `
            --enable-managed-identity `
            --generate-ssh-keys `
            --location $Location `
            --no-wait `
            --output none
        
        Write-Host "✅ Development cluster creation started: $DevClusterName" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create development cluster: $_"
        exit 1
    }

    if ($CreateProdCluster) {
        # Create production cluster
        Write-Host "`n🏭 Creating production AKS cluster..." -ForegroundColor Yellow
        
        try {
            az aks create `
                --resource-group $ResourceGroup `
                --name $ProdClusterName `
                --node-count 3 `
                --enable-managed-identity `
                --generate-ssh-keys `
                --location $Location `
                --no-wait `
                --output none
            
            Write-Host "✅ Production cluster creation started: $ProdClusterName" -ForegroundColor Green
        } catch {
            Write-Error "Failed to create production cluster: $_"
            exit 1
        }
    }
}

# Display environment variables for the student
Write-Host "`n📝 Environment Variables (copy these for later use):" -ForegroundColor Yellow
Write-Host @"
`$STUDENT_ALIAS="$StudentAlias"
`$RESOURCE_GROUP="$ResourceGroup"
`$DEV_CLUSTER_NAME="$DevClusterName"
`$PROD_CLUSTER_NAME="$ProdClusterName"
`$LOCATION="$Location"
"@ -ForegroundColor Cyan

if ($GitHubUser) {
    Write-Host "`$GITHUB_USER="$GitHubUser"" -ForegroundColor Cyan
    Write-Host "`$GITHUB_REPO="$GitHubRepo"" -ForegroundColor Cyan
}

# GitHub setup instructions
Write-Host "`n🐙 GitHub Setup Instructions:" -ForegroundColor Yellow
Write-Host "1. Create a new repository: https://github.com/new" -ForegroundColor White
Write-Host "   - Repository name: $GitHubRepo" -ForegroundColor Cyan
Write-Host "   - Make it Private (for better security)" -ForegroundColor White
Write-Host "   - Initialize with README" -ForegroundColor White
Write-Host "`n2. Create a Personal Access Token: https://github.com/settings/tokens" -ForegroundColor White
Write-Host "   - Select 'repo' scope (required for private repositories)" -ForegroundColor White
Write-Host "   - Copy the token for later use" -ForegroundColor White
Write-Host "`n3. Store your GitHub credentials securely:" -ForegroundColor White
Write-Host "   export GITHUB_TOKEN=`"your_token_here`"" -ForegroundColor Cyan
Write-Host "   export GITHUB_USER=`"$GitHubUser`"" -ForegroundColor Cyan

# Next steps
Write-Host "`n🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Wait for cluster creation to complete (check with: az aks list --resource-group $ResourceGroup --output table)" -ForegroundColor White
Write-Host "2. Clone your GitHub repository locally" -ForegroundColor White
Write-Host "3. Copy the kustomize structure from this lab to your repository" -ForegroundColor White
Write-Host "4. Set your GitHub credentials as environment variables" -ForegroundColor White
Write-Host "5. IMPORTANT: Commit and push your changes to GitHub before configuring Flux!" -ForegroundColor Red
Write-Host "6. Follow the lab instructions to install Flux and configure GitOps" -ForegroundColor White

# Monitoring commands
Write-Host "`n🔍 Useful monitoring commands:" -ForegroundColor Yellow
Write-Host "# Check cluster creation status:" -ForegroundColor White
Write-Host "az aks list --resource-group $ResourceGroup --output table" -ForegroundColor Cyan
Write-Host "`n# Get cluster credentials when ready:" -ForegroundColor White
Write-Host "az aks get-credentials --resource-group $ResourceGroup --name $DevClusterName" -ForegroundColor Cyan

Write-Host "`n🎉 Setup script completed successfully!" -ForegroundColor Green
Write-Host "Continue with the lab instructions in README.md" -ForegroundColor Cyan