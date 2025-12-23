# Azure KeyVault Automation

A comprehensive Azure KeyVault monitoring and automation toolkit for managing certificate, key, and secret expiration notifications.

##  Features

- **Automated Expiration Monitoring**: Scans multiple KeyVaults for expiring certificates, keys, and secrets
- **Tiered Alert System**: 3-tier escalation (30/15/7 days) with appropriate stakeholder notifications  
- **Owner Assignment**: Intelligent owner resolution based on vault naming conventions
- **HTML Email Reports**: Professional HTML email notifications with detailed tables
- **Test Mode**: Safe testing with dummy recipients before production deployment
- **Read-Only Operations**: No destructive actions - monitoring only
- **Disabled Object Tracking**: Identifies and reports on disabled vault objects

## 📁 Project Structure

```
keyvault-automation/
├── scripts/
│   └── KeyVault-Expiration-Monitor.ps1    # Main monitoring script
├── config/
│   └── monitoring-config.yaml             # Configuration settings
├── docs/
│   └── setup-guide.md                     # Setup instructions
└── README.md                              # This file
```

## ⚙️ Configuration

### Authentication Setup

1. Create an Azure Service Principal with KeyVault read permissions
2. Update the authentication section in the script:

```powershell
$clientId     = "<YOUR-CLIENT-ID>"
$tenantId     = "<YOUR-TENANT-ID>"
$clientSecret = "<YOUR-CLIENT-SECRET>"
```

### Email Configuration

Configure SMTP settings and recipient lists:

```powershell
# Test mode recipients (used during testing)
$TestRecipients = @(
    "admin@example.com",
    "manager@example.com",
    "devops@example.com"
)

# SMTP Configuration
$SmtpServer = "mail.example.com"
$FromAddress = "AzureAlerts@example.com"
```

### KeyVault List

Update the `$VaultNames` array with your actual KeyVault names:

```powershell
$VaultNames = @(
    'your-keyvault-dev01',
    'your-keyvault-prod01',
    # Add your actual vault names
)
```

##  Alert Tiers

- **Tier 1 (30 days)**: Owner notification only
- **Tier 2 (15 days)**: Owner + Management team
- **Tier 3 (7 days)**: Owner + Management + DevOps team

##  Usage

### Test Mode (Recommended First)

```powershell
# Ensure TEST_MODE is enabled
$TEST_MODE = $true

# Run the script
.\KeyVault-Expiration-Monitor.ps1
```

### Production Mode

```powershell
# Disable test mode
$TEST_MODE = $false

# Run the script (typically scheduled)
.\KeyVault-Expiration-Monitor.ps1
```

### Scheduled Execution

Set up as a scheduled task or Azure Automation Runbook:

- **Frequency**: Daily (recommended)
- **Time**: Early morning hours
- **Service Account**: With appropriate KeyVault permissions

##  Reports Generated

### Internal Summary Report
- Expiring items across all vaults
- Already expired items
- Disabled vault objects
- Sent to administrators and security team

### Owner-Specific Alerts
- Individual notifications per expiring item
- Escalated based on days remaining
- HTML formatted with vault details

##  Security Considerations

- **Read-Only**: Script performs no destructive operations
- **Credential Management**: Use secure credential storage
- **Test Mode**: Always test with dummy recipients first
- **Audit Logging**: PowerShell transcript logging recommended

## 🔄 Automation Options

### Azure Automation Account
```powershell
# Upload as a runbook
# Schedule daily execution
# Use Azure Key Vault for credentials
```

### Windows Task Scheduler
```powershell
# Create scheduled task
# Run under service account
# Configure for daily execution
```

### Azure DevOps Pipeline
```yaml
# Create pipeline with scheduled trigger
# Use secure variables for credentials
# Email results via pipeline notifications
```

##  Customization

### Owner Assignment Rules

Modify the `Get-ResolvedOwner` function to match your naming conventions:

```powershell
function Get-ResolvedOwner {
    param([string]$VaultName, [string]$ObjectName)
    
    # Add your custom logic here
    # Based on vault prefixes, naming patterns, etc.
    
    return $DefaultOwner
}
```

### Email Templates

Customize the HTML email format in the `New-Table` function:

```powershell
function New-Table {
    # Modify HTML structure and styling
    # Add company branding
    # Include additional metadata
}
```

##  Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify Service Principal permissions
   - Check tenant and client IDs
   - Validate secret hasn't expired

2. **SMTP Errors**
   - Confirm SMTP server settings
   - Check network connectivity
   - Verify sender permissions

3. **KeyVault Access Issues**
   - Ensure Service Principal has "Get" and "List" permissions
   - Check vault access policies
   - Verify vault names are correct

### Debugging

Enable verbose logging:
```powershell
# Add at the beginning of script
$VerbosePreference = "Continue"
Start-Transcript -Path "C:\Logs\KeyVault-Monitor.log"
```

## 📄 License

MIT License - see LICENSE file for details.

##  Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

##  Support

For issues and questions:
- Create an issue in this repository
- Include relevant logs and error messages
- Specify your environment details

---

**Azure KeyVault Automation** - Proactive certificate and secret management! 
