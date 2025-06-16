# Azure Pipelines

This directory contains Azure DevOps pipeline definitions for the Azure DevOps MCP Server project.

## Pipeline Files

### CI/CD Approach Options

You can choose between two approaches for your CI/CD pipelines:

#### Option 1: Separate CI and CD Pipelines (Recommended)

- **`build.yaml`** - Continuous Integration (CI) pipeline
  - Triggers on commits to main branch
  - Builds and pushes Docker image to Azure Container Registry
  - Publishes deployment artifacts and metadata

- **`deploy.yaml`** - Continuous Deployment (CD) pipeline
  - Triggered by completion of the build pipeline
  - Deploys the built container to Azure Container Apps
  - Performs health checks and notifications

#### Option 2: Combined Pipeline

- **`release.yaml`** - Combined build and deployment pipeline
  - Single pipeline that handles both build and deployment
  - Simpler setup but less flexible

## Configuration

### Build Pipeline (`build.yaml`)

**Variables to configure:**
- `dockerRegistryServiceConnection`: Your Azure Container Registry service connection ID
- `imageRepository`: Name of your container image repository
- `containerRegistry`: Your ACR hostname

### Deploy Pipeline (`deploy.yaml`)

**Variables to configure:**
- `azureServiceConnection`: Your Azure service connection name
- `environmentName`: Target environment name (e.g., 'prod', 'staging')
- `subscriptionId`: Your Azure subscription ID
- `location`: Azure region for deployment

**Pipeline Resource:**
- Update the `source` field in the pipeline resource to match your build pipeline name

### Prerequisites

1. **Azure Service Connections:**
   - Container Registry service connection for pushing images
   - Azure Resource Manager service connection for deployment

2. **Azure Resources:**
   - Azure Container Registry (configured in build pipeline)
   - Azure Container Apps environment and app (deployed via Bicep templates)

3. **Environments:**
   - Create Azure DevOps environments for deployment approval gates

## Usage

### Setting up Separate CI/CD Pipelines

1. **Create the Build Pipeline:**
   ```bash
   # In Azure DevOps, create a new pipeline using build.yaml
   # This will be your CI pipeline
   ```

2. **Create the Deploy Pipeline:**
   ```bash
   # In Azure DevOps, create a new pipeline using deploy.yaml
   # Update the pipeline resource source name to match your build pipeline
   ```

3. **Configure Pipeline Dependencies:**
   - The deploy pipeline will automatically trigger when the build pipeline completes successfully
   - You can also trigger deployments manually

### Setting up Combined Pipeline

1. **Create a Single Pipeline:**
   ```bash
   # In Azure DevOps, create a new pipeline using release.yaml
   # This handles both build and deployment in one pipeline
   ```

## Pipeline Artifacts

The build pipeline creates the following artifacts:

- **`source`**: Complete source code for the deployment
- **`infra`**: Infrastructure Bicep templates
- **`deployment-metadata`**: JSON file containing build information used by the deployment pipeline

## Environment Configuration

For production deployments, consider:

1. **Environment Protection:**
   - Add approval gates in Azure DevOps environments
   - Configure deployment conditions and checks

2. **Variable Groups:**
   - Use Azure DevOps variable groups for environment-specific configuration
   - Store sensitive values as secret variables

3. **Service Connections:**
   - Use separate service connections for different environments
   - Follow principle of least privilege

## Troubleshooting

### Common Issues

1. **Service Connection Issues:**
   - Verify service connection permissions
   - Check service principal expiration

2. **Container Registry Access:**
   - Ensure the service connection has push permissions to ACR
   - Verify ACR exists and is accessible

3. **Container Apps Deployment:**
   - Ensure infrastructure is deployed first (using `azd up` or Bicep)
   - Check Azure CLI version compatibility

### Logs and Monitoring

- Check pipeline logs in Azure DevOps
- Monitor container app logs in Azure Portal
- Use Application Insights for application monitoring
