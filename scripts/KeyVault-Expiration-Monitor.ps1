#############################################################################################
# Key Vault Expiration Monitoring Script
# Fully merged version with:
# - Owner overrides
# - Test Mode
# - 30 / 15 / 7-day escalation windows
# - HTML reporting
# - Internal + owner notifications
# - Read-only Azure calls (NO destructive actions)
#############################################################################################

#############################################
# AUTHENTICATION (Insert real credentials)
#############################################

$clientId     = "<CLIENT-ID>"
$tenantId     = "<TENANT-ID>"
$clientSecret = "<CLIENT-SECRET>"

Connect-AzAccount -ServicePrincipal `
    -TenantId $tenantId `
    -ApplicationId $clientId `
    -Credential (ConvertTo-SecureString $clientSecret -AsPlainText -Force)

Write-Output "Authenticated with Service Principal."


#############################################
# GLOBAL TEST MODE CONFIGURATION
#############################################

$TEST_MODE = $true     # <---- Only test recipients get emails

$TestRecipients = @(
    "admin@example.com",
    "manager@example.com",
    "devops@example.com"
)


#############################################
# OWNER OVERRIDES (Vault Prefix or Name-based)
#############################################

$OwnerOverrides = @{
    "CHP"   = "swati@example.com"      # placeholder
    "Sales" = "mor@example.com"        # placeholder
    "RSFH"  = "josh@example.com"       # placeholder
}

$DefaultOwner = "default-owner@example.com"


function Get-ResolvedOwner {
    param(
        [string]$VaultName,
        [string]$ObjectName
    )

    $prefix = $VaultName.Split("-")[1]

    if ($prefix -eq "chp")      { return $OwnerOverrides["CHP"] }
    if ($prefix -eq "rsfh")     { return $OwnerOverrides["RSFH"] }

    if ($ObjectName.ToLower().Contains("salesforce")) {
        return $OwnerOverrides["Sales"]
    }

    return $DefaultOwner
}


#############################################
# OBJECT CONSTRUCTOR
#############################################

function New-KeyVaultObject {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Version,
        [string]$Type,
        [System.Nullable[datetime]]$Expires,
        [string]$KVName,
        [string]$OlderVersion,
        [string]$OldExpirey
    )

    $o = New-Object PSObject
    $o | Add-Member Name         -Value $Name
    $o | Add-Member Id           -Value $Id
    $o | Add-Member Version      -Value $Version
    $o | Add-Member Type         -Value $Type
    $o | Add-Member KVName       -Value $KVName
    $o | Add-Member Expires      -Value $Expires
    $o | Add-Member OlderVersion -Value $OlderVersion
    $o | Add-Member OldExpirey   -Value $OldExpirey
    $o | Add-Member DaysLeft     -Value 0
    $o | Add-Member Owner        -Value ""
    $o | Add-Member EscalationTier -Value "None"
    return $o
}


#############################################
# RETRIEVAL FUNCTIONS (Keys, Secrets, Certs)
#############################################

function Get-AzureKeyVaultObjectKeys {
    param([string]$VaultName)

    $objs = [System.Collections.ArrayList]@()
    $all = Get-AzKeyVaultKey -VaultName $VaultName

    foreach ($it in $all) {
        $versions = Get-AzKeyVaultKey -VaultName $VaultName -IncludeVersions -Name $it.Name |
                    Where-Object { $_.Enabled -eq $true } |
                    Sort-Object Expires -Descending

        if ($versions.Count -gt 0) {
            $latest = $versions[0]
            $older  = if ($versions.Count -gt 1) { $versions[1].Version } else { "NA" }
            $olderExp = if ($versions.Count -gt 1) { $versions[1].Expires } else { "NA" }

            $objs.Add(
                New-KeyVaultObject `
                    -Id $latest.Id `
                    -Name $latest.Name `
                    -Version $latest.Version `
                    -Type "Key" `
                    -Expires $latest.Expires `
                    -KVName $VaultName `
                    -OlderVersion $older `
                    -OldExpirey $olderExp
            ) | Out-Null
        }
    }

    return $objs
}


function Get-AzureKeyVaultObjectSecrets {
    param([string]$VaultName)

    $objs = [System.Collections.ArrayList]@()
    $all = Get-AzKeyVaultSecret -VaultName $VaultName

    foreach ($it in $all) {
        $versions = Get-AzKeyVaultSecret -VaultName $VaultName -IncludeVersions -Name $it.Name |
                    Where-Object { $_.Enabled -eq $true } |
                    Sort-Object Expires -Descending

        if ($versions.Count -gt 0) {
            $latest = $versions[0]
            $older  = if ($versions.Count -gt 1) { $versions[1].Version } else { "NA" }
            $olderExp = if ($versions.Count -gt 1) { $versions[1].Expires } else { "NA" }

            $objs.Add(
                New-KeyVaultObject `
                    -Id $latest.Id `
                    -Name $latest.Name `
                    -Version $latest.Version `
                    -Type "Secret" `
                    -Expires $latest.Expires `
                    -KVName $VaultName `
                    -OlderVersion $older `
                    -OldExpirey $olderExp
            ) | Out-Null
        }
    }

    return $objs
}


function Get-AzureKeyVaultObjectCerts {
    param([string]$VaultName)

    $objs = [System.Collections.ArrayList]@()
    $all = Get-AzKeyVaultCertificate -VaultName $VaultName

    foreach ($it in $all) {
        $versions = Get-AzKeyVaultCertificate -VaultName $VaultName -IncludeVersions -Name $it.Name |
                    Where-Object { $_.Enabled -eq $true } |
                    Sort-Object Expires -Descending

        if ($versions.Count -gt 0) {
            $latest = $versions[0]
            $older  = if ($versions.Count -gt 1) { $versions[1].Version } else { "NA" }
            $olderExp = if ($versions.Count -gt 1) { $versions[1].Expires } else { "NA" }

            $objs.Add(
                New-KeyVaultObject `
                    -Id $latest.Id `
                    -Name $latest.Name `
                    -Version $latest.Version `
                    -Type "Cert" `
                    -Expires $latest.Expires `
                    -KVName $VaultName `
                    -OlderVersion $older `
                    -OldExpirey $olderExp
            ) | Out-Null
        }
    }

    return $objs
}


#############################################
# DISABLED OBJECTS RETRIEVAL
#############################################

function Get-AzureKeyVaultdisabledObjectKeys {
    param([string]$VaultName)

    $objs = [System.Collections.ArrayList]@()

    # Disabled keys
    $keys = Get-AzKeyVaultKey -VaultName $VaultName
    foreach ($it in $keys) {
        $versions = Get-AzKeyVaultKey -VaultName $VaultName -IncludeVersions -Name $it.Name |
                    Where-Object { $_.Enabled -eq $false }

        foreach ($v in $versions) {
            $objs.Add(
                New-KeyVaultObject `
                    -Id $v.Id `
                    -Name $v.Name `
                    -Version $v.Version `
                    -Type "Key" `
                    -Expires $v.Expires `
                    -KVName $VaultName `
                    -OlderVersion "NA" `
                    -OldExpirey "NA"
            ) | Out-Null
        }
    }

    # Disabled certs
    $certs = Get-AzKeyVaultCertificate -VaultName $VaultName
    foreach ($it in $certs) {
        $versions = Get-AzKeyVaultCertificate -VaultName $VaultName -IncludeVersions -Name $it.Name |
                    Where-Object { $_.Enabled -eq $false }

        foreach ($v in $versions) {
            $objs.Add(
                New-KeyVaultObject `
                    -Id $v.Id `
                    -Name $v.Name `
                    -Version $v.Version `
                    -Type "Cert" `
                    -Expires $v.Expires `
                    -KVName $VaultName `
                    -OlderVersion "NA" `
                    -OldExpirey "NA"
            ) | Out-Null
        }
    }

    # Disabled secrets
    $secrets = Get-AzKeyVaultSecret -VaultName $VaultName
    foreach ($it in $secrets) {
        $versions = Get-AzKeyVaultSecret -VaultName $VaultName -IncludeVersions -Name $it.Name |
                    Where-Object { $_.Enabled -eq $false }

        foreach ($v in $versions) {
            $objs.Add(
                New-KeyVaultObject `
                    -Id $v.Id `
                    -Name $v.Name `
                    -Version $v.Version `
                    -Type "Secret" `
                    -Expires $v.Expires `
                    -KVName $VaultName `
                    -OlderVersion "NA" `
                    -OldExpirey "NA"
            ) | Out-Null
        }
    }

    return $objs
}


#############################################
# VAULT LIST (Example vaults - replace with your actual vault names)
#############################################

$VaultNames = @(
    'kv-webapp-dev01','kv-webapp-staging01','kv-webapp-prod01',
    'kv-api-dev01','kv-api-staging01','kv-api-prod01',
    'kv-database-dev01','kv-database-prod01','kv-shared-services01',
    'kv-microservice-a-dev','kv-microservice-a-prod','kv-microservice-b-dev',
    'kv-microservice-b-prod','kv-frontend-dev01','kv-frontend-prod01',
    'kv-integration-dev01','kv-integration-prod01','kv-monitoring-shared',
    'kv-security-dev01','kv-security-prod01','kv-backup-services01'
)


#############################################
# COLLECTION ARRAYS
#############################################

$allKeyVaultObjects            = [System.Collections.ArrayList]@()
$alreadyExpiredKeyVaultObjects = [System.Collections.ArrayList]@()
$nearExpiryKeyVaultObjects     = [System.Collections.ArrayList]@()
$disabledlist                  = [System.Collections.ArrayList]@()

$today = (Get-Date).Date
$AlertBeforeDays = 60


#############################################
# SCAN EACH VAULT (READ-ONLY)
#############################################

foreach ($VaultName in $VaultNames) {

    Write-Output "Scanning $VaultName ..."

    try {
        $allKeyVaultObjects.AddRange(
            Get-AzureKeyVaultObjectKeys -VaultName $VaultName
        )
        $allKeyVaultObjects.AddRange(
            Get-AzureKeyVaultObjectSecrets -VaultName $VaultName
        )
        $allKeyVaultObjects.AddRange(
            Get-AzureKeyVaultObjectCerts -VaultName $VaultName
        )
    }
    catch {
        Write-Output "Error retrieving enabled items for $VaultName"
    }

    try {
        $disabledlist.AddRange(
            Get-AzureKeyVaultdisabledObjectKeys -VaultName $VaultName
        )
    }
    catch {
        Write-Output "Error retrieving disabled items for $VaultName"
    }
}


#############################################
# ASSIGN OWNER AND DAYS LEFT
#############################################

foreach ($obj in $allKeyVaultObjects) {

    $obj.Owner = Get-ResolvedOwner -VaultName $obj.KVName -ObjectName $obj.Name

    if ($obj.Expires -eq $null) { continue }

    $ts = New-TimeSpan -Start $today -End $obj.Expires
    $obj.DaysLeft = $ts.Days

    #############################################
    # ESCALATION WINDOWS (Tier1 / Tier2 / Tier3)
    #############################################

    if ($obj.DaysLeft -le 7 -and $obj.DaysLeft -ge 0) {
        $obj.EscalationTier = "Tier3"     # Owner + Managers + DevOps Team
    }
    elseif ($obj.DaysLeft -le 15 -and $obj.DaysLeft -gt 7) {
        $obj.EscalationTier = "Tier2"     # Owner + Managers
    }
    elseif ($obj.DaysLeft -le 30 -and $obj.DaysLeft -gt 15) {
        $obj.EscalationTier = "Tier1"     # Owner only
    }
    else {
        $obj.EscalationTier = "None"
    }

    #############################################
    # CLASSIFY
    #############################################

    if ($obj.Expires -le $today) {
        $alreadyExpiredKeyVaultObjects.Add($obj) | Out-Null
    }
    elseif ($obj.Expires.AddDays(-$AlertBeforeDays) -le $today) {
        $nearExpiryKeyVaultObjects.Add($obj) | Out-Null
    }
}


#############################################
# HTML TABLE GENERATOR
#############################################

function New-Table {
    param($objects, [string]$heading)

    $html = "<p><b>$heading</b></p>"
    $html += '<table border="1">
        <tr>
            <th>Name</th>
            <th>Expires</th>
            <th>Type</th>
            <th>Vault</th>
            <th>Days Left</th>
            <th>Owner</th>
            <th>Escalation Tier</th>
            <th>Older Version</th>
            <th>Old Expiry</th>
        </tr>'

    foreach ($o in $objects) {
        $html += "<tr>
            <td>$($o.Name)</td>
            <td>$($o.Expires)</td>
            <td>$($o.Type)</td>
            <td>$($o.KVName)</td>
            <td>$($o.DaysLeft)</td>
            <td>$($o.Owner)</td>
            <td>$($o.EscalationTier)</td>
            <td>$($o.OlderVersion)</td>
            <td>$($o.OldExpirey)</td>
        </tr>"
    }

    $html += '</table><br>'
    return $html
}


#############################################
# INTERNAL SUMMARY BODY
#############################################

$internalBody =
    New-Table $nearExpiryKeyVaultObjects     "Expiring Soon" +
    New-Table $alreadyExpiredKeyVaultObjects "Expired Items" +
    New-Table $disabledlist                  "Disabled Items"


#############################################
# OWNER BODY BUILDER
#############################################

function Build-OwnerBody {
    param([string]$OwnerEmail)

    $objs = $allKeyVaultObjects | Where-Object { $_.Owner -eq $OwnerEmail }

    if ($objs.Count -eq 0) {
        return "<p>No items assigned to you.</p>"
    }

    return New-Table $objs "Items Assigned to You"
}


#############################################
# ESCALATION ROUTING
#############################################

$ManagerEmails = @(
    "manager1@example.com",
    "manager2@example.com",
    "teamlead@example.com"
)

$DevOpsTeam = @(
    "devops-team@example.com",
    "infrastructure@example.com",
    "security@example.com"
)


function Resolve-Recipients {
    param(
        [string]$Owner,
        [string]$EscalationTier
    )

    # TEST MODE overrides everything
    if ($TEST_MODE -eq $true) {
        return $TestRecipients
    }

    switch ($EscalationTier) {

        "Tier1" { return @($Owner) }

        "Tier2" { return @($Owner) + $ManagerEmails }

        "Tier3" { return @($Owner) + $ManagerEmails + $DevOpsTeam }

        default { return @($Owner) }
    }
}


#############################################
# SEND INTERNAL SUMMARY EMAIL
#############################################

$internalRecipientsProd = @(
    "admin@example.com",
    "security-team@example.com",
    "operations@example.com"
)

$internalRecipients = if ($TEST_MODE) { $TestRecipients } else { $internalRecipientsProd }

Send-MailMessage `
    -To $internalRecipients `
    -From "AzureAlerts@example.com" `
    -Subject "Azure Key Vault Expiration Summary" `
    -Body $internalBody `
    -SmtpServer "mail.example.com" `
    -BodyAsHtml

Write-Output "Internal summary sent."


#############################################
# OWNER TIERED NOTIFICATIONS
#############################################

$uniqueOwners = $allKeyVaultObjects.Owner | Sort-Object -Unique

foreach ($owner in $uniqueOwners) {

    if ([string]::IsNullOrWhiteSpace($owner)) { continue }

    $objsForOwner = $allKeyVaultObjects | Where-Object { $_.Owner -eq $owner }

    foreach ($obj in $objsForOwner) {

        $tier = $obj.EscalationTier
        $body = New-Table @($obj) "Key Vault Alert ($tier)"

        $recipients = Resolve-Recipients -Owner $owner -EscalationTier $tier

        Send-MailMessage `
            -To $recipients `
            -From "AzureAlerts@example.com" `
            -Subject "Key Vault Expiration ($tier): $($obj.Name)" `
            -Body $body `
            -SmtpServer "mail.example.com" `
            -BodyAsHtml

        Write-Output "Sent $tier alert for $($obj.Name) → $($recipients -join ', ')"
    }
}


#############################################
# COMPLETE
#############################################

Write-Output "Script completed successfully."