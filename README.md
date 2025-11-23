# Azure Infrastructure Deployment with Terraform

This directory contains Terraform configurations for deploying the complete Azure infrastructure for the AKS Advanced Container Networking Services (ACNS) workshop.

## Prerequisites

### Required Tools

1. **Terraform** (>= 1.5)
   - [Download and install Terraform](https://www.terraform.io/downloads)
   - Verify installation: `terraform version`

2. **Azure CLI**
   - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   - Verify installation: `az --version`

3. **kubectl**
   - [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
   - Verify installation: `kubectl version --client`

### Azure Requirements

- **Active Azure Subscription**
- **Sufficient Azure permissions** to create:
  - Resource Groups
  - Azure Kubernetes Service (AKS) clusters
  - Azure Container Registry (ACR)
  - Virtual Networks and Subnets
  - Log Analytics Workspaces
  - Azure Monitor resources
  - Azure Managed Grafana instances

### Authentication

Before deploying, authenticate with Azure:

```bash
az login
```

To verify you're using the correct subscription:

```bash
az account show
az account list --output table
```

To set a specific subscription:

```bash
az account set --subscription "<subscription-id>"
```

## Configuration

### Install AZ Preview extensions

```bash
az extension add --name aks-preview
az extension update --name aks-preview
```


### Enable Azure Account Preview Features

This deployment requires registering Azure preview features. **Important:** Feature registration can take 10-15 minutes to complete.

#### Register Advanced Networking Flow Logs Preview

[AdvancedNetworkingFlowLogsPreview feature](https://learn.microsoft.com/en-us/azure/aks/advanced-container-networking-services-overview?tabs=cilium#register-the-advancednetworkingflowlogspreview-feature-flag)

```bash
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingFlowLogsPreview"
```

Check the registration status (wait until the state shows "Registered"):

```bash
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingFlowLogsPreview"
```

#### Register Advanced Networking L7 Policy Preview

Enabling [AdvancedNetworkingL7PolicyPreview feature](https://learn.microsoft.com/en-us/azure/aks/advanced-container-networking-services-overview?tabs=cilium#register-the-advancednetworkingl7policypreview-feature-flag)

```bash
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
```

Check the registration status (wait until the state shows "Registered"):

```bash
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
```

#### Refresh the Resource Provider

After both features are registered, refresh the Microsoft.ContainerService provider:

```bash
az provider register --namespace Microsoft.ContainerService
```

### Required Variables

Create a `terraform.tfvars` file in this directory with the following required variables:

```hcl
subscription_id = "your-subscription-id"
base_name       = "your-unique-prefix"  # Used as prefix for all resources
```

### Optional Variables

You can override these optional variables (defaults shown):

```hcl
region                           = "swedencentral"
virtual_network_address_prefix   = "10.0.0.0/16"
aks_subnet_address_prefix        = "10.0.0.0/18"
aks_service_cidr                 = "192.168.0.0/20"
aks_dns_service_ip               = "192.168.0.10"
pod_cidr                         = "10.244.0.0/16"
grafana_major_version            = "11"
```

### Example terraform.tfvars

```hcl
subscription_id = "12345678-1234-1234-1234-123456789abc"
base_name       = "acnsworkshop"
region          = "swedencentral"
```

## Deployment Steps

1. **Navigate to the infrastructure directory:**
   ```bash
   cd IaC/infra
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the deployment plan:**
   ```bash
   terraform plan
   ```

4. **Apply the configuration:**
   ```bash
   terraform apply
   ```
   
   Review the proposed changes and type `yes` to confirm.

5. **Configure kubectl access to the AKS cluster:**
   ```bash
   az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
   ```
   
   The resource group and cluster names will be output after the apply completes.

## What Gets Deployed

This Terraform configuration creates:

- **Azure Container Registry (ACR)** - For storing container images
- **Azure Kubernetes Service (AKS)** - Managed Kubernetes cluster
- **Virtual Network** - Network infrastructure with dedicated subnets
- **Log Analytics Workspace** - For centralized logging
- **Azure Monitor** - Monitoring and diagnostics
- **Azure Managed Grafana** - Visualization and dashboards

## Outputs

After successful deployment, Terraform will display important information including:

- Resource Group name
- AKS cluster name
- ACR login server
- Grafana endpoint
- Log Analytics Workspace ID

## Clean Up

To destroy all created resources:

```bash
terraform destroy
```

⚠️ **Warning:** This will permanently delete all resources created by this configuration.

## Troubleshooting

### Common Issues

1. **Authentication errors:**
   - Ensure you're logged in: `az login`
   - Verify correct subscription: `az account show`

2. **Insufficient permissions:**
   - Verify you have Contributor or Owner role on the subscription

3. **Resource name conflicts:**
   - Use a unique `base_name` to avoid naming conflicts

4. **Quota limits:**
   - Check your subscription has sufficient quota for VM cores and other resources

## Terraform Providers

This configuration uses:
- `azurerm` provider (v4.53.0) - Azure Resource Manager
- `azapi` provider (v2.7.0) - Azure API provider
- `null` provider (v3.2.4) - Utility provider

## Next Steps

After infrastructure deployment:

1. Deploy the application by navigating to `IaC/app/`
2. Follow the workshop instructions for Advanced Container Networking Services configuration
3. Explore the monitoring dashboards in Grafana
