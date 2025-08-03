# MFA-Audit

**PowerShell toolkit for auditing multi-factor authentication (MFA) adoption across customer tenants.**

Method to quickly assess security posture and identify high-risk users lacking MFA protection.

## 🎯 **What This Does**

- **Identifies high-risk users** with no MFA protection across customer tenants
- **Generates actionable reports** with clear risk categories
- **Scales to multiple customers** with batch processing
- **Exports detailed CSV files** for further analysis
- **Provides clear recommendations** for improving security

## 📊 **Typical Results**

```
🔍 Starting MFA audit for Contoso Ltd (contoso.com)...
✅ Connected successfully
📋 Getting active users... Found 156 active users
📊 Getting MFA usage data... Found 89 MFA sign-ins in last 30 days

============================================================
                    MFA AUDIT RESULTS
                     Contoso Ltd
============================================================
📊 SUMMARY:
   Total Active Users: 156
   Users with MFA Methods: 134 (85.9%)
   Users with Recent MFA Usage: 89 (57.1%)

🎯 RISK BREAKDOWN:
   🟢 Low Risk: 89 (57.1%)
   🟡 Medium Risk: 45 (28.8%)
   🔴 High Risk: 22 (14.1%)

🚨 HIGH-RISK USERS (NO MFA PROTECTION):
   • John Smith (john.smith@contoso.com) - Last sign-in: 07/29/2025
   • Jane Doe (jane.doe@contoso.com) - Last sign-in: Never
   • Bob Wilson (bob.wilson@contoso.com) - Last sign-in: 07/25/2025
============================================================
```

## 🚀 **Quick Start**

### **Prerequisites**
- PowerShell with Microsoft Graph module
- Global admin access to customer tenants
- One app registration in your MSP tenant

### **Setup (5 minutes, one-time)**
1. Run `Setup-App-Registration.ps1` to create your app
2. Grant admin consent to customer tenants
3. Save your App ID and Client Secret

### **Single Customer Audit**
```powershell
.\scripts\MFA-Audit.ps1 -TenantId "customer.com" -ClientId "your-app-id" -ClientSecret "your-secret" -CustomerName "Contoso Ltd"
```

### **Multiple Customer Audit**
```powershell
.\scripts\Multi-Customer-Audit.ps1 -ClientId "your-app-id" -ClientSecret "your-secret"
```

## 📁 **Files**

| File | Purpose |
|------|---------|
| `scripts/MFA-Audit.ps1` | Main audit script for single customer |
| `scripts/Setup-App-Registration.ps1` | One-time app registration setup |
| `scripts/Multi-Customer-Audit.ps1` | Batch processing multiple customers |
| `docs/setup-guide.md` | Detailed setup instructions |
| `examples/` | Sample outputs and templates |

## 📈 **Risk Categories**

- **🔴 High Risk**: No MFA methods AND no recent MFA usage
- **🟡 Medium Risk**: Has MFA methods but no recent usage  
- **🟢 Low Risk**: Recent MFA usage (active protection)

## 💡 **Recommended Workflow**

1. **Monday morning**: Run batch audit across all customers
2. **Review results**: Focus on customers with >10% high-risk users
3. **Contact customers**: Send high-risk user lists to admins
4. **Follow up**: Verify MFA policies were implemented

## 🔧 **Requirements**

- **PowerShell 5.1+**
- **Microsoft.Graph PowerShell module**
- **App registration** with these permissions:
  - `AuditLog.Read.All`
  - `Reports.Read.All` 
  - `User.Read.All`

## 📖 **Documentation**

- [Detailed Setup Guide](docs/setup-guide.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Customer Communication Templates](examples/customer-communication-template.md)

## 🤝 **Contributing**

Feel free to submit issues, feature requests, or pull requests to improve this toolkit.

## ⚖️ **License**

This project is licensed under the MIT License - see the LICENSE file for details.
