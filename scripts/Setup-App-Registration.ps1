# Setup App Registration for MFA Audit
# Purpose: One-time setup to create app registration with required permissions

Write-Host "🚀 Setting up MFA Audit App Registration..." -ForegroundColor Cyan

try {
    # Connect to Microsoft Graph
    Write-Host "📡 Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"
    
    Write-Host "✅ Connected successfully" -ForegroundColor Green
    
    # Create the app registration
    Write-Host "📝 Creating app registration..." -ForegroundColor Yellow
    $App = New-MgApplication -DisplayName "MSP-MFA-Audit" -SignInAudience "AzureADMultipleOrgs"
    
    Write-Host "✅ App registration created: $($App.DisplayName)" -ForegroundColor Green
    
    # Define required permissions
    $permissions = @(
        @{ Id = "b0afded3-3588-46d8-8b3d-9842eff778da"; Type = "Role" },  # AuditLog.Read.All
        @{ Id = "230c1aed-a721-4c5d-9cb4-a90514e508ef"; Type = "Role" },  # Reports.Read.All
        @{ Id = "df021288-bdef-4463-88db-98f22de89214"; Type = "Role" }   # User.Read.All
    )
    
    # Add permissions to the app
    Write-Host "🔐 Adding required permissions..." -ForegroundColor Yellow
    Update-MgApplication -ApplicationId $App.Id -RequiredResourceAccess @(@{
        ResourceAppId = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph
        ResourceAccess = $permissions
    })
    
    Write-Host "✅ Permissions added successfully" -ForegroundColor Green
    
    # Create client secret
    Write-Host "🔑 Creating client secret..." -ForegroundColor Yellow
    $secret = Add-MgApplicationPassword -ApplicationId $App.Id -PasswordCredential @{
        DisplayName = "MFA-Audit-Secret"
        EndDateTime = [System.DateTime]::Now.AddMonths(24)
    }
    
    Write-Host "✅ Client secret created (expires in 24 months)" -ForegroundColor Green
    
    # Display important information
    Write-Host "`n" + "="*60 -ForegroundColor Red
    Write-Host "           🚨 SAVE THESE VALUES 🚨" -ForegroundColor Red
    Write-Host "="*60 -ForegroundColor Red
    Write-Host "App ID (Client ID): " -NoNewline -ForegroundColor Yellow
    Write-Host "$($App.AppId)" -ForegroundColor White
    Write-Host "Client Secret: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($secret.SecretText)" -ForegroundColor White
    Write-Host "="*60 -ForegroundColor Red
    
    Write-Host "`n📋 NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Save the App ID and Client Secret above" -ForegroundColor Gray
    Write-Host "2. Grant admin consent for each customer tenant:" -ForegroundColor Gray
    Write-Host "   https://login.microsoftonline.com/CUSTOMER-DOMAIN.com/adminconsent?client_id=$($App.AppId)&redirect_uri=https://localhost" -ForegroundColor Gray
    Write-Host "3. Run MFA-Audit.ps1 with your saved credentials" -ForegroundColor Gray
    
    Write-Host "`n✅ Setup complete! App registration ready for use." -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please check your permissions and try again." -ForegroundColor Yellow
} finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}
