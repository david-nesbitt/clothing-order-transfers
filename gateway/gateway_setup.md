# On-premises Data Gateway — Setup Guide

## Overview

The On-premises Data Gateway is installed on **PP01-SV06** (our RDP/general-purpose server). It creates an outbound-only connection to Azure Service Bus, allowing Power Automate to write files directly to UNC paths on the internal network — no inbound firewall rules required.

**Confirmed not installed** — PP01-SV06 has no gateway service or registry entries as of 2026-05-26.

---

## Pre-requisites

Before starting, confirm you have:

- [ ] RDP access to **PP01-SV06** with a local Administrator account
- [ ] M365 account: `DavidN@pricesplus.com.au` (tenant: `pricespluscomau`)
- [ ] The destination UNC path confirmed (where OceanicSquare reads import files)
- [ ] A Windows service account (or the `PP01-SV06` machine account) that has **write access** to the destination UNC path — note this for Step 4

---

## Step 1 — Download the Gateway Installer

1. RDP into **PP01-SV06**
2. Open a browser and go to: **https://make.powerautomate.com**
3. Sign in as `DavidN@pricesplus.com.au`
4. In the left navigation: **Data → Gateways**
5. Click **+ New gateway** (top right)
6. A panel appears — click **Download gateway installer**
7. Save the installer (`GatewayInstall.exe`) somewhere accessible (e.g. `C:\Installs\`)

---

## Step 2 — Install the Gateway

Run the installer **as Administrator** on PP01-SV06:

1. Right-click `GatewayInstall.exe` → **Run as administrator**
2. Accept the terms and click **Install**
3. Accept the default install path (`C:\Program Files\On-premises data gateway`)
4. When prompted for a sign-in email: enter `DavidN@pricesplus.com.au`
5. Sign in with your M365 credentials when the browser window opens
6. On the gateway setup screen, choose: **Register a new gateway on this computer**
7. **Gateway name:** `PP01-SV06-Gateway` (or similar — must be unique in the tenant)
8. **Recovery key:** Choose a strong key and **store it securely** (e.g. in a shared IT password manager)
   - This key is required if you ever need to restore or migrate the gateway — it cannot be recovered if lost
9. Click **Configure**
10. Wait for "The gateway _PP01-SV06-Gateway_ is online and ready to be used"

> The gateway installs as a Windows service named **On-premises data gateway service** (`PBIEgwService`), running under the `NT SERVICE\PBIEgwService` account by default.

---

## Step 3 — Verify Gateway is Registered

Back in Power Automate (on your local PC, not PP01-SV06):

1. Go to **https://make.powerautomate.com**
2. **Data → Gateways**
3. You should see **PP01-SV06-Gateway** listed with status **Online**

If it shows Offline: RDP back to PP01-SV06 and check that the **On-premises data gateway** Windows service is Running (Services → `PBIEgwService`).

---

## Step 4 — Set the Gateway Service Account (important)

By default the gateway service runs as `NT SERVICE\PBIEgwService`. This account will **not** have access to network UNC paths.

You need to change the service to run as an account that **can write to the destination UNC path**:

1. On PP01-SV06, open **Services** (`services.msc`)
2. Find **On-premises data gateway service**
3. Right-click → **Properties → Log On tab**
4. Switch from "Local System" to **This account**
5. Enter the domain account that has write permission to the OceanicSquare import UNC path
   - Likely: `PRICESPLUS\<service account>` or `PRICESPLUS\DavidN` (confirm with IT)
6. Enter the account password
7. Click OK → **Restart** the service
8. Confirm the service restarts successfully

> The service account must have:
> - **Log on as a service** right on PP01-SV06
> - **Write** permission on the destination UNC folder

---

## Step 5 — Create the File System Connection in Power Automate

1. Go to **https://make.powerautomate.com**
2. **Data → Connections → + New connection**
3. Search for and select **File System**
4. Fill in the connection details:
   | Field | Value |
   |---|---|
   | Root folder | The UNC path OceanicSquare reads from — e.g. `\\<server>\OceanicSquare\Imports\StockTransfers\` |
   | Authentication Type | `Windows` |
   | Username | The domain account from Step 4 (e.g. `PRICESPLUS\<account>`) |
   | Password | Account password |
   | Gateway | Select **PP01-SV06-Gateway** |
5. Click **Create**
6. The connection should show as **Connected**

> The Root folder is the base path. When creating files in the flow, the file path is relative to this root — so if root is `\\server\imports\` and you specify filename only, the file lands directly in that folder.

---

## Step 6 — Update the Power Automate Flow (Task 3)

In the flow, replace the SharePoint `Create file` action with:

- Action: **Create file** *(File System connector — not SharePoint)*
- Connection: the File System connection created in Step 5
- Folder path: `/` (root of the connection, or a subfolder if needed)
- File name: `@{variables('varFileName')}` — e.g. `STKTRAN_014_105676_2026-04-30.txt`
- File content: the CSV string built in step 3.5 of the plan

Everything else in the flow (Tasks 1, 2, 4, 5) is unchanged.

---

## Ongoing — Gateway Health

The gateway logs are on PP01-SV06 at:
```
C:\Users\<account>\AppData\Local\Microsoft\On-premises data gateway\
```

Power Automate also shows gateway status at **Data → Gateways**. If a flow fails with a gateway error, first check the service is Running on PP01-SV06 and the service account password hasn't expired.

---

## Recovery

If PP01-SV06 is rebuilt or the gateway needs to be reinstalled:
1. Re-run the installer
2. Choose **Migrate, restore, or takeover an existing gateway**
3. Enter the gateway name and the **recovery key** saved in Step 2
