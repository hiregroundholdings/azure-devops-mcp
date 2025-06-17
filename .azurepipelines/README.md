# Azure Pipelines

This directory contains Azure DevOps pipeline definitions for the Azure DevOps MCP Server project.

## Pipeline Files

### CI/CD Approach: Separate CI and CD Pipelines ✅

- **`build.yaml`** - Continuous Integration (CI) pipeline
  - Triggers on commits to main branch (excludes `.azure/**` and deployment pipeline changes)
  - Builds and pushes Docker image to Azure Container Registry
  - Publishes deployment metadata for consumption by CD pipeline

- **`deploy.yaml`** - Continuous Deployment (CD) pipeline
  - Triggered by:
    - Completion of the build pipeline (automatic container deployment)
    - Changes to `.azure/**` (infrastructure-only deployment)
    - Changes to the deployment pipeline itself
  - Deploys infrastructure using Bicep templates (from repository, not artifacts)
  - Conditionally updates container app (only when new build is available)
  - Performs health checks and notifications

- **`release.yaml`** - Combined build and deployment pipeline (legacy)
  - Single pipeline that handles both build and deployment
  - Kept for reference/fallback scenarios

## Key Features

### 🎯 **Smart Triggering**
- **Code changes** → Triggers build pipeline → Automatically triggers deployment
- **Infrastructure changes** → Triggers deployment pipeline only (no unnecessary builds)
- **Deployment pipeline changes** → Triggers deployment pipeline for self-validation

### 🔄 **Flexible Deployment Modes**

#### 1. **Full Deployment** (Build + Deploy)
When the build pipeline completes:
- Downloads build metadata with new image information
- Deploys infrastructure using latest Bicep templates
- Updates container app with newly built image
- Performs health verification

#### 2. **Infrastructure-Only Deployment**
When only infrastructure changes:
- Uses latest available container image from registry
- Deploys infrastructure updates using Bicep templates
- Skips container app image update (no new build)
- Performs health verification

### 🏗️ **Infrastructure Management**
- Infrastructure files (`.azure/**`) are sourced directly from the repository
- No infrastructure artifacts are published by the build pipeline
- Deployment pipeline uses `$(System.DefaultWorkingDirectory)/.azure/main.bicep`
- Supports both new deployments and incremental updates

## Configuration

### Build Pipeline (`build.yaml`)

**Variables to configure:**
- `dockerRegistryServiceConnection`: Your Azure Container Registry service connection ID
- `imageRepository`: Name of your container image repository
- `containerRegistry`: Your ACR hostname

**Trigger Configuration:**
```yaml
trigger:
  branches:
    include:
      - main
  paths:
    exclude:
      - .azurepipelines/deploy.yaml
      - .azurepipelines/release.yaml
      - .azure/**  # Infrastructure changes don't trigger builds
```

### Deploy Pipeline (`deploy.yaml`)

**Variables to configure:**
- `azureServiceConnection`: Your Azure service connection name
- `environmentName`: Target environment name (e.g., 'Production')
- `subscriptionId`: Your Azure subscription ID
- `location`: Azure region for deployment
- `azureDevOpsOrgName`: Your Azure DevOps organization name

**Trigger Configuration:**
```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - .azurepipelines/deploy.yaml  # Self-triggering
      - .azure/**                    # Infrastructure changes

resources:
  pipelines:
  - pipeline: ci
    source: 'ado-mcp-ci'            # Build pipeline name
    trigger:
      branches:
        include:
        - main
```

### Prerequisites

1. **Azure Service Connections:**
   - Container Registry service connection for pushing images
   - Azure Resource Manager service connection for deployment

2. **Azure Resources:**
   - Azure Container Registry (configured in build pipeline)
   - Appropriate RBAC permissions for subscription-level deployments

3. **Environments:**
   - Create Azure DevOps environments for deployment approval gates

## Deployment Flow Examples

### Scenario 1: Code Change
```
Developer commits code changes
↓
Build pipeline triggers (builds new container image)
↓
Build pipeline completes successfully
↓
Deploy pipeline triggers automatically
↓
Downloads build metadata with new image tag
↓
Deploys infrastructure + updates container with new image
```

### Scenario 2: Infrastructure Change
```
Developer modifies .azure/resources.bicep
↓
Deploy pipeline triggers directly (no build)
↓
No build metadata available
↓
Deploys infrastructure updates + keeps existing container image
```

### Scenario 3: Pipeline Configuration Change
```
Developer modifies .azurepipelines/deploy.yaml
↓
Deploy pipeline triggers to validate changes
↓
Tests pipeline changes with current infrastructure/container
```

## Bicep Infrastructure

### Key Features
- **RBAC Authorization**: Key Vault uses modern RBAC instead of access policies
- **Managed Identity**: Container apps use user-assigned managed identity
- **Role Assignments**: Automatic RBAC role assignments for Key Vault and ACR access
- **Subscription Scope**: Deployment creates resource group and all resources

### Role Assignments
- **Key Vault Secrets User**: Allows container app to read secrets
- **Key Vault Secrets Officer**: Allows deployment process to create secrets
- **ACR Pull**: Allows container app to pull images from registry

## Troubleshooting

### Common Issues

1. **Build Pipeline Not Triggering Deployment:**
   - Check pipeline resource configuration in `deploy.yaml`
   - Verify the CI pipeline name matches `source: 'ado-mcp-ci'`

2. **Infrastructure-Only Deployments Failing:**
   - Ensure container app exists (infrastructure creates it)
   - Check that fallback image `hireground.azurecr.io/adomcp:latest` exists

3. **Permission Issues:**
   - Verify service connection has Contributor access to subscription
   - Check that managed identity has proper RBAC roles assigned

### Logs and Monitoring

- **Build logs**: Check Azure DevOps pipeline history for build issues
- **Deployment logs**: Monitor ARM deployment progress in Azure portal
- **Container logs**: Use Azure Container Apps logs for runtime issues
- **Application Insights**: Monitor application performance and errors

## Migration Notes

If migrating from the old combined pipeline approach:
1. Update pipeline references to use the new `build.yaml` and `deploy.yaml`
2. Ensure environment and service connection configurations are correct
3. Test both code changes and infrastructure changes to verify triggers work
4. Consider removing the old `release.yaml` once new pipelines are stable
