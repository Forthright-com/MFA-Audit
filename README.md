# MFA-Audit

**PowerShell toolkit for auditing multi-factor authentication (MFA) adoption across customer tenants.**

Perfect for Managed Service Providers (MSPs) who need to quickly assess security posture and identify users requiring MFA enrollment.

## 🎯 **What This Does**

- **Identifies users requiring MFA enrollment** across customer tenants
- **Verifies MFA enrollment status** for each user (enrolled/not enrolled)
- **Tracks MFA usage patterns** over the last 30 days
- **Handles MFA exemptions** via group membership (service accounts, etc.)
- **Identifies recently created accounts** for context on enrollment status
- **Generates actionable reports** with clear status categories
- **Scales to multiple customers** with batch processing
- **Exports detailed CSV files** for further analysis
- **Provides clear recommendations** for improving security

## 📊 **Typical Results**

```
🔍 Starting MFA audit for Contoso Ltd (contoso.com)...
✅ Connected successfully
🔒 Checking for MFA exemption group... Found exemption group with 3 members
📋 Getting active users... Found 156 active users
📊 Getting MFA usage data... Found 89 MFA sign-ins in last 30 days

============================================================
                    MFA AUDIT RESULTS
                     Contoso Ltd
============================================================
📊 SUMMARY:
   Total Active Users: 156
   Users with MFA Enrolled: 134 (85.9%)
   Users with Recent MFA Usage: 89 (57.1%)
   ✅ MFA Enrollment Status Verified: 156 users

🎯 MFA STATUS BREAKDOWN:
   ✅ MFA Active: 89 (57.1%)
   ⚠️ MFA Required: 22 (14.1%)
   🟡 MFA Inactive: 42 (26.9%)
   🔒 MFA Exempted: 3 (1.9%)
   ❓ MFA Unknown: 0 (0.0%)

⚠️ USERS REQUIRING MFA ENROLLMENT:
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

## 🗂 **Files**

| File | Purpose |
|------|---------|
| `scripts/MFA-Audit.ps1` | Main audit script for single customer |
| `scripts/Setup-App-Registration.ps1` | One-time app registration setup |
| `scripts/Multi-Customer-Audit.ps1` | Batch processing multiple customers |
| `docs/setup-guide.md` | Detailed setup instructions |
| `examples/` | Sample outputs and templates |

## 📈 **MFA Status Categories**

- **✅ MFA Active**: Users who have MFA enrolled and used it recently (good security posture)
- **⚠️ MFA Required**: Users with no MFA methods enrolled (immediate action required)
- **🟡 MFA Inactive**: Users who have MFA enrolled but haven't used it recently (policy enforcement needed)
- **🔒 MFA Exempted**: Users intentionally excluded via group membership (service accounts, automation accounts)
- **❓ MFA Unknown**: Cannot verify enrollment status (permission/API issues)

## 💡 **Recommended Workflow**

1. **Monday morning**: Run batch audit across all customers
2. **Review results**: Focus on customers with >10% users requiring MFA enrollment
3. **Contact customers**: Send enrollment lists to admins
4. **Follow up**: Verify MFA policies were implemented

## 🔧 **Requirements**

- **PowerShell 5.1+**
- **Microsoft.Graph PowerShell module**
- **App registration** with these permissions:
  - `AuditLog.Read.All`
  - `Reports.Read.All` 
  - `User.Read.All`
  - `UserAuthenticationMethod.Read.All`

## 🔑 **Permissions Explained**

| Permission | Purpose | Why Needed |
|------------|---------|------------|
| `AuditLog.Read.All` | Read sign-in logs | Detect MFA usage patterns |
| `Reports.Read.All` | Read usage reports | User activity analysis |
| `User.Read.All` | Read user profiles | Enumerate active users |
| `UserAuthenticationMethod.Read.All` | Read MFA enrollment | Verify MFA method registration |

## 🆕 **What's New**

### **Version 2.0 Updates**
- **Enhanced MFA Detection**: Now directly reads user MFA enrollment status
- **MFA Exemption Support**: Handles service accounts and automation users via group membership
- **Recently Created Account Tracking**: Identifies new accounts for context
- **Improved Status Categories**: Clear action-oriented status instead of risk levels
- **Better Reporting**: Professional terminology and actionable recommendations
- **Updated Permissions**: Added UserAuthenticationMethod.Read.All for enrollment detection

### **Migration from v1.x**
If you're upgrading from a previous version:
1. **Update app registration** - Run the new `Setup-App-Registration.ps1`
2. **Re-grant consent** - Customer tenants need to consent to the new permission
3. **Update scripts** - Replace existing scripts with new versions

## 📖 **Documentation**

- [Detailed Setup Guide](docs/setup-guide.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Customer Communication Templates](examples/customer-communication-template.md)

## 🤝 **Contributing**

Feel free to submit issues, feature requests, or pull requests to improve this toolkit.

## ⚖️ **License**

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 📋 **CSV Output Fields**

| Field | Description | Values |
|-------|-------------|---------|
| `UserPrincipalName` | User's email address | user@domain.com |
| `DisplayName` | User's full name | John Smith |
| `JobTitle` | User's role/title | Marketing Manager |
| `LastSignIn` | Last sign-in date | 2025-01-15T10:30:00Z |
| `HasMfaEnrolled` | MFA enrollment status | Yes/No/Cannot Verify |
| `MfaUsedLast30Days` | Recent MFA usage | True/False |
| `MfaSignInCount` | MFA sign-ins in period | 15 |
| `RecentlyCreated` | Account created within 15 days | True/False |
| `MfaStatus` | Current MFA status | MFA Active/Required/Inactive/Exempted/Unknown |

## 🔍 **Troubleshooting**

### **Common Issues**

**"Insufficient privileges to complete the operation"**
- **Cause:** Missing UserAuthenticationMethod.Read.All permission
- **Solution:** Re-run Setup-App-Registration.ps1 and re-grant customer consent

**"MFA Unknown" showing for enrollment**
- **Cause:** Permission not granted for this customer tenant
- **Solution:** Re-grant admin consent for the specific customer

**All users showing "MFA Required"**
- **Cause:** Customer may not have MFA policies enabled
- **Solution:** This is accurate data - implement MFA policies for customer

**Many users showing "MFA Inactive"**
- **Cause:** Users have MFA enrolled but conditional access policies not enforcing usage
- **Solution:** Review and strengthen conditional access policies
