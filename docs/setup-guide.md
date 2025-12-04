# Azure KeyVault Expiration Monitoring Setup Guide

## Prerequisites

### Azure Requirements
- Azure subscription with KeyVault resources
- Service Principal with KeyVault read permissions
- SMTP server access for email notifications

### PowerShell Requirements
- PowerShell 5.1 or later
- Azure PowerShell module (`Az.KeyVault`)

## Step 1: Install Azure PowerShell Module

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force

# Import the KeyVault module
Import-Module Az.KeyVault
```

## Step 2: Create Azure Service Principal

### Using Azure CLI
```bash
# Create service principal
az ad sp create-for-rbac --name "KeyVault-Monitor-SP" --role "Key Vault Reader"

# Note down the output:
# - appId (clientId)
# - password (clientSecret)  
# - tenant (tenantId)
```

### Using Azure Portal
1. Go to Azure Active Directory
2. Select "App registrations"
3. Click "New registration"
4. Name: "KeyVault-Monitor-SP"
5. Create client secret in "Certificates & secrets"
6. Note down Application (client) ID and Directory (tenant) ID

## Step 3: Assign KeyVault Permissions

### For each KeyVault to monitor:

```powershell
# Set KeyVault access policy
Set-AzKeyVaultAccessPolicy `
    -VaultName "your-keyvault-name" `
    -ServicePrincipalName "your-app-id" `
    -PermissionsToKeys get,list `
    -PermissionsToSecrets get,list `
    -PermissionsToCertificates get,list
```

### Or using Azure CLI:
```bash
# Assign permissions
az keyvault set-policy `
    --name "your-keyvault-name" `
    --spn "your-app-id" `
    --key-permissions get list `
    --secret-permissions get list `
    --certificate-permissions get list
```

## Step 4: Configure the Script

### Update Authentication Settings

Edit `scripts/KeyVault-Expiration-Monitor.ps1`:

```powershell
$clientId     = "your-application-id"
$tenantId     = "your-tenant-id"  
$clientSecret = "your-client-secret"
```

### Update Vault Names

Replace the dummy vault names with your actual KeyVaults:

```powershell
$VaultNames = @(
    'your-actual-keyvault-name1',
    'your-actual-keyvault-name2',
    'your-actual-keyvault-name3'
)
```

### Configure Email Settings

```powershell
# Test recipients for initial testing
$TestRecipients = @(
    "your-email@domain.com"
)

# SMTP configuration
$SmtpServer = "your-smtp-server.com"
$FromAddress = "AzureAlerts@your-domain.com"
```

## Step 5: Test the Configuration

### Run in Test Mode

```powershell
# Ensure test mode is enabled
$TEST_MODE = $true

# Run the script
.\scripts\KeyVault-Expiration-Monitor.ps1
```

### Verify Output

Check for:
- Successful Azure authentication
- KeyVault access (no permission errors)
- Email sending (test recipients should receive emails)

## Step 6: Production Deployment

### Option 1: Windows Task Scheduler

1. Create new task in Task Scheduler
2. Set trigger for daily execution
3. Set action to run PowerShell script
4. Configure service account with appropriate permissions

### Option 2: Azure Automation Account

1. Create Azure Automation Account
2. Import Az.KeyVault module
3. Create runbook from script
4. Set up schedule for daily execution
5. Use KeyVault or Variables for credentials

### Option 3: Azure DevOps Pipeline

```yaml
trigger: none

schedules:
- cron: "0 8 * * *"  # Daily at 8 AM
  displayName: Daily KeyVault Monitor
  branches:
    include:
    - main

pool:
  vmImage: 'windows-latest'

steps:
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'your-service-connection'
    ScriptType: 'FilePath'
    ScriptPath: 'scripts/KeyVault-Expiration-Monitor.ps1'
    azurePowerShellVersion: 'LatestVersion'
```

## Step 7: Monitoring and Maintenance

### Log Collection

Add logging to the script:

```powershell
Start-Transcript -Path "C:\Logs\KeyVault-Monitor-$(Get-Date -Format 'yyyy-MM-dd').log"
# ... script content ...
Stop-Transcript
```

### Regular Maintenance

- Review and update vault lists monthly
- Validate Service Principal credentials quarterly
- Test email delivery monthly
- Review owner assignments quarterly

## Security Best Practices

### Credential Management

- Store Service Principal secret securely (Azure KeyVault recommended)
- Rotate client secret regularly
- Use least-privilege permissions
- Enable audit logging

### Network Security

- Restrict SMTP access to authorized servers
- Use TLS for email transmission
- Consider private endpoints for KeyVault access

### Access Control

- Limit script execution to authorized personnel
- Use service accounts for automated execution
- Monitor script execution logs
- Review access permissions regularly

## Troubleshooting

### Common Issues

#### Authentication Errors
```
Error: AADSTS70011: The provided request must include a 'scope' parameter
```
- Update Azure PowerShell module to latest version
- Check Service Principal permissions

#### KeyVault Access Denied
```
Error: Access denied to KeyVault 'vault-name'
```
- Verify access policy is set correctly
- Check Service Principal object ID
- Ensure permissions include get/list for all object types

#### Email Sending Failures
```
Error: Unable to relay message
```
- Verify SMTP server configuration
- Check network connectivity
- Validate sender permissions

### Debug Mode

Enable detailed logging:

```powershell
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
```

## Support and Maintenance

### Updating the Script

1. Test changes in non-production environment
2. Validate with test recipients first
3. Deploy during maintenance windows
4. Monitor execution logs post-deployment

### Performance Optimization

For large numbers of KeyVaults:
- Implement parallel processing
- Add retry logic for transient failures
- Consider batching vault operations
- Monitor script execution time

---

**Setup complete!** Your KeyVault monitoring system should now be operational.