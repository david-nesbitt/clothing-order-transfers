# Plan: Shirt Returns Export — Store → Warehouse

## ✅ LIVE — 29/05/2026

Flow is on and running daily at 6:45 PM Brisbane. Updated with transfer numbers and new filename format to match the order export pattern.

**Latest live export:** `flow/ClothingReturnExportLIVEVERSION_20260529035627.zip`

### Final file format (post-29/05/2026 update)
**Filename:** `STKTRAN_{transferNum}_{StoreID}-001_{yyyyMMdd}_{employeeId}_SHIRT_RETURN.txt`
**CSV row:**
```
{transferNum},{DateReturned dd/MM/yyyy},{EmpID}-STAFF SHIRT RETURN,S,{StoreID},001,{StockCode},{EmpID} {EMP NAME},{QtyReturned},{EmpID},SHIRT RETURNED,{DateReturned dd/MM/yyyy},{DateReturned dd/MM/yyyy},{StoreID}-{StockCode}
```
Note Field 3 is `STAFF SHIRT RETURN` (no D); Field 11 is `SHIRT RETURNED` (with D) — intentional.

### Transfer number
Same as order export — `PP.dbo.sproc_Next_Stocktrans_number` via SQL Server connector through PP01-SV06 gateway.

---

## Original plan

## Overview

When a store sends shirts back to warehouse 001, warehouse staff fill in 5 new Smartsheet columns on the original order row. A new Power Automate flow runs at **6:45 PM Brisbane** each evening, picks up any rows ready for return export, writes a STKTRAN_*.txt file per row to `\\PPS2012\DataLoad\StkTrans`, ticks the row back in Smartsheet, and posts one summary message to the Warehouse Team channel.

The existing ClothingOrderExport flow is **not touched** — this is a completely separate flow.

---

## Step 1 — Smartsheet: Add 5 Columns

Add the following 5 columns to the **Clothing Order Form** sheet (`5041000518995844`), positioned after the existing `Exported Date` column.

| # | Column Title | Type | Index | Column ID | Purpose |
|---|---|---|---|---|---|
| 1 | **Returning** | CHECKBOX | 18 | `8475089208381316` | Warehouse ticks when shirts received back |
| 2 | **Date Returned** | DATE | 19 | `312314883772292` | Date shirts arrived back at warehouse 001 |
| 3 | **Quantity Returned** | TEXT_NUMBER | 20 | `4815914511142788` | How many shirts are being returned |
| 4 | **Returned Exported Date** | DATE | 21 | `2564114697457540` | Set by flow after export — do not edit manually |
| 5 | **Returned Exported** | CHECKBOX | 22 | `7067714324828036` | Ticked by flow after export — do not edit manually |

**Columns added to Smartsheet on 2026-05-28. ✅**

> **Workflow for warehouse staff:** When shirts come back, find the original row for that employee + shirt size, tick **Returning**, fill in **Date Returned** and **Quantity Returned**. Leave the last two columns alone — the flow sets them.

---

## Step 2 — New Power Automate Flow: ClothingReturnExport

### Trigger
- **Recurrence** — 08:45 UTC = **6:45 PM Brisbane** (`E. Australia Standard Time`)
- Runs every day

### Variables
| Variable | Type | Value | Purpose |
|---|---|---|---|
| varSheetId | String | `5041000518995844` | Same sheet |
| varAPIToken | String | *(paste from password manager)* | Smartsheet API token |
| varReturningColId | String | `8475089208381316` | Returning checkbox |
| varDateReturnedColId | String | `312314883772292` | Date Returned |
| varQtyReturnedColId | String | `4815914511142788` | Quantity Returned |
| varReturnedExportedDateColId | String | `2564114697457540` | Returned Exported Date |
| varReturnedExportedColId | String | `7067714324828036` | Returned Exported checkbox |
| varBrisbaneTime | String | `convertTimeZone(...)` | Display in Teams message |
| varBrisbaneDate | String | `convertTimeZone(...)` | Written to Returned Exported Date |
| varTimestamp | String | `convertTimeZone(...)` | Filename timestamp |
| varFileNameList | String | `''` | Accumulates filenames for summary message |
| varRowUpdates | Array | `[]` | Batch Smartsheet tick-back payload |
| varReturnRows | Array | `[]` | Count of processed rows |
| varTestMode | Boolean | `true` → `false` at go-live | Redirects Teams posts to test channel |

### Flow steps

1. **Initialize variables** (same pattern as existing flow)
2. **Get Smartsheet** — GET `/sheets/{varSheetId}?includeAll=true`
3. **Parse response**
4. **Apply to each row** — filter: `Returning == true AND DateReturned is not empty AND QtyReturned > 0 AND ReturnedExported != true`
   - For each qualifying row:
     - Extract cells: Post to Location ID, Employee ID, Employee Full Name, Shirt Size, Date Returned, Quantity Returned
     - Derive stock code from Shirt Size (same mapping as existing flow)
     - Compose file name (see below)
     - Compose file content (see below)
     - **Create file** in `\\PPS2012\DataLoad\StkTrans`
     - Append filename to `varFileNameList`
     - Build row update (Returned Exported = true, Returned Exported Date = varBrisbaneDate)
     - Append row update to `varRowUpdates`
5. **Condition** — if `varRowUpdates` is not empty:
   - **Batch Smartsheet PUT** — tick all processed rows
   - **Teams message** → Warehouse Team → General (see below)
6. (Optionally) **Failure DM** to DavidN@pricesplus.com.au if flow errors

---

## TXT File Format — Returns Direction

### Existing to-store format (for reference)
```
,[PickedDate dd/MM/yyyy],STAFF SHIRT ORDER,S,001,{StoreID},{StockCode},{EmpID} {EMP NAME},{PickedQty},{EmpID},SHIRT ORDER,[PickedDate dd/MM/yyyy],[CreatedDate dd/MM/yyyy],[EmpID]-{StockCode}
```
- Field 5 = `001` (FROM — warehouse)
- Field 6 = `{StoreID}` (TO — store)

### Returns format — fields that change
| Field | Tencia field | To-store | Return |
|---|---|---|---|
| Field 2 (date) | — | Picked Date | **Date Returned** |
| Field 3 (description) | `DOC_HEADS_DETAIL` | `STAFF SHIRT ORDER` | **`STAFF SHIRT RETURNED`** |
| Field 5 (FROM) | — | `001` | **`{StoreID}`** |
| Field 6 (TO) | — | `{StoreID}` | **`001`** |
| Field 9 (quantity) | — | Picked Qty | **Quantity Returned** |
| Field 11 (short desc) | `TRANS_LINES_USER_FIELD_2` | `SHIRT ORDER` | **`SHIRT RETURNED`** |
| Field 12 | `TRANS_LINES_USER_FIELD_3` | Picked Date | **Date Returned** |
| Field 13 | `TRANS_LINES_USER_FIELD_4` | Created Date | **Date Returned** |
| Field 14 (reference) | `TRANS_LINES_USER_FIELD_6` | `{EmpID}-{StockCode}` | **`{StoreID}-{StockCode}`** |

### Returns format full line ✅ CONFIRMED
```
,[DateReturned dd/MM/yyyy],STAFF SHIRT RETURNED,S,{StoreID},001,{StockCode},{EmpID} {EMP NAME},{QtyReturned},{EmpID},SHIRT RETURNED,[DateReturned dd/MM/yyyy],[DateReturned dd/MM/yyyy],[StoreID]-{StockCode}
```

---

## Filename Format

```
STKTRAN_{StoreID}_{EmployeeID}_{DateReturned yyyy-MM-dd}.txt
```

Example: `STKTRAN_018_12345_2026-05-28.txt`

Same naming convention as existing flow, same destination folder.

---

## Teams Notification — Warehouse Team Only

Returns are received at the warehouse — only the Warehouse Team needs to know. No per-store notifications.

**Channel:** Warehouse Team → General  
`groupId: e8132bda-7152-45df-b1ca-de0f52a41977`  
`channelId: 19:7q7EU6zu9oaE54aW9AEnW8xrHSYCq_zDoWXqHyig2_k1@thread.tacv2`

**Message format:**
```
Returned clothing items have been exported as Return Transfers.
{BrisbaneTime} — {count} return transfer file(s)

{filename1}
{filename2}
...
```

---

## Filter Logic (in flow expression)

For a row to qualify for return export, ALL of the following must be true:
1. `Returning` = `true`
2. `Date Returned` is not empty / not null
3. `Quantity Returned` > 0
4. `Returned Exported` ≠ `true` (prevents double-export)

PA expression (draft — adjust column IDs after Step 1):
```
and(
  equals(coalesce(first(body('Get_Returning_Cell'))?['value'], false), true),
  not(empty(string(coalesce(first(body('Get_DateReturned_Cell'))?['value'], '')))),
  greater(int(coalesce(string(first(body('Get_QtyReturned_Cell'))?['value']), '0')), 0),
  not(equals(coalesce(first(body('Get_ReturnedExported_Cell'))?['value'], false), true))
)
```

---

## Confirmed Design Decisions

| # | Question | Answer |
|---|---|---|
| 1 | Transaction descriptions | `STAFF SHIRT RETURNED` (DOC_HEADS_DETAIL) and `SHIRT RETURNED` (USER_FIELD_2) ✅ |
| 2 | Partial returns | Yes — Quantity Returned can be less than Picked Quantity ✅ |
| 3 | Multiple returns on one row | Manual workaround if it happens — not handled in flow ✅ |
| 4 | varTestMode | Yes — same pattern, Teams posts → Feature Test Site when true ✅ |

---

## Build Order

| # | Step | Notes |
|---|---|---|
| 1 | ~~Add 5 columns to Smartsheet~~ | ✅ Done 2026-05-28 — column IDs recorded above |
| 2 | Build flow definition.json from scratch (based on existing flow pattern) | New flow GUID, new flow name |
| 3 | Test in varTestMode with a real row that has the new columns filled | Confirm file created, Smartsheet ticked, Teams message in test channel |
| 4 | Go-live — varTestMode = false, turn flow ON | |

---

## Key Differences from Existing Flow

| Concern | ClothingOrderExport | ClothingReturnExport |
|---|---|---|
| Trigger time | 08:30 UTC (6:30 PM) | **08:45 UTC (6:45 PM)** |
| Direction | Warehouse → Store | **Store → Warehouse** |
| Qty field | Picked Quantity | **Quantity Returned** |
| Date field | Picked Date | **Date Returned** |
| FROM field in file | `001` | **{StoreID}** |
| TO field in file | {StoreID} | **`001`** |
| Teams notifications | Warehouse + per-store | **Warehouse Team only** |
| Tick-back columns | Exported Transfer, Exported Date | **Returned Exported, Returned Exported Date** |
| Filter trigger columns | Returning (new), Date Returned (new), Qty Returned (new) | — |
