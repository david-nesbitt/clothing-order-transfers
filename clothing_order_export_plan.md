# Claude Code Plan: Clothing Order Export Automation
## Power Automate — Smartsheet to TXT via Scheduled Flow

---

## ⚡ Current Status — End of Session 27/05/2026

### What's built and working (v12)
| Item | Status |
|---|---|
| Importable Power Automate package | ✅ `flow/ClothingOrderExport_v12_TEST.zip` |
| Scheduled trigger — 08:30 UTC (6:30 PM Brisbane) | ✅ In definition |
| File creation — STKTRAN_*.txt → \\PPS2012\DataLoad\StkTrans | ✅ Tested and working |
| Smartsheet tick-back (Exported Transfer + Exported Date) | ✅ Tested and working |
| Teams warehouse notification (test → Feature Test Site → General) | ✅ Working |
| Teams per-store notification (test → Feature Test Site → General) | ✅ Working |
| Teams failure DM → DavidN@pricesplus.com.au | ✅ Tested and working |
| Live store channel routing (varStoreMapping lookup) | ✅ Architecture in place, partial mapping |
| varTestMode flag (true = all posts → Feature Test Site) | ✅ In place |
| Stock code + description in Teams message (bold) | ✅ Working |

### Flow state right now
- **Flow is TURNED OFF** in Power Automate (do not turn on until go-live checklist below is complete)
- **varTestMode = true** — all Teams posts still route to Feature Test Site → General
- **Filter = Picked Quantity equals 100** (test filter) — must be changed to `> 0` before backfill run
- **Package version:** v12 — `flow/ClothingOrderExport_v12_TEST.zip`

### varStoreMapping — mapped so far
| Store | Name | Mapped |
|---|---|---|
| 001 | Warehouse DC | ✅ Warehouse Team → General |
| 002 | Support Office | ✅ Warehouse Team → General |
| 014 | Blackwater | ✅ Region 1 |
| 023 | Moranbah | ✅ Region 1 |
| All others | — | ⬜ Falls back silently (no error, no post) |

---

## ⏭️ Next Steps — Resume Here

### Step 1 — Add varSilentMode (backfill option)
Add a new boolean variable `varSilentMode` to the flow:
- When **true**: exports files and ticks Smartsheet — **but skips all Teams notifications**
- When **false**: normal operation including all Teams messages

This is needed for the initial backfill of ~105 existing rows. The stores don't need Teams notifications for historical orders.

**Implementation:** Wrap the Teams notification block (Condition_TestMode_Warehouse + Apply_to_each_location) inside a `Condition_SilentMode` check:
- `Condition_SilentMode` = `@equals(variables('varSilentMode'), false)` → only post if NOT silent

Add `Initialize_varSilentMode` to the variable chain (after `Initialize_varStoreMapping`):
- Type: Boolean
- Default value: `true` (safe default — don't accidentally spam stores)

### Step 2 — Collect remaining store Teams channel URLs
Still need channel URLs for these stores (right-click channel in Teams → Get link to channel, paste URL here):

**Region 1** (groupId: `9328e896-1d30-44f9-acd9-7456f322d86b`):
- [ ] 019 Inverell
- [ ] 021 Brassall
- [ ] 022 Bribie Island
- [ ] 032 Kingaroy
- [ ] 034 Muswellbrook
- [ ] 037 Longreach
- [ ] 038 Charleville

**Region 2** (groupId: unknown — provide any one URL to get it):
- [ ] 012 Bowen
- [ ] 017 Mossman
- [ ] 018 Hermit Park
- [ ] 026 Innisfail
- [ ] 027 Tully
- [ ] 028 Ingham
- [ ] 029 Woodlands
- [ ] 036 Atherton
- [ ] 040 Smithfield
- [ ] 041 Atherton Overflow
- [ ] 042 Charters Towers Overflow
- [ ] 043 Ayr
- [ ] 044 Mareeba

**Toowoomba team** (separate team — General channel):
- [ ] 031 Toowoomba

Stores 030 (Charters Towers), 033 (Willows), 045 (Calliope) — **closed, no notification, no mapping needed.**

### Step 3 — Backfill run (all ~105 historic rows, no Teams messages)
Once varSilentMode is built and the filter is updated:

1. Import latest package
2. Edit flow → set `varSilentMode = true`
3. Edit flow → set filter from `equals(..., 100)` to `greater(..., 0)` *(or change Condition_Row_Qualifies expression)*
4. Run manually once
5. Confirm all files created in \\PPS2012\DataLoad\StkTrans
6. Confirm all ~105 rows ticked in Smartsheet (Exported Transfer ✅, Exported Date set)
7. Confirm NO Teams messages sent to any store channels

### Step 4 — Go-live
After backfill is confirmed and all store channel IDs are mapped:

1. Import final package with:
   - `varTestMode = false`
   - `varSilentMode = false`
   - Filter: `greater(Picked Quantity, 0)`
   - All store channels mapped in varStoreMapping
2. Paste real Smartsheet API token into `Initialize_varAPIToken`
3. **Turn the flow ON** (enable the scheduled trigger)
4. From this point: the flow runs daily at 6:30 PM Brisbane time — only new orders (not yet exported) trigger files + Smartsheet tick-back + Teams messages

---

## Context & Goal

Build a scheduled Power Automate flow that runs daily at 6:30 PM **Brisbane Time (AEST, UTC+10 = 08:30 UTC)**. It reads rows from the **Clothing Order Form** Smartsheet, exports qualifying rows — one TXT file per row — to `\\PPS2012\DataLoad\StkTrans` via On-premises Data Gateway on PP01-SV06, ticks the "Exported Transfer" checkbox on each processed row back in Smartsheet, and sends two Microsoft Teams notifications — one to the warehouse team and one per unique "Post to Location" store.

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
| Shirt Size | `2640527506755460` | PICKLIST | e.g. "M (code 9991003)" |
| Picked Date | `6046473727463300` | DATE | |
| Picked Quantity | `3794673913778052` | TEXT_NUMBER | **Export trigger: value > 0** |
| Exported Transfer | `2388194816724868` | CHECKBOX | **Ticked true after export** |
| Exported Date | `7514863571341188` | DATE | **Set to Brisbane date after export** |

### Stock Code Mapping
| Shirt Size | Stock Code | Description |
|---|---|---|
| XS | 9991001 | STAFF POLO SHIRT XS |
| S | 9991002 | STAFF POLO SHIRT SML |
| M | 9991003 | STAFF POLO SHIRT MED |
| L | 9991004 | STAFF POLO SHIRT LGE |
| XL | 9991005 | STAFF POLO SHIRT XL |
| XXL | 9991006 | STAFF POLO SHIRT XXL |
| XXXL | 9991007 | STAFF POLO SHIRT XXXL |

---

## Pre-requisites Checklist

| # | Item | Status |
|---|---|---|
| 1 | Smartsheet `Exported Transfer` column added (CHECKBOX, ID: `2388194816724868`) | ✅ Done |
| 2 | TXT file per row — column structure defined | ✅ Done |
| 3 | On-premises Data Gateway installed and registered on **PP01-SV06** | ✅ Done (v3000.318.9, May 2026) |
| 4 | UNC path confirmed: `\\PPS2012\DataLoad\StkTrans` | ✅ Done |
| 5 | Service account confirmed: reuse `PRICESPLUS\TenciaCheckSvc` | ✅ Done |
| 6 | File System connection created in Power Automate | ✅ Done — `\\PPS2012\DataLoad\StkTrans` connected |
| 7 | Smartsheet API token — stored in IT password manager only | ✅ Generated — **never commit to repo** |
| 8 | Teams: Warehouse Team → General | ✅ IDs in varStoreMapping (001, 002) |
| 9 | Teams: per-store channel mapping | ⚠️ Partial — 014 and 023 done, rest outstanding (see Step 2 above) |
| 10 | Teams message content | ✅ Done |
| 11 | Power Automate Premium licence | ✅ Confirmed |
| 12 | Flow package importable and tested | ✅ v12 |

---

## Flow Package Files

```
flow/
├── ClothingOrderExport_v12_TEST.zip          ← Current — import this
├── package/
│   ├── manifest.json
│   └── Microsoft.Flow/flows/
│       ├── manifest.json
│       └── a7c3d852-e14f-4b89-9f2a-63c8e5d10b47/
│           ├── definition.json               ← Source of truth — edit this, re-zip
│           ├── apisMap.json
│           └── connectionsMap.json
```

**To rebuild the zip after editing definition.json:**
```powershell
$pkg = "c:\GitProjects\Clothing Order Transfers\flow\package"
$out = "c:\GitProjects\Clothing Order Transfers\flow\ClothingOrderExport_vXX_TEST.zip"
Compress-Archive -Path "$pkg\*" -DestinationPath $out -CompressionLevel Optimal
```

---

## Key Flow Variables

| Variable | Type | Current Value | Purpose |
|---|---|---|---|
| varSheetId | String | `5041000518995844` | Smartsheet sheet ID |
| varAPIToken | String | `PASTE_SMARTSHEET_API_TOKEN_HERE` | **Paste from password manager — never commit** |
| varExportedColumnId | String | `2388194816724868` | Exported Transfer column |
| varExportedDateColumnId | String | `7514863571341188` | Exported Date column |
| varExportRows | Array | `[]` | Accumulates exported row data |
| varBrisbaneTime | String | `convertTimeZone(...)` | Display time in messages |
| varBrisbaneDate | String | `convertTimeZone(...)` | Date for Smartsheet tick-back |
| varTimestamp | String | `convertTimeZone(...)` | Filename timestamp |
| varTestMode | Boolean | `true` | **false at go-live** — redirects all posts to Feature Test Site |
| varSilentMode | Boolean | *(to be added)* | **true for backfill** — exports files/ticks Smartsheet but skips Teams posts |
| varFileNameList | String | `''` | Accumulates filenames for warehouse message |
| varRowUpdates | Array | `[]` | Batch Smartsheet row updates |
| varStoreMapping | Object | See below | Store ID → Teams groupId/channelId lookup |

### varStoreMapping current value
```json
{
  "001": { "groupId": "e8132bda-7152-45df-b1ca-de0f52a41977", "channelId": "19:7q7EU6zu9oaE54aW9AEnW8xrHSYCq_zDoWXqHyig2_k1@thread.tacv2" },
  "002": { "groupId": "e8132bda-7152-45df-b1ca-de0f52a41977", "channelId": "19:7q7EU6zu9oaE54aW9AEnW8xrHSYCq_zDoWXqHyig2_k1@thread.tacv2" },
  "014": { "groupId": "9328e896-1d30-44f9-acd9-7456f322d86b", "channelId": "19:80af764441164fc687c52770e7f57799@thread.tacv2" },
  "023": { "groupId": "9328e896-1d30-44f9-acd9-7456f322d86b", "channelId": "19:2af021222450490885c65e319e85c6f5@thread.tacv2" }
}
```
Region 1 groupId: `9328e896-1d30-44f9-acd9-7456f322d86b`
Warehouse Team groupId: `e8132bda-7152-45df-b1ca-de0f52a41977`
Region 2 groupId: *(unknown — provide any Region 2 channel URL to get it)*
Toowoomba team groupId: *(unknown — provide Toowoomba → General URL)*

---

## Teams Channel Mapping (Full)

See `teams/teams_mapping.md` for logical mapping.

| Location ID | Location Name | Teams Team | Channel | Notification |
|---|---|---|---|---|
| 001 | Warehouse Distribution Centre | Warehouse Team | General | ✅ Mapped |
| 002 | Support Office | Warehouse Team | General | ✅ Mapped |
| 012 | Bowen | Region 2 | 012 Bowen | ⬜ Need URL |
| 014 | Blackwater | Region 1 | 014 Blackwater | ✅ Mapped |
| 017 | Mossman | Region 2 | 017 Mossman | ⬜ Need URL |
| 018 | Hermit Park | Region 2 | 018 Hermit Park | ⬜ Need URL |
| 019 | Inverell | Region 1 | 019 Inverell | ⬜ Need URL |
| 021 | Brassall | Region 1 | 021 Brassall | ⬜ Need URL |
| 022 | Bribie Island | Region 1 | 022 Bribie Island | ⬜ Need URL |
| 023 | Moranbah | Region 1 | 023 Moranbah | ✅ Mapped |
| 026 | Innisfail | Region 2 | 026 Innisfail | ⬜ Need URL |
| 027 | Tully | Region 2 | 027 Tully | ⬜ Need URL |
| 028 | Ingham | Region 2 | 028 Ingham | ⬜ Need URL |
| 029 | Woodlands | Region 2 | 029 Woodlands | ⬜ Need URL |
| 030 | Charters Towers | — | — | ❌ Closed — no notification |
| 031 | Toowoomba | Toowoomba | General | ⬜ Need URL |
| 032 | Kingaroy | Region 1 | 032 Kingaroy | ⬜ Need URL |
| 033 | Willows | — | — | ❌ Closed — no notification |
| 034 | Muswellbrook | Region 1 | 034 Muswellbrook | ⬜ Need URL |
| 036 | Atherton | Region 2 | 036 Atherton | ⬜ Need URL |
| 037 | Longreach | Region 1 | 037 Longreach | ⬜ Need URL |
| 038 | Charleville | Region 1 | 038 Charleville | ⬜ Need URL |
| 040 | Smithfield | Region 2 | 040 Smithfield | ⬜ Need URL |
| 041 | Atherton Overflow | Region 2 | 041 Overflow Atherton | ⬜ Need URL |
| 042 | Charters Towers Overflow | Region 2 | 042 Overflow Charters Towers | ⬜ Need URL |
| 043 | Ayr | Region 2 | 043 Ayr | ⬜ Need URL |
| 044 | Mareeba | Region 2 | 044 Mareeba | ⬜ Need URL |
| 045 | Calliope | — | — | ❌ Closed — no notification |

---

## Key Technical Notes

- **Timezone:** Brisbane = `E. Australia Standard Time` (UTC+10, no DST). Trigger = 08:30 UTC.
- **Cell lookup:** Always match by `columnId` — never by array position. Use `Query` (Filter Array) action.
- **Batch Smartsheet update:** Single PUT call with array body — not one call per row.
- **File connector:** File System connector (not SharePoint). Root `/` maps to `\\PPS2012\DataLoad\StkTrans`.
- **Teams DM (failure):** Uses `body/recipient` (not `body/recipient/to`) — confirmed from working flow in this tenant.
- **Channel posts:** Use `body/recipient/groupId` + `body/recipient/channelId`.
- **newline in PA expressions:** Use `decodeUriComponent('%0A')` — `\n` is literal backslash-n in PA.
- **Smartsheet API token:** Paste manually into `Initialize_varAPIToken` after import — never store in repo or files.
- **Test rows:** Rows 105630 and 105676 have been used for testing. Un-tick Exported Transfer + clear Exported Date to re-test.
