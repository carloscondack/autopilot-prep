# Intune Autopilot Bootstrap (Phishing Resistant MFA)

This repository contains a bootstrap script designed to streamline the manual Intune enrollment of Windows devices in enterprise environments that enforce **Phishing Resistant MFA** (FIDO2 Security Keys, YubiKeys, Windows Hello for Business).

## 🚨 The Problem
In high-security tenants, standard PowerShell-based enrollment methods often fail:
* **Legacy PowerShell (v5.1)** uses older web components (IE-based) for authentication popups.
* These legacy components often **cannot interface with hardware security keys (FIDO2)** or pass strict Conditional Access policies.
* Technicians are frequently unable to authenticate during the OOBE (Out of Box Experience) setup.

## ✅ The Solution
This script automates the transition to a modern authentication stack by:
1.  **Downloading and installing PowerShell 7 (Core)** on the fly.
2.  Setting the correct TLS 1.2 security protocols.
3.  Handing off the enrollment process to PowerShell 7, which natively supports modern web authentication (including FIDO2/YubiKeys).

## 🚀 Usage (OOBE)

Perform these steps on a fresh Windows device during the initial setup screen.

1.  Boot the device and proceed until you reach the **Wi-Fi / Network selection screen**.
2.  **Connect to the internet** (Wi-Fi or Ethernet).
3.  Press **`Shift + F10`** to open a Command Prompt.
4.  Run the following "One-Liner" command:

```cmd
curl -L -o setup.ps1 [https://raw.githubusercontent.com/carloscondack/autopilot-prep/main/IntuneBootstrap.ps1](https://raw.githubusercontent.com/carloscondack/autopilot-prep/main/IntuneBootstrap.ps1) && powershell -ExecutionPolicy Bypass -File setup.ps1