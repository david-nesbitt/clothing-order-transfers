# Teams Message Templates

## Message 1 — Warehouse Notification

**Destination:** Warehouse Team → General  
**Trigger:** Sent once per flow run, only if one or more rows were exported  
**Timing:** Immediately after all files are created (before per-store notifications)

### Content

```
Picked clothing orders have been exported as Transfers.

{varBrisbaneTime}  {n} transfer file(s)

{list of filenames, one per line}
```

### Example

```
Picked clothing orders have been exported as Transfers.

26/05/2026 19:00  3 transfer file(s)

STKTRAN_014_105676_2026-05-26.txt
STKTRAN_019_105234_2026-05-26.txt
STKTRAN_032_106891_2026-05-26.txt
```

### Power Automate Build Notes

- `{varBrisbaneTime}` → `@{variables('varBrisbaneTime')}` (format: dd/MM/yyyy HH:mm)
- `{n}` → `@{length(variables('varExportRows'))}` 
- Filename list → built during the export loop using `Append to string variable` into `varFileNameList`, one filename per line using `\n` as separator
- Post using: **Post message in a chat or channel** (Teams connector)
  - Post as: Flow bot (or your account)
  - Post in: Channel
  - Team: Warehouse Team
  - Channel: General

---

## Message 2 — Per-Store Notification

**Destination:** Store's own Teams channel (see `teams_mapping.md`)  
**Trigger:** One message per unique Post to Location, sent only for locations with an active channel  
**Skip if:** Location ID is 030, 033, or 045 (closed stores — file still exported, no message sent)  
**Route to Warehouse Team → General if:** Location ID is 001 or 002

### Content

```
The following clothing orders have been picked and will be delivered on your store's next pallet delivery:

{Employee Full Name} — {Shirt Size} × {Picked Quantity}
{Employee Full Name} — {Shirt Size} × {Picked Quantity}
...

Please make sure that once you receive them, you sell them to the employee via Point of Sale process as per the quantity and prices listed on the delivery note. All shirts MUST be purchased by the employee.
```

### Example

```
The following clothing orders have been picked and will be delivered on your store's next pallet delivery:

KINGSLY WESTON — S × 1
JANE SMITH — M × 2

Please make sure that once you receive them, you sell them to the employee via Point of Sale process as per the quantity and prices listed on the delivery note. All shirts MUST be purchased by the employee.
```

### Power Automate Build Notes

- Employee list → built during the per-location filter loop using `Append to string variable` into `varStoreOrderList`:
  ```
  @{toUpper(item()?['employeeFullName'])} — @{item()?['shirtSize']} × @{item()?['pickedQty']}
  ```
  with `\n` separator between entries
- Shirt Size display: show the size label only (e.g. `S`, `M`, `L`) — strip the `(code XXXXXXX)` suffix using:
  ```
  @{trim(first(split(variables('varShirtSize'), '(')))}
  ```
- Post using: **Post message in a chat or channel** (Teams connector)
  - Post as: Flow bot (or your account)
  - Post in: Channel
  - Team: dynamic — from location mapping
  - Channel: dynamic — from location mapping
