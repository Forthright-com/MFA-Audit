# MFA Audit Script 
# Purpose: Quickly identify high-risk users lacking MFA protection

param(
    [Parameter(Mandatory=$true, HelpMessage="Customer tenant domain (e.g., customer.com)")]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true, HelpMessage="Your app registration ID")]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true, HelpMessage="Your app secret")]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$false, HelpMessage="Customer name for the report")]
    [string]$CustomerName = "Customer",
    
    [Parameter(Mandatory=$false, HelpMessage="Days to look back for MFA usage")]
    [int]$DaysBack = 30
)

Write-Host "🔍 Starting MFA audit for $CustomerName ($TenantId)..." -ForegroundColor Cyan

try {
    # Connect to customer tenant
    $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
    Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $Credential -NoWelcome
    
    Write-Host "✅ Connected successfully" -ForegroundColor Green
    
    # Get active users only
    Write-Host "📋 Getting active users..." -ForegroundColor Yellow
    $Users = Get-MgUser -All -Filter "accountEnabled eq true and userType eq 'Member'" -Select "UserPrincipalName,DisplayName,JobTitle,SignInActivity,Id" | 
        Where-Object { $_.UserPrincipalName -notlike "*#EXT#*" }
    
    Write-Host "   Found $($Users.Count) active users" -ForegroundColor Gray
    
    # Get MFA sign-ins from last X days
    Write-Host "📊 Getting MFA usage data..." -ForegroundColor Yellow
    $CutoffDate = (Get-Date).AddDays(-$DaysBack)
    
    try {
        # Get all MFA sign-ins (workaround for API limitation)
        $AllMfaSignIns = @()
        $mfaUri = "https://graph.microsoft.com/beta/auditLogs/signIns?`$filter=authenticationRequirement eq 'multiFactorAuthentication'&`$top=1000"
        
        do {
            $response = Invoke-MgGraphRequest -Method GET -Uri $mfaUri
            $AllMfaSignIns += $response.value
            $mfaUri = $response.'@odata.nextLink'
        } while ($mfaUri -and $AllMfaSignIns.Count -lt 5000)
        
        # Filter by date
        $RecentMfaSignIns = $AllMfaSignIns | Where-Object { 
            [DateTime]::Parse($_.createdDateTime) -ge $CutoffDate 
        }
        
        Write-Host "   Found $($RecentMfaSignIns.Count) MFA sign-ins in last $DaysBack days" -ForegroundColor Gray
    } catch {
        Write-Host "   ⚠️  Could not get MFA sign-in data: $($_.Exception.Message)" -ForegroundColor Yellow
        $RecentMfaSignIns = @()
    }
    
    # Analyze each user
    Write-Host "🔍 Analyzing users for MFA enrollment and usage..." -ForegroundColor Yellow
    $Results = @()
    $HighRiskUsers = @()
    $EnrollmentCheckSuccessful = 0
    $EnrollmentCheckFailed = 0
    
    foreach ($User in $Users) {
        # Check MFA enrollment using UserAuthenticationMethod.Read.All permission
        $HasMfaEnrolled = "Unknown"
        
        try {
            # Get user's authentication methods
            $AuthMethods = Get-MgUserAuthenticationMethod -UserId $User.Id -ErrorAction Stop
            
            # Filter out password methods to get only MFA methods
            $MfaMethods = $AuthMethods | Where-Object { 
                $_.AdditionalProperties.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' 
            }
            
            if ($MfaMethods.Count -gt 0) {
                $HasMfaEnrolled = "Yes"
                $EnrollmentCheckSuccessful++
            } else {
                $HasMfaEnrolled = "No"
                $EnrollmentCheckSuccessful++
            }
            
        } catch {
            # If we can't read auth methods, try to infer from sign-in history
            $HasMfaEnrolled = "Cannot Verify"
            $EnrollmentCheckFailed++
        }
        
        # Check recent MFA usage
        $UserMfaSignIns = $RecentMfaSignIns | Where-Object { $_.userPrincipalName -eq $User.UserPrincipalName }
        $HasRecentMfaUsage = $UserMfaSignIns.Count -gt 0
        
        # Determine risk level with comprehensive logic
        $IsHighRisk = $false
        $RiskLevel = "Low"
        
        # High Risk: Confirmed no MFA enrollment OR (can't verify enrollment AND no recent usage)
        if ($HasMfaEnrolled -eq "No" -or ($HasMfaEnrolled -eq "Cannot Verify" -and -not $HasRecentMfaUsage)) {
            $IsHighRisk = $true
            $RiskLevel = "High"
        }
        # Medium Risk: Has MFA enrolled but not using it recently
        elseif ($HasMfaEnrolled -eq "Yes" -and -not $HasRecentMfaUsage) {
            $RiskLevel = "Medium"
        }
        # Low Risk: Recent MFA usage (regardless of enrollment status)
        else {
            $RiskLevel = "Low"
        }
        
        # Create result with clear enrollment status
        $UserResult = [PSCustomObject]@{
            UserPrincipalName = $User.UserPrincipalName
            DisplayName = $User.DisplayName
            JobTitle = $User.JobTitle
            LastSignIn = $User.SignInActivity.LastSignInDateTime
            HasMfaEnrolled = $HasMfaEnrolled  # Yes/No/Cannot Verify
            MfaUsedLast30Days = $HasRecentMfaUsage
            MfaSignInCount = $UserMfaSignIns.Count
            RiskLevel = $RiskLevel
            IsHighRisk = $IsHighRisk
        }
        
        $Results += $UserResult
        
        if ($IsHighRisk) {
            $HighRiskUsers += $UserResult
        }
    }
    
    # Calculate summary statistics
    $TotalUsers = $Results.Count
    $HighRiskCount = $HighRiskUsers.Count
    $MediumRiskCount = ($Results | Where-Object { $_.RiskLevel -eq "Medium" }).Count
    $LowRiskCount = ($Results | Where-Object { $_.RiskLevel -eq "Low" }).Count
    $WithMfaUsage = ($Results | Where-Object { $_.MfaUsedLast30Days -eq $true }).Count
    $WithMfaEnrolled = ($Results | Where-Object { $_.HasMfaEnrolled -eq "Yes" }).Count
    $CannotVerifyCount = ($Results | Where-Object { $_.HasMfaEnrolled -eq "Cannot Verify" }).Count
    
    # Display results
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "                MFA AUDIT RESULTS" -ForegroundColor Cyan
    Write-Host "                $CustomerName" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    Write-Host "📊 SUMMARY:" -ForegroundColor White
    Write-Host "   Total Active Users: $TotalUsers" -ForegroundColor White
    Write-Host "   Users with MFA Enrolled: $WithMfaEnrolled ($([math]::Round(($WithMfaEnrolled/$TotalUsers)*100,1))%)" -ForegroundColor White
    Write-Host "   Users with Recent MFA Usage: $WithMfaUsage ($([math]::Round(($WithMfaUsage/$TotalUsers)*100,1))%)" -ForegroundColor White
    
    # Show enrollment verification status
    if ($EnrollmentCheckFailed -gt 0) {
        Write-Host "   ⚠️  Enrollment Status Unknown: $CannotVerifyCount users" -ForegroundColor Yellow
        Write-Host "      (Consider re-granting admin consent if this number is high)" -ForegroundColor Gray
    } else {
        Write-Host "   ✅ MFA Enrollment Status Verified: $EnrollmentCheckSuccessful users" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "🎯 RISK BREAKDOWN:" -ForegroundColor White
    Write-Host "   🟢 Low Risk: $LowRiskCount ($([math]::Round(($LowRiskCount/$TotalUsers)*100,1))%)" -ForegroundColor Green
    Write-Host "   🟡 Medium Risk: $MediumRiskCount ($([math]::Round(($MediumRiskCount/$TotalUsers)*100,1))%)" -ForegroundColor Yellow
    Write-Host "   🔴 High Risk: $HighRiskCount ($([math]::Round(($HighRiskCount/$TotalUsers)*100,1))%)" -ForegroundColor Red
    
    # Show high-risk users
    if ($HighRiskCount -gt 0) {
        Write-Host "`n🚨 HIGH-RISK USERS (NO MFA PROTECTION):" -ForegroundColor Red
        $HighRiskUsers | Select-Object -First 10 | ForEach-Object {
            $lastSignIn = if ($_.LastSignIn) { 
                ([DateTime]::Parse($_.LastSignIn)).ToString("MM/dd/yyyy") 
            } else { 
                "Never" 
            }
            $enrollmentStatus = if ($_.HasMfaEnrolled -eq "Cannot Verify") { " [Status Unknown]" } else { "" }
            Write-Host "   • $($_.DisplayName) ($($_.UserPrincipalName))$enrollmentStatus - Last sign-in: $lastSignIn" -ForegroundColor Red
        }
        
        if ($HighRiskCount -gt 10) {
            Write-Host "   ... and $($HighRiskCount - 10) more (see CSV export)" -ForegroundColor Red
        }
        
        Write-Host "`n🔧 RECOMMENDED ACTIONS:" -ForegroundColor Yellow
        Write-Host "   1. Implement conditional access policy requiring MFA for all users" -ForegroundColor Gray
        Write-Host "   2. Contact high-risk users to register and use MFA methods" -ForegroundColor Gray
        Write-Host "   3. Consider blocking sign-ins without MFA" -ForegroundColor Gray
        
        if ($CannotVerifyCount -gt 0) {
            Write-Host "   4. Re-grant admin consent to improve enrollment detection accuracy" -ForegroundColor Gray
        }
    } else {
        Write-Host "`n✅ No high-risk users found - excellent MFA coverage!" -ForegroundColor Green
    }
    
    Write-Host "="*60 -ForegroundColor Cyan
    
    # Export results to CSV
    $timestamp = Get-Date -Format "yyyyMMdd_HHmm"
    $csvPath = ".\MFA_Audit_$($CustomerName.Replace(' ','_'))_$timestamp.csv"
    $Results | Export-Csv -Path $csvPath -NoTypeInformation
    
    Write-Host "`n📄 Full results exported to: $csvPath" -ForegroundColor Green
    
    # Return summary for scripting
    return @{
        CustomerName = $CustomerName
        TotalUsers = $TotalUsers
        HighRiskUsers = $HighRiskCount
        HighRiskPercentage = [math]::Round(($HighRiskCount/$TotalUsers)*100,1)
        MfaEnrolledUsers = $WithMfaEnrolled
        MfaEnrolledPercentage = [math]::Round(($WithMfaEnrolled/$TotalUsers)*100,1)
        EnrollmentVerificationSuccessRate = [math]::Round(($EnrollmentCheckSuccessful/$TotalUsers)*100,1)
        CsvPath = $csvPath
    }
    
} catch {
    Write-Host "`n❌ Audit failed: $($_.Exception.Message)" -ForegroundColor Red
    return $null
} finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}
