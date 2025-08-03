# MFA Audit Setup Guide

## 🎯 **What You Need**

1. **One app registration** in your MSP tenant
2. **Global admin access** to customer tenants for consent
3. **The audit scripts** from this repository
4. **PowerShell with Microsoft Graph module**

---

## 📋 **Step 1: Install Prerequisites (5 minutes, one-time)**

```powershell
# Install Microsoft Graph PowerShell module
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

---

## 📋 **Step 2: Create App Registration (5 minutes, one-time)**

Run the setup script to create your app registration:

```powershell
.\scripts\Setup-App-Registration.ps1
```

This script will:
- Create an app registration named "MSP-MFA-Audit"
- Add required permissions (AuditLog.Read.All, Reports.Read.All, User.Read.All)
- Generate a client secret valid for 24 months
- Display your App ID and Client Secret

**💾 Save the App ID and Secret** - you'll need these for every audit.

### **Manual Setup (Alternative)**

If you prefer to create the app registration manually:

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"

# Create the app
$App = New-MgApplication -DisplayName "MSP-MFA-Audit" -SignInAudience "AzureADMultipleOrgs"

# Add required permissions
$permissions = @(
    @{ Id = "b0afded3-3588-46d8-8b3d-9842eff778da"; Type = "Role" },  # AuditLog.Read.All
    @{ Id = "230c1aed-a721-4c5d-9cb4-a90514e508ef"; Type = "Role" },  # Reports.Read.All
    @{ Id = "df021288-bdef-4463-88db-98f22de89214"; Type = "Role" }   # User.Read.All
)

Update-MgApplication -ApplicationId $App.Id -RequiredResourceAccess @(@{
    ResourceAppId = "00000003-0000-0000-c000-000000000000"
    ResourceAccess = $permissions
})

# Create client secret
$secret = Add-MgApplicationPassword -ApplicationId $App.Id -PasswordCredential @{
    DisplayName = "MFA-Audit-Secret"
    EndDateTime = [System.DateTime]::Now.AddMonths(24)
}

Write-Host "SAVE THESE VALUES:" -ForegroundColor Red
Write-Host "App ID: $($App.AppId)" -ForegroundColor Yellow
Write-Host "Secret: $($secret.SecretText)" -ForegroundColor Yellow

Disconnect-MgGraph
```

---

## 📋 **Step 3: Grant Consent to Customer Tenants (2 minutes per customer)**

For each customer tenant you want to audit:

### **Generate Consent URL**
Replace `YOUR-APP-ID` with your actual App ID from Step 2, as well as replace `CUSTOMER-DOMAIN`:

```
https://login.microsoftonline.com/CUSTOMER-DOMAIN.com/adminconsent?client_id=YOUR-APP-ID&redirect_uri=https://localhost
```

### **Grant Consent Process**
1. **Sign in as Global Admin** to the customer tenant using the consent URL
2. **Review the permissions** being requested
3. **Click "Accept"** to grant permissions
4. **Ignore the localhost error** - this indicates successful consent
5. **Repeat for each customer tenant** you manage

### **Permissions Being Requested**
- **AuditLog.Read.All**: Read audit log data (required for MFA sign-in analysis)
- **Reports.Read.All**: Read usage reports (required for user activity)
- **User.Read.All**: Read user profiles (required for user enumeration)

---

## 📋 **Step 4: Download and Prepare Scripts**

1. **Download this repository** or clone it locally
2. **Extract to a working directory** (e.g., `C:\MFA-Audit\`)
3. **Open PowerShell** in that directory
4. **Test the connection** with a single customer first

---

## 📋 **Step 5: Run Your First Audit**

### **Single Customer Test**
Start with one customer to verify everything works:

```powershell
.\scripts\MFA-Audit.ps1 -TenantId "customer.com" -ClientId "your-app-id" -ClientSecret "your-secret" -CustomerName "Test Customer"
```

### **Expected Output**
```
🔍 Starting MFA audit for Test Customer (customer.com)...
✅ Connected successfully
📋 Getting active users... Found 156 active users
📊 Getting MFA usage data... Found 89 MFA sign-ins in last 30 days
🔍 Analyzing users for MFA risk...

============================================================
                    MFA AUDIT RESULTS
                     Test Customer
============================================================
📊 SUMMARY:
   Total Active Users: 156
   Users with MFA Methods: 134 (85.9%)
   Users with Recent MFA Usage: 89 (57.1%)

🎯 RISK BREAKDOWN:
   🟢 Low Risk: 89 (57.1%)
   🟡 Medium Risk: 45 (28.8%)
   🔴 High Risk: 22 (14.1%)

📄 Full results exported to: .\MFA_Audit_Test_Customer_20250731_1430.csv
```

---

## 📋 **Step 6: Scale to Multiple Customers**

### **Update Customer List**
Edit `scripts\Multi-Customer-Audit.ps1` and update the customer list:

```powershell
$Customers = @(
    @{Name="Contoso Ltd"; TenantId="contoso.com"},
    @{Name="Fabrikam Inc"; TenantId="fabrikam.com"},
    @{Name="Northwind Traders"; TenantId="northwind.com"},
    @{Name="Adventure Works"; TenantId="adventure-works.com"}
    # Add your actual customers here
)
```

### **Run Batch Audit**
```powershell
.\scripts\Multi-Customer-Audit.ps1 -ClientId "your-app-id" -ClientSecret "your-secret"
```

---

## 🔧 **Troubleshooting**

### **Common Issues**

**"Application not found" Error**
- Verify your App ID is correct
- Ensure the app registration exists in your tenant

**"Insufficient privileges" Error**
- Admin consent not granted for this customer
- Re-run the consent process for this customer

**"User not found" Error**
- Check that you're using the customer's tenant domain
- Verify you have the correct tenant ID

**No MFA sign-in data returned**
- Customer may not have any MFA sign-ins
- API might be throttled (add delays between customers)

### **Permissions Verification**
To verify permissions are granted correctly:

```powershell
# Connect to customer tenant
Connect-MgGraph -TenantId "customer.com" -ClientId "your-app-id" -ClientSecret "your-secret"

# Test basic access
Get-MgUser -Top 5
Get-MgAuditLogSignIn -Top 5

Disconnect-MgGraph
```

---

## 💡 **Best Practices**

### **Security**
- **Store credentials securely** - consider using Azure Key Vault for production
- **Rotate client secrets** every 12-24 months
- **Use least privilege** - only grant permissions you actually need
- **Monitor usage** - track which customers are being audited

### **Operational**
- **Weekly routine**: Run batch audits every Monday morning
- **Customer communication**: Send results to customer admins promptly
- **Follow up**: Track which customers implement MFA policies
- **Documentation**: Keep records of audit results and customer responses

### **Performance**
- **Batch processing**: Use Multi-Customer-Audit.ps1 for efficiency
- **Rate limiting**: Add delays between API calls if you hit throttling
- **Parallel processing**: Run multiple customer audits simultaneously (advanced)

---

## 📊 **Understanding the Results**

### **Risk Categories**
- **🔴 High Risk**: No MFA methods AND no recent MFA usage (immediate action required)
- **🟡 Medium Risk**: Has MFA methods but no recent usage (policy enforcement needed)
- **🟢 Low Risk**: Recent MFA usage (good security posture)

### **Key Metrics**
- **Total Active Users**: Internal users with active accounts
- **Users with MFA Methods**: Users who have enrolled MFA methods
- **Users with Recent MFA Usage**: Users who've used MFA in the last 30 days
- **High-Risk Percentage**: % of users with no MFA protection

### **CSV Export Fields**
- `UserPrincipalName`: User's email address
- `DisplayName`: User's full name
- `JobTitle`: User's role/title
- `LastSignIn`: Last sign-in date
- `HasMfaMethods`: TRUE if user has MFA methods enrolled
- `RecentMfaUsage`: TRUE if user used MFA in last 30 days
- `MfaSignInCount`: Number of MFA sign-ins in period
- `RiskLevel`: High/Medium/Low risk assessment
- `IsHighRisk`: TRUE for high-risk users

---

## 🎯 **Success Metrics**

### **Initial Baseline**
After your first round of audits, you should have:
- **Customer risk assessment** for each tenant
- **High-risk user counts** for prioritization
- **Baseline metrics** for tracking improvement

### **Ongoing Tracking**
Week over week, track:
- **Reduction in high-risk users**
- **Increase in MFA method enrollment**
- **Improvement in MFA usage rates**
- **Customer policy implementation**

### **Target Goals**
- **<5% high-risk users** per customer (excellent)
- **<10% high-risk users** per customer (good)
- **>15% high-risk users** per customer (needs immediate attention)

---

## 🚀 **Next Steps**

1. **Complete setup** following this guide
2. **Test with one customer** to verify everything works
3. **Add all your customers** to the batch script
4. **Establish weekly routine** for regular audits
5. **Create customer communication** templates
6. **Track improvements** over time

**You should be auditing customer MFA security within 30 minutes of setup completion.**
