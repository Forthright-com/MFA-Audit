# Multi-Customer MFA Audit Script
# Purpose: Batch audit MFA adoption across multiple customer tenants

param(
    [Parameter(Mandatory=$true, HelpMessage="Your app registration ID")]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true, HelpMessage="Your app secret")]
    [string]$ClientSecret
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
        $result = & "$PSScriptRoot\MFA-Audit.ps1" -TenantId $Customer.TenantId -ClientId $ClientId -ClientSecret $ClientSecret -CustomerName $Customer.Name
        
        if ($result) {
            $Results += $result
            
            # Quick status for each customer
            $riskColor = switch ($result.HighRiskPercentage) {
                { $_ -le 5 } { "Green" }
                { $_ -le 15 } { "Yellow" }
                default { "Red" }
            }
            
            Write-Host "✅ $($Customer.Name): $($result.HighRiskUsers) high-risk users ($($result.HighRiskPercentage)%)" -ForegroundColor $riskColor
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
    $TotalHighRisk = ($Results | Measure-Object HighRiskUsers -Sum).Sum
    $OverallPercentage = if ($TotalUsers -gt 0) { [math]::Round(($TotalHighRisk/$TotalUsers)*100,1) } else { 0 }
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "              📊 OVERALL SUMMARY" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host "Customers Successfully Audited: $($Results.Count)" -ForegroundColor White
    Write-Host "Total Users Across All Customers: $TotalUsers" -ForegroundColor White
    Write-Host "Total High-Risk Users: $TotalHighRisk ($OverallPercentage%)" -ForegroundColor White
    
    # Show customers needing immediate attention
    $CustomersNeedingAttention = $Results | Where-Object { $_.HighRiskPercentage -gt 10 } | Sort-Object HighRiskPercentage -Descending
    if ($CustomersNeedingAttention.Count -gt 0) {
        Write-Host "`n🚨 CUSTOMERS NEEDING IMMEDIATE ATTENTION:" -ForegroundColor Red
        $CustomersNeedingAttention | ForEach-Object {
            Write-Host "   • $($_.CustomerName): $($_.HighRiskUsers) high-risk users ($($_.HighRiskPercentage)%)" -ForegroundColor Red
        }
        
        Write-Host "`n📧 Consider sending MFA security alerts to these customers immediately." -ForegroundColor Yellow
    }
    
    # Show customers with good MFA coverage
    $GoodCoverage = $Results | Where-Object { $_.HighRiskPercentage -le 5 }
    if ($GoodCoverage.Count -gt 0) {
        Write-Host "`n✅ CUSTOMERS WITH GOOD MFA COVERAGE:" -ForegroundColor Green
        $GoodCoverage | ForEach-Object {
            Write-Host "   • $($_.CustomerName): $($_.HighRiskUsers) high-risk users ($($_.HighRiskPercentage)%)" -ForegroundColor Green
        }
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
