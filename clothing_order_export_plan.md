# Claude Code Plan: Clothing Order Export Automation
## Power Automate — Smartsheet to CSV via Scheduled Flow

---

## Context & Goal

Build a scheduled Power Automate flow that runs daily at 7:00 PM **Brisbane Time (AEST, UTC+10)**. It reads rows from the **Clothing Order Form** Smartsheet, exports qualifying rows — one CSV file per row — to a **SharePoint folder**, ticks the "Exported Transfer" checkbox on each processed row back in Smartsheet, and sends two Microsoft Teams notifications — one to the warehouse team and one per unique "Post to Location" store. All timestamps and message times displayed to users must be in **Brisbane local time (AEST UTC+10)**.

---

## Source Sheet Details

- **Sheet Name:** Clothing Order Form
- **Workspace:** Online Forms
- **Sheet ID:** `5041000518995844`
- **Smartsheet API Base URL:** `https://api.smartsheet.com/2.0`

### Columns Reference (with IDs)

| Column Title | Column ID | Type | Notes |
|---|---|---|---|
| Document Name | `5978907523108740` | TEXT_NUMBER | Hidden, locked |
| Created Date | `2863694728875908` | DATETIME | System column |
| Employee ID | `8551502017679236` | TEXT_NUMBER | Primary column |
| Employee Full Name | `388727693070212` | TEXT_NUMBER | |
| Post to Location | `4094810949373828` | PICKLIST | e.g. "031 - Toowoomba" |
| Post to Location ID | `1533107887886212` | TEXT_NUMBER | Hidden |
| Post to Location Name | `6036707515256708` | TEXT_NUMBER | Hidden |
| Employee's Main Workplace Y/N | `3971665647062916` | PICKLIST | Yes / No |
| Main Workplace (if diff.) | `4892327320440708` | PICKLIST | |
| Shirt Size | `2640527506755460` | PICKLIST | e.g. "M (code 9991003)" |
| Shirt Cost | `6420449018728324` | TEXT_NUMBER | |
| Shirt Quantity | `7144127134125956` | TEXT_NUMBER | |
| Total Cost | `699131539443588` | TEXT_NUMBER | |
| Employee Declaration | `1514627599912836` | CHECKBOX | |
| Picked Date | `6046473727463300` | DATE | |
| Picked Quantity | `3794673913778052` | TEXT_NUMBER | **Export trigger: value > 0** |
| Exported Transfer | `2388194816724868` | CHECKBOX | **Ticked true after export** |

### Post to Location Picklist Values
001 - Warehouse Distribution Centre, 002 - Support Office, 012 - Bowen, 014 - Blackwater,
017 - Mossman, 018 - Hermit Park, 019 - Inverell, 021 - Brassall, 022 - Bribie Island,
023 - Moranbah, 026 - Innisfail, 027 - Tully, 028 - Ingham, 029 - Woodlands,
030 - Charters Towers, 031 - Toowoomba, 032 - Kingaroy, 033 - Willows, 034 - Muswellbrook,
036 - Atherton, 037 - Longreach, 038 - Charleville, 040 - Smithfield, 041 - Atherton Overflow,
042 - Charters Towers Overflow, 043 - Ayr, 044 - Mareeba, 045 - Calliope

---

## Pre-requisites Checklist

| # | Item | Status |
|---|---|---|
| 1 | Smartsheet `Exported Transfer` column added (CHECKBOX, ID: `2388194816724868`) | ✅ Done |
| 2 | CSV file per row — column structure defined in `csv/csv_structure.md` | ✅ Done |
| 3 | SharePoint site URL and target folder path for CSV output | ⬜ To be supplied |
| 4 | Smartsheet API token (from Account > Personal Settings > API Access) | ⬜ To be supplied |
| 5 | Teams channel ID — Warehouse team | ⬜ To be supplied at build time |
| 6 | Teams channel IDs — one per Post to Location store | ⬜ To be supplied at build time |
| 7 | Teams message content — Warehouse notification | ⬜ To be defined at build time |
| 8 | Teams message content — Post to Location notification | ⬜ To be defined at build time |
| 9 | Power Automate Premium licence confirmed | ✅ Confirmed |

---

## Tasks

---

### Task 1 — Create the Scheduled Flow Trigger

**1.1 — Create a new Scheduled Cloud Flow**
- Trigger: `Recurrence`
- Frequency: `Day`
- At: `09:00 AM UTC` (which equals 7:00 PM AEST Brisbane Time, UTC+10)
- Name the flow: `Clothing Order Export — Daily 7PM Brisbane`

> **Timezone note:** Power Automate's Recurrence trigger runs in UTC. Brisbane is UTC+10 and does not observe daylight saving, so 7:00 PM AEST is always 09:00 UTC. Set the trigger to 09:00 UTC.

**1.2 — Initialize variables**

Add the following `Initialize variable` actions at the start of the flow:

| Variable Name | Type | Initial Value |
|---|---|---|
| `varSheetId` | String | `5041000518995844` |
| `varAPIToken` | String | *(Smartsheet API token — use a named secret or connection, not plaintext)* |
| `varExportedColumnId` | String | `2388194816724868` |
| `varExportRows` | Array | `[]` |
| `varBrisbaneTime` | String | `@{convertTimeZone(utcNow(), 'UTC', 'E. Australia Standard Time', 'dd/MM/yyyy HH:mm')}` |
| `varTimestamp` | String | `@{convertTimeZone(utcNow(), 'UTC', 'E. Australia Standard Time', 'yyyyMMdd_HHmm')}` |

> All times shown in Teams messages and file names must use `varBrisbaneTime` or `varTimestamp` — never raw UTC values. Power Automate's timezone string for Brisbane is `'E. Australia Standard Time'`.

---

### Task 2 — Fetch and Filter Rows from Smartsheet

**2.1 — HTTP action: Get sheet**
- Action: `HTTP`
- Method: `GET`
- URI:
  ```
  https://api.smartsheet.com/2.0/sheets/5041000518995844?includeAll=true
  ```
- Headers:
  ```
  Authorization: Bearer @{variables('varAPIToken')}
  Content-Type: application/json
  ```

**2.2 — Parse JSON**
- Use `Parse JSON` on the HTTP response body
- Generate schema from a sample Smartsheet API response

**2.3 — Filter rows**
Use a `Filter array` action on `body/rows` to select only rows where:
- The cell with `columnId` = `3794673913778052` (Picked Quantity) has a `value` greater than `0`
- AND the cell with `columnId` = `2388194816724868` (Exported Transfer) has a `value` of `false` or is null/empty

> **Important:** Smartsheet returns cells as an array inside each row. You cannot reference cells by index — you must use a `Filter array` or nested expression to find the cell where `columnId` matches, then read its `value`.

**2.4 — Store filtered rows**
Set `varExportRows` to the output of the filter array.

---

### Task 3 — Create One CSV File Per Row in SharePoint

> Full column specification: see `csv/csv_structure.md`

**3.1 — Apply to each row in varExportRows**

**3.2 — Extract cell values**

Add `Initialize variable` actions inside the loop to extract each required cell. Use this pattern for every field:
```
@{first(filter(item()?['cells'], equals(string(item()?['columnId']), '<COLUMN_ID>')))?['value']}
```

| Variable | Column ID | Notes |
|---|---|---|
| `varEmployeeID` | `8551502017679236` | |
| `varEmployeeFullName` | `388727693070212` | Convert to UPPERCASE in expression |
| `varPostToLocationID` | `1533107887886212` | 3-digit string, leading zero must be preserved |
| `varShirtSize` | `2640527506755460` | Full value e.g. `S (code 9991002)` |
| `varPickedQuantity` | `3794673913778052` | |
| `varPickedDate` | `6046473727463300` | Format to `dd/MM/yyyy` and `yyyy-MM-dd` separately |
| `varCreatedDate` | `2863694728875908` | Format to `dd/MM/yyyy` |

**3.3 — Derive Stock Code from Shirt Size**

Parse the 7-digit stock code directly from `varShirtSize` — no Switch needed:
```
substring(variables('varShirtSize'), add(indexOf(variables('varShirtSize'), 'code '), 5), 7)
```
Store as `varStockCode`.

**3.4 — Build filename**
```
concat('STKTRAN_', variables('varPostToLocationID'), '_', variables('varEmployeeID'), '_', formatDateTime(<PickedDate_value>, 'yyyy-MM-dd'), '.txt')
```

**3.5 — Build CSV content (no header row)**

Concatenate all 14 fields as a single comma-separated string. The output is one data row with no header:
```
concat(
  '',                                                                    ,  Field 1: DOC_HEADS_REFERENCE_NBR (empty)
  ',', formatDateTime(<PickedDate>, 'dd/MM/yyyy'),                       ,  Field 2: DOC_HEADS_TRANS_DATE
  ',', variables('varEmployeeID'), ' CLOTHING ORDER',                    ,  Field 3: DOC_HEADS_DETAIL
  ',S',                                                                  ,  Field 4: TRANS_LINES_LINE_TYPE
  ',001',                                                                ,  Field 5: DOC_HEADS_STOCK_LOCATION (always 001)
  ',', variables('varPostToLocationID'),                                  ,  Field 6: TRANS_LINES_STOCK_LOCATION
  ',', variables('varStockCode'),                                         ,  Field 7: TRANS_LINES_STOCK_CODE
  ',', variables('varEmployeeID'), ' ', toUpper(variables('varEmployeeFullName')),  ,  Field 8: TRANS_LINES_DESCRIPTION
  ',', variables('varPickedQuantity'),                                    ,  Field 9: TRANS_LINES_ENTERED_QTY
  ',', variables('varEmployeeID'),                                        ,  Field 10: TRANS_LINES_USER_FIELD_1
  ',SHIRT ORDER',                                                        ,  Field 11: TRANS_LINES_USER_FIELD_2
  ',', formatDateTime(<PickedDate>, 'dd/MM/yyyy'),                       ,  Field 12: TRANS_LINES_USER_FIELD_3
  ',', formatDateTime(<CreatedDate>, 'dd/MM/yyyy'),                      ,  Field 13: TRANS_LINES_USER_FIELD_4
  ',', variables('varEmployeeID'), '-', variables('varStockCode')        ,  Field 14: TRANS_LINES_USER_FIELD_6
)
```

> Note: Power Automate `concat()` does not accept inline comments — remove the comment text when entering in the portal. The layout above is for readability only.

**3.6 — Create file in SharePoint**
- Action: `Create file` (SharePoint connector)
- Site Address: *(SharePoint site URL — to be supplied)*
- Folder Path: *(target folder path — to be supplied)*
- File Name: output of step 3.4 (e.g. `STKTRAN_014_105676_2026-04-30.txt`)
- File Content: CSV string built in 3.5

> One `.txt` file is created per exported row. Content is CSV-formatted with no header row.

---

### Task 4 — Tick "Exported Transfer" in Smartsheet

After all CSV files are created, update Smartsheet to mark each exported row.

**4.1 — Build row update payload array**
Before or during the loop, collect all exported row IDs.

**4.2 — HTTP action: Batch update rows (single API call)**
- Method: `PUT`
- URI:
  ```
  https://api.smartsheet.com/2.0/sheets/5041000518995844/rows
  ```
- Headers:
  ```
  Authorization: Bearer @{variables('varAPIToken')}
  Content-Type: application/json
  ```
- Body: Array of all exported rows, each setting `Exported Transfer` to `true`:
  ```json
  [
    {
      "id": <row_id>,
      "cells": [
        {
          "columnId": 2388194816724868,
          "value": true
        }
      ]
    },
    ...
  ]
  ```

> Send all row updates in a **single PUT call** (the Smartsheet API accepts an array). Do not loop with one HTTP call per row — this avoids rate limiting (300 requests/minute limit).

---

### Task 5 — Send Teams Notifications

> **Message content for both notifications below must be defined and approved before this task is built.**
> Placeholders are shown. Replace with agreed wording during the build session.

All times in messages must use `varBrisbaneTime` (Brisbane local time, not UTC).

**5.1 — Condition: Only send notifications if varExportRows is not empty**
- Add a `Condition` check: `length(variables('varExportRows'))` is greater than `0`
- Only proceed with Teams notifications if true

**5.2 — Notification 1: Warehouse Team**
- Action: `Post message in a chat or channel` (Microsoft Teams connector)
- Team / Channel: *(Warehouse Teams channel — ID to be supplied at build time)*
- Message content: *(To be defined and approved at build time)*
- Must include: Brisbane timestamp from `varBrisbaneTime`, count of exported rows, list of files created

**5.3 — Notification 2: Per Post to Location store**

Each store should only receive details of their own orders.

- Use a `Select` action on `varExportRows` to extract all `Post to Location` values
- Use a `Union` expression to deduplicate: `@{union(variables('varLocationList'), variables('varLocationList'))}`
- Loop over unique locations with `Apply to each`
- For each location, filter `varExportRows` to rows matching that location
- Action: `Post message in a chat or channel`
- Team / Channel: *(Mapped from location code to Teams channel ID — mapping JSON to be supplied at build time)*
- Message content: *(To be defined and approved at build time)*
- Must include: Brisbane timestamp, store location name, list of employee names and items in the batch

---

## Recommended Claude Code Setup

This plan is intended to be executed using **Claude Code via the VS Code extension**, which is the recommended approach for someone already working with VS Code, Git, and GitLab.

### Installation
1. Open VS Code
2. Go to the Extensions marketplace and search for **Claude Code**
3. Install the Anthropic Claude Code extension
4. Authenticate with your Anthropic account when prompted
5. Claude Code will appear as a sidebar panel and inline within the editor

### GitLab Integration
1. Install the **GitLab plugin for Claude Code** from: `https://claude.com/plugins/gitlab`
2. Connect it to your GitLab instance (supports both GitLab.com and self-hosted)
3. Once connected, Claude Code can read issues, create merge requests, and view pipeline status directly from within the workflow

### Suggested Repo Structure
Create a GitLab repo for this project (e.g. `clothing-order-export`). Suggested structure:

```
clothing-order-export/
├── README.md
├── plan/
│   └── clothing_order_export_plan.md   ← this document
├── flow/
│   └── flow_definition.json            ← exported Power Automate flow (for version control)
├── csv/
│   └── csv_structure.md                ← CSV column definition (to be added)
└── teams/
    └── message_templates.md            ← Teams message content (to be added at build time)
```

### How to Work With Claude Code on This Project
- Open the repo folder in VS Code
- Use the Claude Code sidebar to give instructions — Claude Code will read, create, and edit files directly in your workspace
- Claude Code does **not** auto-commit or push — you retain full control over `git add`, `git commit`, and `git push` as normal
- Power Automate flows cannot be built directly by Claude Code (they live in the Power Automate portal), but Claude Code can generate the full flow logic as a documented step-by-step guide or exportable JSON that you apply manually in the portal
- Use GitLab to track versions of the plan, CSV structure, and any supporting scripts as they evolve

### Note on Power Automate and Claude Code
Claude Code cannot log into the Power Automate portal and click through the UI. What it **can** do is:
- Produce precise, step-by-step build instructions referencing exact connector names, action names, and expression syntax
- Generate any HTTP request bodies, JSON payloads, and Power Automate expressions needed
- Help debug expressions if something doesn't behave as expected
- Document the finished flow for the repo

You (or someone with portal access) will apply the steps in the Power Automate portal, using Claude Code's output as the guide.

---

## Notes for Claude Code

- **Timezone:** Brisbane is `E. Australia Standard Time` (UTC+10, no daylight saving). All displayed times must use `convertTimeZone(utcNow(), 'UTC', 'E. Australia Standard Time', ...)`. The Recurrence trigger must be set to **09:00 UTC** to fire at 7:00 PM Brisbane time.
- **One CSV per row:** Each qualifying Smartsheet row produces its own CSV file. Do not combine rows into a single file.
- **SharePoint output:** Use the SharePoint `Create file` connector action. Site URL and folder path will be supplied.
- **CSV structure:** Column definitions will be provided before Task 3 is built. Do not assume column content.
- **Smartsheet API token:** Do not hardcode. Use a Power Automate Connection reference or environment variable.
- **Cell value lookup:** Smartsheet rows return a `cells` array. Always locate cells by matching `columnId`, never by array position.
- **Batch Smartsheet updates:** Send all row tick-backs in a single PUT request (array body). One call, not one per row.
- **Teams message content:** Both notification messages (warehouse and per-location) are to be defined interactively during the build session. Build placeholder actions and pause for content to be supplied.
- **Teams channel mapping:** The location-to-channel mapping JSON will be supplied at build time. Build the lookup structure ready to receive it.
- **No-rows scenario:** If no rows qualify (Picked Quantity > 0 and not yet exported), the flow should exit gracefully without creating files or sending notifications.
- **Power Automate Premium:** Confirmed available. HTTP connector and SharePoint connector are both available.
- **Test first:** Before enabling the 7PM schedule, test manually with 1–2 rows to verify CSV creation, Smartsheet tick-back, and Teams messages.
