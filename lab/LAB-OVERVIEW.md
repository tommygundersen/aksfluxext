# GitOps with AKS and Flux Extension - Lab Overview

## 🎯 Learning Objectives

This hands-on lab provides a comprehensive introduction to GitOps principles using Azure Kubernetes Service (AKS) and the Flux extension. Students will gain practical experience with:

### Core GitOps Concepts
- **Declarative Configuration**: Understanding how to describe desired system state in Git
- **Git as Source of Truth**: Using Git repositories as the single source of truth for infrastructure and applications
- **Automated Synchronization**: Implementing automatic deployment of changes from Git to Kubernetes
- **Environment Management**: Managing multiple environments (dev/prod) with consistent processes

### Technical Skills
- **AKS Cluster Management**: Creating and configuring Azure Kubernetes Service clusters
- **Flux Extension**: Installing and configuring the Flux GitOps extension for AKS
- **Kustomize**: Using Kustomize for configuration management with base and overlay patterns
- **Azure CLI**: Using Azure CLI for cloud resource management
- **kubectl**: Managing Kubernetes resources with kubectl
- **Git Workflows**: Implementing GitOps workflows with Git repositories

### Real-World Application
- **Microservices Deployment**: Deploying a complex, multi-service application
- **Environment Promotion**: Managing configuration differences between environments
- **Scalability**: Understanding how to scale applications using GitOps principles
- **Monitoring**: Observing GitOps operations and troubleshooting issues

## 🏗️ Lab Architecture

### Application Components
The lab uses the **AKS Store Demo** application, which consists of:

```
Frontend Services:
├── store-front (React web app)
└── store-admin (Admin interface)

Backend Services:
├── order-service (Node.js - order processing)
├── product-service (Go - product catalog)
└── makeline-service (Python - order fulfillment)

Data & Messaging:
├── mongodb (Order database)
└── rabbitmq (Message queue)

Load Testing:
├── virtual-customer (Simulates customers)
└── virtual-worker (Simulates workers)
```

### Infrastructure Components
```
Azure Resources:
├── Resource Group
├── AKS Development Cluster (3 nodes)
├── AKS Production Cluster (3 nodes)
└── Managed Identities

GitOps Components:
├── Private GitHub Repository (secure)
├── GitHub Personal Access Token (authentication)
├── Flux Extension on each cluster
├── GitRepository Custom Resource (with HTTPS auth)
└── Kustomization Custom Resource
```

### Repository Structure
```
aks-store-<student-alias>/
├── base/                           # Base Kubernetes manifests
│   ├── kustomization.yaml         # Base kustomization config
│   ├── mongodb.yaml               # Database deployment
│   ├── rabbitmq.yaml              # Message queue
│   ├── order-service.yaml         # Order processing service
│   ├── product-service.yaml       # Product catalog service
│   ├── makeline-service.yaml      # Order fulfillment service
│   ├── store-front.yaml           # Web frontend
│   ├── store-admin.yaml           # Admin interface
│   ├── virtual-customer.yaml      # Load testing
│   └── virtual-worker.yaml        # Worker simulation
└── overlays/                      # Environment-specific configs
    ├── dev/                       # Development environment
    │   └── kustomization.yaml     # Dev-specific settings
    └── prod/                      # Production environment
        ├── kustomization.yaml     # Prod-specific settings
        └── patches/               # Production patches
            ├── order-service-replicas.yaml
            ├── product-service-replicas.yaml
            └── store-front-replicas.yaml
```

## 📚 Lab Flow and Timeline

### Phase 1: Infrastructure Setup (30 minutes)
1. **Environment Preparation** (5 min)
   - Set up Azure CLI and verify authentication
   - Configure environment variables
   - Create resource group

2. **Development Cluster Creation** (15 min)
   - Create AKS cluster with managed identity
   - Understand cluster configuration options
   - Monitor cluster creation progress

3. **GitHub Repository Setup** (10 min)
   - Create GitHub repository
   - Generate Personal Access Token
   - Clone repository locally

### Phase 2: GitOps Configuration (45 minutes)
4. **Kustomize Structure Creation** (20 min)
   - Understand Kustomize concepts
   - Create base manifests from monolithic YAML
   - Set up development overlay

5. **Flux Installation and Configuration** (15 min)
   - Install Flux extension on AKS
   - Configure GitOps synchronization
   - Verify automatic deployment

6. **Observe GitOps in Action** (10 min)
   - Monitor application deployment
   - Understand reconciliation process
   - Verify application functionality

### Phase 3: Production Environment (30 minutes)
7. **Production Cluster Setup** (15 min)
   - Create production AKS cluster
   - Install Flux extension
   - Configure production GitOps

8. **Production Overlay Configuration** (15 min)
   - Create production-specific patches
   - Understand environment differences
   - Deploy to production environment

### Phase 4: GitOps Workflow Testing (20 minutes)
9. **Configuration Updates** (10 min)
   - Modify production replica counts
   - Commit and push changes to Git
   - Observe automatic deployment

10. **Validation and Monitoring** (10 min)
    - Verify scaling operations
    - Compare environments
    - Monitor GitOps status

## 🛠️ Tools and Technologies

### Required Tools
- **Azure CLI**: Cloud resource management
- **kubectl**: Kubernetes cluster management
- **Git**: Version control and GitOps workflow
- **PowerShell**: Automation scripts (Windows users)

### Azure Services
- **Azure Kubernetes Service (AKS)**: Managed Kubernetes clusters
- **Azure Managed Identity**: Secure authentication without credentials
- **Azure Resource Groups**: Resource organization and management

### GitOps Stack
- **Flux v2**: GitOps toolkit for Kubernetes
- **Kustomize**: Configuration management tool
- **GitHub**: Git repository hosting and collaboration

### Application Stack
- **Frontend**: React (TypeScript)
- **Backend Services**: Node.js, Go, Python
- **Database**: MongoDB
- **Messaging**: RabbitMQ
- **Container Registry**: GitHub Container Registry

## 🎓 Skills Assessment

### Beginner Level (Basic Understanding)
- [ ] Understand what GitOps is and its benefits
- [ ] Create and manage AKS clusters
- [ ] Use Azure CLI for basic operations
- [ ] Navigate Kubernetes resources with kubectl
- [ ] Understand Git workflow basics

### Intermediate Level (Practical Application)
- [ ] Implement Kustomize base and overlay pattern
- [ ] Configure Flux for GitOps automation
- [ ] Manage multi-environment deployments
- [ ] Troubleshoot GitOps synchronization issues
- [ ] Monitor application deployments

### Advanced Level (Best Practices)
- [ ] Design scalable GitOps workflows
- [ ] Implement proper security practices
- [ ] Optimize resource utilization
- [ ] Design disaster recovery strategies
- [ ] Integrate monitoring and alerting

## 🔍 Key Learning Outcomes

### GitOps Principles Mastery
Students will understand and apply the four core GitOps principles:
1. **Declarative**: System state described declaratively
2. **Versioned and Immutable**: Stored in Git with complete version history
3. **Pulled Automatically**: Software agents pull from Git automatically
4. **Continuously Reconciled**: Agents ensure actual state matches desired state

### Practical DevOps Skills
- Infrastructure as Code (IaC) with Kubernetes manifests
- Configuration management with Kustomize
- Multi-environment deployment strategies
- Automated testing and validation
- Monitoring and observability

### Azure Cloud Expertise
- AKS cluster lifecycle management
- Azure security best practices with Managed Identity
- Azure CLI automation and scripting
- Resource organization and governance

## 🚀 Extension Opportunities

After completing the core lab, students can explore:

### Advanced GitOps Features
- **Progressive Delivery**: Implement canary deployments with Flagger
- **Image Automation**: Automatic container image updates
- **Multi-tenancy**: Separate GitOps configurations for different teams
- **Secrets Management**: Integrate with Azure Key Vault

### Monitoring and Observability
- **Application Monitoring**: Implement Prometheus and Grafana
- **Log Aggregation**: Set up centralized logging with Azure Monitor
- **Distributed Tracing**: Implement application tracing
- **Alerting**: Configure automated alerting systems

### Security Enhancements
- **Pod Security Standards**: Implement security policies
- **Network Policies**: Secure inter-service communication
- **Image Scanning**: Automated vulnerability scanning
- **Compliance**: Implement governance and compliance checks

### Production Readiness
- **High Availability**: Multi-region deployments
- **Backup and Recovery**: Implement backup strategies
- **Performance Optimization**: Resource optimization and tuning
- **Cost Management**: Implement cost monitoring and optimization

## 📖 Additional Resources

### Documentation
- [GitOps Principles](https://opengitops.dev/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Azure Kubernetes Service](https://docs.microsoft.com/azure/aks/)
- [Kustomize Documentation](https://kustomize.io/)

### Best Practices
- [GitOps Best Practices](https://fluxcd.io/flux/guides/best-practices/)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)

### Community
- [Flux Community](https://fluxcd.io/community/)
- [AKS Community](https://github.com/Azure/AKS)
- [CNCF GitOps Working Group](https://github.com/cncf/tag-app-delivery)

This lab provides a solid foundation for understanding and implementing GitOps practices in production environments, preparing students for real-world DevOps and platform engineering roles.