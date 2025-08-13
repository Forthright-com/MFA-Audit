# Multi-Customer MFA Audit Script
# Purpose: Batch audit MFA adoption across multiple customer tenants

param(
    [Parameter(Mandatory=$true, HelpMessage="Your app registration ID")]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true, HelpMessage="Your app secret")]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$false, HelpMessage="Name of group containing MFA-exempt users")]
    [string]$MfaBypassGroupName = "MFA-Bypass-ServiceAccounts"
)

Write-Host "🚀 Starting Multi-Customer MFA Audit..." -ForegroundColor Cyan

# Define your customer list here
$Customers = @(
    @{Name="Contoso Ltd"; TenantId="contoso.com"},
    @{Name="Fabrikam Inc"; TenantId="fabrikam.com"},
    @{Name="Northwind Traders"; TenantId="northwind.com"}
    # Add more customers as needed
)

Write-Host "📋 Customers to audit: $($Customers.Count)" -ForegroundColor Yellow

$Results = @()
$FailedAudits = @()

foreach ($Customer in $Customers) {
    Write-Host "`n🔄 Processing $($Customer.Name)..." -ForegroundColor Cyan
    
    try {
        # Call the main audit script
        $result = & "$PSScriptRoot\MFA-Audit.ps1" -TenantId $Customer.TenantId -ClientId $ClientId -ClientSecret $ClientSecret -CustomerName $Customer.Name -MfaBypassGroupName $MfaBypassGroupName
        
        if ($result) {
            $Results += $result
            
            # Quick status for each customer
            $statusColor = switch ($result.MfaRequiredPercentage) {
                { $_ -le 5 } { "Green" }
                { $_ -le 15 } { "Yellow" }
                default { "Red" }
            }
            
            Write-Host "✅ $($Customer.Name): $($result.MfaRequiredCount) users requiring MFA ($($result.MfaRequiredPercentage)%)" -ForegroundColor $statusColor
        } else {
            throw "Audit returned null result"
        }
        
    } catch {
        Write-Host "❌ $($Customer.Name): Failed - $($_.Exception.Message)" -ForegroundColor Red
        $FailedAudits += @{
            CustomerName = $Customer.Name
            TenantId = $Customer.TenantId
            Error = $_.Exception.Message
        }
    }
    
    # Brief pause between customers to avoid throttling
    Start-Sleep -Seconds 3
}

# Generate overall summary
if ($Results.Count -gt 0) {
    $TotalUsers = ($Results | Measure-Object TotalUsers -Sum).Sum
    $TotalMfaRequired = ($Results | Measure-Object MfaRequiredCount -Sum).Sum
    $TotalMfaActive = ($Results | Measure-Object MfaActiveCount -Sum).Sum
    $TotalMfaInactive = ($Results | Measure-Object MfaInactiveCount -Sum).Sum
    $TotalMfaExempted = ($Results | Measure-Object MfaExemptedCount -Sum).Sum
    $TotalMfaUnknown = ($Results | Measure-Object MfaUnknownCount -Sum).Sum
    $OverallRequiredPercentage = if ($TotalUsers -gt 0) { [math]::Round(($TotalMfaRequired/$TotalUsers)*100,1) } else { 0 }
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "              📊 OVERALL SUMMARY" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host "Customers Successfully Audited: $($Results.Count)" -ForegroundColor White
    Write-Host "Total Users Across All Customers: $TotalUsers" -ForegroundColor White
    Write-Host ""
    Write-Host "OVERALL MFA STATUS:" -ForegroundColor White
    Write-Host "   ✅ MFA Active: $TotalMfaActive ($([math]::Round(($TotalMfaActive/$TotalUsers)*100,1))%)" -ForegroundColor Green
    Write-Host "   ⚠️ MFA Required: $TotalMfaRequired ($OverallRequiredPercentage%)" -ForegroundColor Red
    Write-Host "   🟡 MFA Inactive: $TotalMfaInactive ($([math]::Round(($TotalMfaInactive/$TotalUsers)*100,1))%)" -ForegroundColor Yellow
    Write-Host "   🔒 MFA Exempted: $TotalMfaExempted ($([math]::Round(($TotalMfaExempted/$TotalUsers)*100,1))%)" -ForegroundColor Blue
    Write-Host "   ❓ MFA Unknown: $TotalMfaUnknown ($([math]::Round(($TotalMfaUnknown/$TotalUsers)*100,1))%)" -ForegroundColor Magenta
    
    # Show customers needing immediate attention
    $CustomersNeedingAttention = $Results | Where-Object { $_.MfaRequiredPercentage -gt 10 } | Sort-Object MfaRequiredPercentage -Descending
    if ($CustomersNeedingAttention.Count -gt 0) {
        Write-Host "`n⚠️ CUSTOMERS NEEDING IMMEDIATE ATTENTION:" -ForegroundColor Red
        $CustomersNeedingAttention | ForEach-Object {
            Write-Host "   • $($_.CustomerName): $($_.MfaRequiredCount) users requiring MFA ($($_.MfaRequiredPercentage)%)" -ForegroundColor Red
        }
        
        Write-Host "`n🔧 Consider prioritizing MFA enrollment campaigns for these customers." -ForegroundColor Yellow
    }
    
    # Show customers with good MFA coverage
    $GoodCoverage = $Results | Where-Object { $_.MfaRequiredPercentage -le 5 }
    if ($GoodCoverage.Count -gt 0) {
        Write-Host "`n✅ CUSTOMERS WITH GOOD MFA COVERAGE:" -ForegroundColor Green
        $GoodCoverage | ForEach-Object {
            Write-Host "   • $($_.CustomerName): $($_.MfaRequiredCount) users requiring MFA ($($_.MfaRequiredPercentage)%)" -ForegroundColor Green
        }
    }
    
    # Show customers with inactive MFA users
    $InactiveUsers = $Results | Where-Object { $_.MfaInactiveCount -gt 0 } | Sort-Object MfaInactiveCount -Descending
    if ($InactiveUsers.Count -gt 0) {
        Write-Host "`n🟡 CUSTOMERS WITH INACTIVE MFA USERS:" -ForegroundColor Yellow
        $InactiveUsers | Select-Object -First 5 | ForEach-Object {
            Write-Host "   • $($_.CustomerName): $($_.MfaInactiveCount) inactive MFA users" -ForegroundColor Yellow
        }
        if ($InactiveUsers.Count -gt 5) {
            Write-Host "   ... and $($InactiveUsers.Count - 5) more customers with inactive users" -ForegroundColor Yellow
        }
        Write-Host "   Consider reviewing conditional access policies for these customers" -ForegroundColor Gray
    }
    
    Write-Host "="*60 -ForegroundColor Cyan
}

# Report any failures
if ($FailedAudits.Count -gt 0) {
    Write-Host "`n❌ FAILED AUDITS:" -ForegroundColor Red
    $FailedAudits | ForEach-Object {
        Write-Host "   • $($_.CustomerName) ($($_.TenantId)): $($_.Error)" -ForegroundColor Red
    }
    Write-Host "`nCheck permissions and tenant IDs for failed audits." -ForegroundColor Yellow
}

# Export summary to CSV
$timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$summaryPath = ".\Multi_Customer_MFA_Summary_$timestamp.csv"
$Results | Export-Csv -Path $summaryPath -NoTypeInformation

Write-Host "`n📄 Summary exported to: $summaryPath" -ForegroundColor Green
Write-Host "🎯 Multi-customer audit complete!" -ForegroundColor Cyan
