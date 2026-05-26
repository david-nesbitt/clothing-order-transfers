# On-premises Data Gateway — Setup Guide

## Overview

The On-premises Data Gateway is installed on **PP01-SV06** (our RDP/general-purpose server). It creates an outbound-only connection to Azure Service Bus, allowing Power Automate to write files directly to UNC paths on the internal network — no inbound firewall rules required.

**Installed:** 2026-05-26 — version 3000.318.9 (May 2026). Status: Online.

| | |
|---|---|
| **Gateway host** | PP01-SV06 |
| **Gateway name** | PP01-SV06-Gateway |
| **M365 registration account** | DavidN@pricesplus.com.au |
| **Region** | Australia Southeast |

---

## Architecture — Two Separate Accounts, Two Separate Purposes

Understanding this distinction is important before configuring anything:

| | Account | Purpose | Permissions needed |
|---|---|---|---|
| **Gateway service account** | `PRICESPLUS\svc_pa_gateway` | Runs the gateway Windows service on PP01-SV06 | "Log on as a service" on PP01-SV06 only — no file share access needed |
| **Connection credentials** | e.g. `PRICESPLUS\TenciaCheckSvc` | Authenticates to a specific resource (file share, SQL Server, etc.) per connection | Write access to the specific UNC path for that connection |

The gateway is **general-purpose** — one installation on PP01-SV06 serves all current and future Power Automate flows at Prices Plus. Each Power Automate connection specifies its own credentials for its own resource. The service account just keeps the gateway service running.

Do not use `TenciaCheckSvc` as the service account — that name implies a specific purpose and would be confusing as more connections are added.

---

## Step 0 — IT Pre-work: Create svc_pa_gateway

Before changing the service account, ask IT to create a dedicated generic gateway service account:

1. **Create the account** in Active Directory:
   - Username: `svc_pa_gateway`
   - Full name: `Power Automate Gateway Service`
   - Password: strong, stored in IT password manager
   - **Password never expires:** Yes
   - **User cannot change password:** Yes
   - No mailbox required

2. **Grant "Log on as a service" right** on PP01-SV06:
   - Local Security Policy → Security Settings → Local Policies → User Rights Assignment → **Log on as a service**
   - Add `PRICESPLUS\svc_pa_gateway`
   - *(The gateway app's Service Settings page can also do this automatically — see Step 2)*

3. **No file share permissions needed** — `svc_pa_gateway` does not access any UNC paths directly. Resource access is handled by per-connection credentials.

---

## Step 1 — Change the Gateway Service Account

The gateway is currently running as the default `NT SERVICE\PBIEgwService`. Change it to `svc_pa_gateway`:

**Option A — via the Gateway app (easiest):**
1. Open the **On-premises data gateway** app on PP01-SV06 (it's in the Start menu / system tray)
2. Click **Service Settings** in the left menu
3. Under "Gateway service account", click **Change account**
4. Enter `PRICESPLUS\svc_pa_gateway` and the password
5. Click **Apply** — the service will restart automatically

**Option B — via Services.msc:**
1. Open `services.msc` on PP01-SV06
2. Find **On-premises data gateway service** (`PBIEgwService`)
3. Right-click → **Properties → Log On tab**
4. Select **This account** → enter `PRICESPLUS\svc_pa_gateway` and password
5. Click OK → right-click → **Restart**

After the restart, confirm the Status page shows the gateway is still **Online**.

---

## Step 2 — Verify Gateway is Still Online

In Power Automate on your local PC:

1. Go to **https://make.powerautomate.com**
2. **Data → Gateways**
3. **PP01-SV06-Gateway** should show status **Online**

If Offline: confirm `PBIEgwService` is Running on PP01-SV06 and the `svc_pa_gateway` password is correct.

---

## Step 3 — Create a File System Connection (for Clothing Order Export)

Each resource gets its own connection with its own credentials. For the clothing order export:

1. Go to **https://make.powerautomate.com**
2. **Data → Connections → + New connection**
3. Search for and select **File System**
4. Fill in the connection details:

   | Field | Value |
   |---|---|
   | Root folder | `\\PPS2012\DataLoad\StkTrans` |
   | Authentication Type | `Windows` |
   | Username | `PRICESPLUS\TenciaCheckSvc` |
   | Password | *(from IT password manager)* |
   | Gateway | `PP01-SV06-Gateway` |

5. Click **Create** — connection should show as **Connected**

> `TenciaCheckSvc` is used here as the *connection* credentials (not the service account) because it already has write access to `\\PPS2012\DataLoad\StkTrans` via the Everyone ACE on that folder.

---

## Adding Future Connections

To use this gateway for other purposes (different file shares, SQL Server, SFTP, etc.):

1. **Data → Connections → + New connection**
2. Select the relevant connector
3. Enter credentials appropriate for *that* resource
4. Select **PP01-SV06-Gateway**

The gateway service account (`svc_pa_gateway`) does not change — only the per-connection credentials differ.

---

## Step 4 — Use in the Clothing Order Export Flow (Task 3.6)

In the flow, the file creation action is:

- Action: **Create file** *(File System connector — not SharePoint)*
- Connection: the File System connection created in Step 3
- Folder path: `/`
- File name: `@{variables('varFileName')}` — e.g. `STKTRAN_014_105676_2026-04-30.txt`
- File content: the CSV string built in step 3.5 of the plan

---

## Ongoing — Gateway Health

Gateway logs are on PP01-SV06 at:
```
C:\Users\svc_pa_gateway\AppData\Local\Microsoft\On-premises data gateway\
```

If a flow run fails with a gateway error, check:
1. `PBIEgwService` is Running on PP01-SV06
2. `svc_pa_gateway` password has not been changed
3. The target UNC path is reachable from PP01-SV06

---

## Recovery

If PP01-SV06 is rebuilt or the gateway needs reinstalling:
1. Re-run the installer
2. Choose **Migrate, restore, or takeover an existing gateway**
3. Enter gateway name `PP01-SV06-Gateway` and the **recovery key** from the IT password manager
