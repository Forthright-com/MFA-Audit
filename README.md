# MSP MFA Audit Tool

> **Quickly identify high-risk users lacking MFA protection across customer tenants**

A PowerShell-based audit system for Managed Service Providers (MSPs) to assess Multi-Factor Authentication (MFA) adoption across customer Microsoft 365 tenants.

## 🎯 What This Does

- **Identifies high-risk users** without MFA protection
- **Audits multiple customer tenants** efficiently
- **Generates actionable reports** with CSV exports
- **Scales from single customer to entire client base**

## ⚡ Quick Start

1. **Setup** (one-time, 30 minutes)
   - Run app registration script
   - Grant consent to customer tenants
   - Install PowerShell prerequisites

2. **Audit** (2-3 minutes per customer)
   ```powershell
   .\Simple-MFA-Audit.ps1 -TenantId "customer.com" -ClientId "your-app-id" -ClientSecret "your-secret" -CustomerName "Contoso Ltd"
   ```

3. **Results**
   - Console output with risk breakdown
   - CSV export with detailed user analysis
   - Clear action items for each customer

## 📊 Typical Results

- **Customer A**: 156 users, 22 high-risk (14.1%) → Needs MFA policy
- **Customer B**: 89 users, 2 high-risk (2.2%) → Good coverage  
- **Customer C**: 234 users, 67 high-risk (28.6%) → URGENT action needed

## 📋 Requirements

- **PowerShell 5.1+** with Microsoft Graph module
- **Azure AD app registration** with required permissions
- **Global admin access** to customer tenants for consent
- **Windows** or **PowerShell Core** on Mac/Linux

## 🚀 Benefits

- **Time Investment**: 30 min setup, 2-3 min per customer audit
- **Visibility**: Clear picture of MFA adoption across customers
- **Action Items**: Specific users needing MFA setup
- **Scalability**: Batch processing for multiple customers
- **Professional**: CSV reports ready for customer communication

## 📁 Repository Structure

```
├── scripts/              # PowerShell audit scripts
├── docs/                 # Setup and usage documentation  
├── templates/            # Customer communication templates
└── examples/             # Sample outputs and configurations
```

## 🛡️ Security Note

This tool requires sensitive permissions. Follow security best practices:
- Store app secrets securely (Azure Key Vault recommended)
- Use separate app registration for each MSP
- Regularly rotate client secrets
- Monitor app usage through Azure AD logs

## 📖 Documentation

- **[Setup Guide](docs/SETUP.md)** - Initial configuration
- **[Usage Guide](docs/USAGE.md)** - Running audits
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues

## 🤝 Contributing

Improvements welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Built for MSPs by MSPs** 🛡️

*Secure your customers' identities, one audit at a time.*
