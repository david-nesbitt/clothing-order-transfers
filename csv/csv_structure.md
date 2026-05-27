# CSV Output File Structure

## File Naming

```
STKTRAN_{Post to Location ID}_{Employee ID}_{Picked Date YYYY-MM-DD}.txt
```

**Example:** `STKTRAN_014_105676_2026-04-30.txt`

> Extension is `.txt` — the content is comma-separated (CSV format) but the receiving system expects `.txt`.

Power Automate filename expression:
```
concat('STKTRAN_', <PostToLocationID>, '_', <EmployeeID>, '_', formatDateTime(<PickedDate>, 'yyyy-MM-dd'), '.txt')
```

---

## File Content

- **No header row** — data row only, one row per file
- One file per qualifying Smartsheet row
- 14 comma-separated fields

### Column Definitions

| # | CSV Field | Source | Power Automate Expression |
|---|---|---|---|
| 1 | DOC_HEADS_REFERENCE_NBR | Always empty | `''` |
| 2 | DOC_HEADS_TRANS_DATE | {Picked Date} — DD/MM/YYYY | `formatDateTime(<PickedDate>, 'dd/MM/yyyy')` |
| 3 | DOC_HEADS_DETAIL | {Employee ID} + space + "CLOTHING ORDER" | `concat(<EmployeeID>, ' CLOTHING ORDER')` |
| 4 | TRANS_LINES_LINE_TYPE | Always `S` (static) | `'S'` |
| 5 | DOC_HEADS_STOCK_LOCATION | Always `001` (Warehouse — static) | `'001'` |
| 6 | TRANS_LINES_STOCK_LOCATION | {Post to Location ID} — 3 digits, leading zero preserved | `<PostToLocationID>` |
| 7 | TRANS_LINES_STOCK_CODE | Derived from {Shirt Size} — see lookup below | See stock code lookup |
| 8 | TRANS_LINES_DESCRIPTION | {Employee ID} + space + {Employee Full Name} in UPPERCASE | `concat(<EmployeeID>, ' ', toUpper(<EmployeeFullName>))` |
| 9 | TRANS_LINES_ENTERED_QTY | {Picked Quantity} | `<PickedQuantity>` |
| 10 | TRANS_LINES_USER_FIELD_1 | {Employee ID} | `<EmployeeID>` |
| 11 | TRANS_LINES_USER_FIELD_2 | Always `SHIRT ORDER` (static) | `'SHIRT ORDER'` |
| 12 | TRANS_LINES_USER_FIELD_3 | {Picked Date} — DD/MM/YYYY | `formatDateTime(<PickedDate>, 'dd/MM/yyyy')` |
| 13 | TRANS_LINES_USER_FIELD_4 | {Created Date} — DD/MM/YYYY | `formatDateTime(<CreatedDate>, 'dd/MM/yyyy')` |
| 14 | TRANS_LINES_USER_FIELD_6 | {Employee ID} + "-" + {Stock Code} | `concat(<EmployeeID>, '-', <StockCode>)` |

> Note: There is no USER_FIELD_5 — the numbering skips from 4 to 6. This matches the receiving system's field layout.

### Example Output

```
,30/04/2026,105676 CLOTHING ORDER,S,001,014,9991002,105767 KINGSLY WESTON,1,105676,SHIRT ORDER,30/04/2026,30/04/2026,105676-9991002
```

---

## Stock Code Lookup (from Shirt Size)

The Smartsheet `Shirt Size` column stores values in the format `{Size} (code {STOCK_CODE})` e.g. `S (code 9991002)`.

### Option A — Parse the code from the value (recommended)
Extract the 7-digit code directly from the Smartsheet cell value using:
```
substring(variables('varShirtSize'), add(indexOf(variables('varShirtSize'), 'code '), 5), 7)
```

### Option B — Switch lookup table

| Shirt Size value | Stock Code | Description |
|---|---|---|
| XS (code 9991001) | 9991001 | STAFF POLO SHIRT XS |
| S (code 9991002) | 9991002 | STAFF POLO SHIRT SML |
| M (code 9991003) | 9991003 | STAFF POLO SHIRT MED |
| L (code 9991004) | 9991004 | STAFF POLO SHIRT LGE |
| XL (code 9991005) | 9991005 | STAFF POLO SHIRT XL |
| XXL (code 9991006) | 9991006 | STAFF POLO SHIRT XXL |
| XXXL (code 9991007) | 9991007 | STAFF POLO SHIRT XXXL |

Option A is preferred — it doesn't require a Switch action and automatically handles any future size additions.

---

## Smartsheet Column ID Reference (for cell lookups)

Power Automate cell value lookup pattern:
```
@{first(filter(item()?['cells'], equals(string(item()?['columnId']), '<COLUMN_ID>')))?['value']}
```

| Field needed | Smartsheet Column | Column ID |
|---|---|---|
| Employee ID | Employee ID | `8551502017679236` |
| Employee Full Name | Employee Full Name | `388727693070212` |
| Post to Location ID | Post to Location ID | `1533107887886212` |
| Shirt Size | Shirt Size | `2640527506755460` |
| Picked Quantity | Picked Quantity | `3794673913778052` |
| Picked Date | Picked Date | `6046473727463300` |
| Created Date | Created Date | `2863694728875908` |
| Exported Date | Exported Date | `7514863571341188` | Set to Brisbane date at export time (yyyy-MM-dd) |

---

## Post to Location ID → Location Name

Used for `TRANS_LINES_STOCK_LOCATION` and Teams notification routing.

| ID | Location Name |
|---|---|
| 001 | Warehouse Distribution Centre |
| 002 | Support Office |
| 012 | Bowen |
| 014 | Blackwater |
| 017 | Mossman |
| 018 | Hermit Park |
| 019 | Inverell |
| 021 | Brassall |
| 022 | Bribie Island |
| 023 | Moranbah |
| 026 | Innisfail |
| 027 | Tully |
| 028 | Ingham |
| 029 | Woodlands |
| 030 | Charters Towers |
| 031 | Toowoomba |
| 032 | Kingaroy |
| 033 | Willows |
| 034 | Muswellbrook |
| 036 | Atherton |
| 037 | Longreach |
| 038 | Charleville |
| 040 | Smithfield |
| 041 | Atherton Overflow |
| 042 | Charters Towers Overflow |
| 043 | Ayr |
| 044 | Mareeba |
| 045 | Calliope |
