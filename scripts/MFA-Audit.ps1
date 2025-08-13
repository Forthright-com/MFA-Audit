# MFA Audit Script 
# Purpose: Assess MFA adoption and identify users requiring MFA enrollment

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
    [int]$DaysBack = 30,
    
    [Parameter(Mandatory=$false, HelpMessage="Name of group containing MFA-exempt users")]
    [string]$MfaBypassGroupName = "MFA-Bypass-ServiceAccounts"
)

Write-Host "🔍 Starting MFA audit for $CustomerName ($TenantId)..." -ForegroundColor Cyan

try {
    # Connect to customer tenant
    $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
    Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $Credential -NoWelcome
    
    Write-Host "✅ Connected successfully" -ForegroundColor Green
    
    # Get MFA bypass group members
    Write-Host "🔒 Checking for MFA exemption group..." -ForegroundColor Yellow
    $MfaBypassMembers = @()
    try {
        $BypassGroup = Get-MgGroup -Filter "displayName eq '$MfaBypassGroupName'" -ErrorAction Stop
        if ($BypassGroup) {
            $MfaBypassMembers = Get-MgGroupMember -GroupId $BypassGroup.Id | Select-Object -ExpandProperty Id
            Write-Host "   Found exemption group with $($MfaBypassMembers.Count) members" -ForegroundColor Gray
        } else {
            Write-Host "   No exemption group found with name: $MfaBypassGroupName" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   Cannot access exemption group: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    # Get active users only
    Write-Host "📋 Getting active users..." -ForegroundColor Yellow
    $Users = Get-MgUser -All -Filter "accountEnabled eq true and userType eq 'Member'" -Select "UserPrincipalName,DisplayName,JobTitle,SignInActivity,Id,CreatedDateTime" | 
        Where-Object { $_.UserPrincipalName -notlike "*#EXT#*" }
    
    Write-Host "   Found $($Users.Count) active users" -ForegroundColor Gray
    
    # Get MFA sign-ins from last X days
    Write-Host "📊 Getting MFA usage data..." -ForegroundColor Yellow
    $CutoffDate = (Get-Date).AddDays(-$DaysBack)
    
    try {
        # Get all MFA sign-ins
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
        Write-Host "   ⚠️ Could not get MFA sign-in data: $($_.Exception.Message)" -ForegroundColor Yellow
        $RecentMfaSignIns = @()
    }
    
    # Analyze each user
    Write-Host "🔍 Analyzing users for MFA status..." -ForegroundColor Yellow
    $Results = @()
    $EnrollmentCheckSuccessful = 0
    $EnrollmentCheckFailed = 0
    
    # Initialize status counters
    $MfaActiveCount = 0
    $MfaRequiredCount = 0
    $MfaInactiveCount = 0
    $MfaExemptedCount = 0
    $MfaUnknownCount = 0
    
    foreach ($User in $Users) {
        # Check if user is in MFA bypass group
        $IsExempted = $MfaBypassMembers -contains $User.Id
        
        # Check if account was created within last 15 days
        $RecentlyCreated = $false
        if ($User.CreatedDateTime) {
            $CreationDate = [DateTime]::Parse($User.CreatedDateTime)
            $RecentlyCreated = $CreationDate -ge (Get-Date).AddDays(-15)
        }
        
        # Check MFA enrollment
        $HasMfaEnrolled = "Unknown"
        
        if (-not $IsExempted) {
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
                $HasMfaEnrolled = "Cannot Verify"
                $EnrollmentCheckFailed++
            }
        }
        
        # Check recent MFA usage
        $UserMfaSignIns = $RecentMfaSignIns | Where-Object { $_.userPrincipalName -eq $User.UserPrincipalName }
        $HasRecentMfaUsage = $UserMfaSignIns.Count -gt 0
        
        # Determine MFA status
        $MfaStatus = ""
        
        if ($IsExempted) {
            $MfaStatus = "MFA Exempted"
            $MfaExemptedCount++
        }
        elseif ($HasMfaEnrolled -eq "Cannot Verify") {
            $MfaStatus = "MFA Unknown"
            $MfaUnknownCount++
        }
        elseif ($HasMfaEnrolled -eq "No") {
            $MfaStatus = "MFA Required"
            $MfaRequiredCount++
        }
        elseif ($HasMfaEnrolled -eq "Yes" -and $HasRecentMfaUsage) {
            $MfaStatus = "MFA Active"
            $MfaActiveCount++
        }
        elseif ($HasMfaEnrolled -eq "Yes" -and -not $HasRecentMfaUsage) {
            $MfaStatus = "MFA Inactive"
            $MfaInactiveCount++
        }
        else {
            $MfaStatus = "MFA Unknown"
            $MfaUnknownCount++
        }
        
        # Create result
        $UserResult = [PSCustomObject]@{
            UserPrincipalName = $User.UserPrincipalName
            DisplayName = $User.DisplayName
            JobTitle = $User.JobTitle
            LastSignIn = $User.SignInActivity.LastSignInDateTime
            HasMfaEnrolled = $HasMfaEnrolled
            MfaUsedLast30Days = $HasRecentMfaUsage
            MfaSignInCount = $UserMfaSignIns.Count
            RecentlyCreated = $RecentlyCreated
            MfaStatus = $MfaStatus
        }
        
        $Results += $UserResult
    }
    
    # Calculate summary statistics
    $TotalUsers = $Results.Count
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
        Write-Host "   ⚠️ Enrollment Status Unknown: $CannotVerifyCount users" -ForegroundColor Yellow
        Write-Host "      (Consider re-granting admin consent if this number is high)" -ForegroundColor Gray
    } else {
        Write-Host "   ✅ MFA Enrollment Status Verified: $EnrollmentCheckSuccessful users" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "🎯 MFA STATUS BREAKDOWN:" -ForegroundColor White
    Write-Host "   ✅ MFA Active: $MfaActiveCount ($([math]::Round(($MfaActiveCount/$TotalUsers)*100,1))%)" -ForegroundColor Green
    Write-Host "   ⚠️ MFA Required: $MfaRequiredCount ($([math]::Round(($MfaRequiredCount/$TotalUsers)*100,1))%)" -ForegroundColor Red
    Write-Host "   🟡 MFA Inactive: $MfaInactiveCount ($([math]::Round(($MfaInactiveCount/$TotalUsers)*100,1))%)" -ForegroundColor Yellow
    Write-Host "   🔒 MFA Exempted: $MfaExemptedCount ($([math]::Round(($MfaExemptedCount/$TotalUsers)*100,1))%)" -ForegroundColor Blue
    Write-Host "   ❓ MFA Unknown: $MfaUnknownCount ($([math]::Round(($MfaUnknownCount/$TotalUsers)*100,1))%)" -ForegroundColor Magenta
    
    # Show users requiring MFA enrollment
    $UsersRequiringMfa = $Results | Where-Object { $_.MfaStatus -eq "MFA Required" }
    if ($UsersRequiringMfa.Count -gt 0) {
        Write-Host "`n⚠️ USERS REQUIRING MFA ENROLLMENT:" -ForegroundColor Red
        $UsersRequiringMfa | Select-Object -First 10 | ForEach-Object {
            $lastSignIn = if ($_.LastSignIn) { 
                ([DateTime]::Parse($_.LastSignIn)).ToString("MM/dd/yyyy") 
            } else { 
                "Never" 
            }
            Write-Host "   • $($_.DisplayName) ($($_.UserPrincipalName)) - Last sign-in: $lastSignIn" -ForegroundColor Red
        }
        
        if ($UsersRequiringMfa.Count -gt 10) {
            Write-Host "   ... and $($UsersRequiringMfa.Count - 10) more (see CSV export)" -ForegroundColor Red
        }
        
        Write-Host "`n🔧 RECOMMENDED ACTIONS:" -ForegroundColor Yellow
        Write-Host "   1. Implement conditional access policy requiring MFA for all users" -ForegroundColor Gray
        Write-Host "   2. Contact users requiring MFA to register authentication methods" -ForegroundColor Gray
        Write-Host "   3. Review inactive MFA users for policy enforcement" -ForegroundColor Gray
        Write-Host "   4. Validate exempted users still require bypass" -ForegroundColor Gray
        
        if ($CannotVerifyCount -gt 0) {
            Write-Host "   5. Re-grant admin consent to improve enrollment detection accuracy" -ForegroundColor Gray
        }
    } else {
        Write-Host "`n✅ All users have MFA enrolled or are properly exempted" -ForegroundColor Green
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
        MfaActiveCount = $MfaActiveCount
        MfaRequiredCount = $MfaRequiredCount
        MfaInactiveCount = $MfaInactiveCount
        MfaExemptedCount = $MfaExemptedCount
        MfaUnknownCount = $MfaUnknownCount
        MfaRequiredPercentage = [math]::Round(($MfaRequiredCount/$TotalUsers)*100,1)
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
