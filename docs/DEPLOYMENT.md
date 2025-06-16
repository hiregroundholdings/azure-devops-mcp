# Deploying Azure DevOps MCP Server to Azure Container Apps

This guide explains how to deploy the Azure DevOps MCP Server to Azure Container Apps so your entire team can access it without needing individual local installations.

## Prerequisites

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Azure Developer CLI (azd)** - [Install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
3. **Node.js 20+** - [Install Node.js](https://nodejs.org/)
4. **Docker** (optional) - Only needed for local testing

## Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd azure-devops-mcp

# Install dependencies
npm install

# Copy environment template
cp .env.example .env
```

### 2. Configure Environment Variables

Edit the `.env` file and update:

```bash
# Required: Your Azure DevOps organization name
AZURE_ORGANIZATION_NAME=your-organization-name

# Azure environment settings
AZURE_ENV_NAME=dev
AZURE_LOCATION=eastus
```

### 3. Login to Azure

```bash
# Login to Azure
az login

# Initialize azd (if not already done)
azd init
```

### 4. Deploy to Azure

```bash
# Deploy the application
azd up
```

This will:
- Create a resource group
- Set up Azure Container Apps environment
- Create Application Insights for monitoring
- Set up Key Vault for secrets
- Create Container Registry
- Deploy the MCP server as a container app

### 5. Access the Service

After deployment, you'll get an endpoint URL. The service provides:

- **Health check**: `https://your-app.azurecontainerapps.io/health`
- **MCP endpoint**: `https://your-app.azurecontainerapps.io/sse`
- **Info endpoint**: `https://your-app.azurecontainerapps.io/`

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   VS Code +     │    │  Azure Container │    │  Azure DevOps   │
│ GitHub Copilot  │◄──►│      Apps        │◄──►│  Organization   │
│    (Client)     │    │  (MCP Server)    │    │   (REST API)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ Azure Resources  │
                    │ • Key Vault      │
                    │ • App Insights   │
                    │ • Log Analytics  │
                    │ • Container Reg  │
                    └──────────────────┘
```

## Security

The deployment uses Azure managed identity for secure authentication:

- **System-assigned managed identity** for the container app
- **Key Vault** for storing sensitive configuration
- **Azure DevOps authentication** via DefaultAzureCredential
- **RBAC** for minimal required permissions

## Team Access

### Option 1: Direct MCP Connection (Recommended)

Team members can configure their local VS Code to connect to the deployed MCP server:

1. Create `.vscode/mcp.json` in your project:

```json
{
  "servers": {
    "azure-devops-remote": {
      "type": "sse",
      "url": "https://your-app.azurecontainerapps.io/sse"
    }
  }
}
```

### Option 2: Proxy Configuration

For more complex scenarios, you can set up authentication proxies or API gateways.

## Monitoring

The deployment includes monitoring through:

- **Application Insights** - Application performance and errors
- **Log Analytics** - Container logs and metrics
- **Azure Monitor** - Infrastructure monitoring
- **Health checks** - Service availability

Access monitoring via:
- Azure Portal → Resource Group → Application Insights
- Logs: `az containerapp logs show --name ca-<resourceToken> --resource-group rg-<envName>`

## Scaling

The container app is configured with:
- **Min replicas**: 1 (always running)
- **Max replicas**: 3 (auto-scale based on demand)
- **CPU**: 0.5 cores
- **Memory**: 1GB

Modify scaling in `infra/resources.bicep`:

```bicep
scale: {
  minReplicas: 2      // Always have 2 instances
  maxReplicas: 10     // Scale up to 10 instances
}
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```bash
   # Check managed identity configuration
   az identity show --name mi-<resourceToken> --resource-group rg-<envName>
   ```

2. **Container Startup Issues**
   ```bash
   # Check container logs
   az containerapp logs show --name ca-<resourceToken> --resource-group rg-<envName> --follow
   ```

3. **Azure DevOps Connection Issues**
   - Verify the organization name in environment variables
   - Check managed identity has access to Azure DevOps
   - Ensure DefaultAzureCredential can authenticate

### Debugging

1. **Local Testing**
   ```bash
   # Test the web server locally
   npm run dev:server
   curl http://localhost:3000/health
   ```

2. **Container Testing**
   ```bash
   # Build and test container locally
   docker build -t azure-devops-mcp .
   docker run -p 3000:3000 --env-file .env azure-devops-mcp
   ```

## Updating the Deployment

```bash
# Update the application
azd deploy

# Or update infrastructure only
azd provision
```

## Cleanup

```bash
# Remove all resources
azd down --purge
```

## Environment Variables Reference

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `AZURE_ORGANIZATION_NAME` | Azure DevOps organization | Yes | - |
| `AZURE_ENV_NAME` | Environment name for resource naming | Yes | - |
| `AZURE_LOCATION` | Azure region | Yes | - |
| `PORT` | Web server port | No | 3000 |
| `NODE_ENV` | Node environment | No | production |

## Advanced Configuration

### Custom Domain

To use a custom domain, update `infra/resources.bicep`:

```bicep
ingress: {
  external: true
  targetPort: 3000
  customDomains: [
    {
      name: 'mcp.yourdomain.com'
      certificateId: 'your-certificate-id'
    }
  ]
}
```

### Multiple Organizations

Deploy separate instances for different Azure DevOps organizations:

```bash
# Deploy for different organizations
azd env set AZURE_ORGANIZATION_NAME contoso
azd env set AZURE_ENV_NAME contoso-mcp
azd up

azd env set AZURE_ORGANIZATION_NAME fabrikam
azd env set AZURE_ENV_NAME fabrikam-mcp
azd up
```

### CI/CD Integration

Create GitHub Actions workflow for automated deployments:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Azure
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: |
          curl -fsSL https://aka.ms/install-azd.sh | bash
          azd deploy --no-prompt
```
