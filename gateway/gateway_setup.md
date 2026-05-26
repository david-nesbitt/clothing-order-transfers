# On-premises Data Gateway — Setup Guide

## Overview

The On-premises Data Gateway is installed on **PP01-SV06** (our RDP/general-purpose server). It creates an outbound-only connection to Azure Service Bus, allowing Power Automate to write files directly to UNC paths on the internal network — no inbound firewall rules required.

**Confirmed not installed** — PP01-SV06 has no gateway service or registry entries as of 2026-05-26.

| | |
|---|---|
| **Gateway host** | PP01-SV06 |
| **Gateway name** | PP01-SV06-Gateway |
| **Destination UNC path** | `\\PPS2012\DataLoad\StkTrans` |
| **Service account** | `PRICESPLUS\TenciaCheckSvc` *(existing — no new account needed, see below)* |
| **M365 registration account** | `DavidN@pricesplus.com.au` |

---

## Service Account Decision — Reuse TenciaCheckSvc

`PRICESPLUS\TenciaCheckSvc` already exists as a dedicated domain service account (used by the TenciaConnectChecker project). It can be reused here — no new AD account needed.

**Why it already has access to `\\PPS2012\DataLoad\StkTrans`:**
The folder ACL includes `Everyone: FullControl`, which covers any authenticated domain account including `TenciaCheckSvc`. Confirmed by reading the ACL on `E:\DataLoad\StkTrans` on PPS2012 directly.

> Note: The ACL also contains two unresolved SIDs (orphaned deleted accounts). These can be cleaned up by IT at any time — right-click the folder → Properties → Security → Advanced → remove any entries showing as SIDs without names.

The gateway service will run as `PRICESPLUS\TenciaCheckSvc`. The password for this account is stored in the IT password manager.

---

## Step 1 — Download the Gateway Installer

1. RDP into **PP01-SV06** (log in as your own account or a local admin)
2. Open a browser and go to **https://make.powerautomate.com**
3. Sign in as `DavidN@pricesplus.com.au`
4. In the left navigation: **Data → Gateways**
5. Click **+ New gateway** (top right)
6. A panel appears — click **Download gateway installer**
7. Save `GatewayInstall.exe` to `C:\Installs\` (create the folder if needed)

---

## Step 2 — Install the Gateway

Run the installer **as Administrator** on PP01-SV06:

1. Right-click `GatewayInstall.exe` → **Run as administrator**
2. Accept the terms and click **Install**
3. Accept the default install path (`C:\Program Files\On-premises data gateway`)
4. When prompted for a sign-in email: enter `DavidN@pricesplus.com.au`
5. Sign in with your M365 credentials in the browser window that opens
6. Choose: **Register a new gateway on this computer**
7. **Gateway name:** `PP01-SV06-Gateway`
8. **Recovery key:** Choose a strong key and **store it in the IT password manager**
   - Required to restore or migrate the gateway if PP01-SV06 is ever rebuilt — cannot be recovered if lost
9. Click **Configure**
10. Wait for: *"The gateway PP01-SV06-Gateway is online and ready to be used"*

> The gateway installs as Windows service **On-premises data gateway service** (`PBIEgwService`), initially running as `NT SERVICE\PBIEgwService`. This is changed in the next step.

---

## Step 3 — Switch the Service to TenciaCheckSvc

The default service identity cannot access network UNC paths. Change it to `TenciaCheckSvc`:

1. On PP01-SV06, open **Services** (`services.msc`)
2. Find **On-premises data gateway service**
3. Right-click → **Properties → Log On tab**
4. Select **This account**
5. Enter: `PRICESPLUS\TenciaCheckSvc`
6. Enter the password (from IT password manager)
7. Click **OK**
8. Right-click the service → **Restart**
9. Confirm status returns to **Running**

> If the service fails to start: the account may need the **"Log on as a service"** right granted on PP01-SV06.
> To check: Local Security Policy → Security Settings → Local Policies → User Rights Assignment → Log on as a service → add `PRICESPLUS\TenciaCheckSvc`.

---

## Step 4 — Verify Gateway is Online

Back in Power Automate on your local PC:

1. Go to **https://make.powerautomate.com**
2. **Data → Gateways**
3. **PP01-SV06-Gateway** should show status **Online**

If Offline: confirm `PBIEgwService` is Running on PP01-SV06 and the TenciaCheckSvc password is correct.

---

## Step 5 — Create the File System Connection in Power Automate

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

5. Click **Create**
6. Connection should show as **Connected**

> Files created by the flow land directly in `\\PPS2012\DataLoad\StkTrans` — no subfolder needed.

---

## Step 6 — Update the Power Automate Flow (Task 3.6)

In the flow, the file creation action is:

- Action: **Create file** *(File System connector — not SharePoint)*
- Connection: the File System connection created in Step 5
- Folder path: `/`
- File name: `@{variables('varFileName')}` — e.g. `STKTRAN_014_105676_2026-04-30.txt`
- File content: the CSV string built in step 3.5 of the plan

Everything else in the flow (Tasks 1, 2, 4, 5) is unchanged.

---

## Ongoing — Gateway Health

Gateway logs are on PP01-SV06 at:
```
C:\Users\TenciaCheckSvc\AppData\Local\Microsoft\On-premises data gateway\
```

Power Automate shows live gateway status at **Data → Gateways**. If a flow run fails with a gateway error, check:

1. `PBIEgwService` is Running on PP01-SV06
2. `TenciaCheckSvc` password has not been changed (it should be set to never expire)
3. `\\PPS2012\DataLoad\StkTrans` is reachable from PP01-SV06

---

## Recovery

If PP01-SV06 is rebuilt or the gateway needs reinstalling:
1. Re-run the installer
2. Choose **Migrate, restore, or takeover an existing gateway**
3. Enter gateway name `PP01-SV06-Gateway` and the **recovery key** from the IT password manager
