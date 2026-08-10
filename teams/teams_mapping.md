# Teams Channel Mapping

## Team Structure

| Teams Team | Purpose |
|---|---|
| **Region 1** | Store channels for Region 1 locations |
| **Region 2** | Store channels for Region 2 locations |
| **Region 3** | Store channels for Region 3 locations — formerly the "Toowoomba" team, renamed August 2026 (same groupId `8f5be748-f935-40a7-b3b5-87068317a39b`) |
| **Warehouse Team** | Warehouse notification (General channel) + catchall for 001, 002 |

> **Region 3 restructure (August 2026):** the Toowoomba team was renamed **Region 3**, a dedicated `031 Toowoomba` channel was created (031 previously posted to that team's General channel), and **022 Bribie Island** moved from Region 1 into Region 3 under a new `022 Bribie Island` channel. The original Region 1 channel for 022 is still active for historical purposes but no longer receives flow posts.

---

## Location → Team / Channel Mapping

| Location ID | Location Name | Teams Team | Channel | Notification |
|---|---|---|---|---|
| 001 | Warehouse Distribution Centre | Warehouse Team | General | ✅ Send |
| 002 | Support Office | Warehouse Team | General | ✅ Send |
| 012 | Bowen | Region 2 | 012 Bowen | ✅ Send |
| 014 | Blackwater | Region 1 | 014 Blackwater | ✅ Send |
| 017 | Mossman | Region 2 | 017 Mossman | ✅ Send |
| 018 | Hermit Park | Region 2 | 018 Hermit Park | ✅ Send |
| 019 | Inverell | Region 1 | 019 Inverell | ✅ Send |
| 021 | Brassall | Region 1 | 021 Brassall | ✅ Send |
| 022 | Bribie Island | Region 3 | 022 Bribie Island | ✅ Send |
| 023 | Moranbah | Region 1 | 023 Moranbah | ✅ Send |
| 026 | Innisfail | Region 2 | 026 Innisfail | ✅ Send |
| 027 | Tully | Region 2 | 027 Tully | ✅ Send |
| 028 | Ingham | Region 2 | 028 Ingham | ✅ Send |
| 029 | Woodlands | Region 2 | 029 Woodlands | ✅ Send |
| 030 | Charters Towers | — | — | ❌ No notification — store closed |
| 031 | Toowoomba | Region 3 | 031 Toowoomba | ✅ Send |
| 032 | Kingaroy | Region 1 | 032 Kingaroy | ✅ Send |
| 033 | Willows | — | — | ❌ No notification — store closed |
| 034 | Muswellbrook | Region 1 | 034 Muswellbrook | ✅ Send |
| 036 | Atherton | Region 2 | 036 Atherton | ✅ Send |
| 037 | Longreach | Region 1 | 037 Longreach | ✅ Send |
| 038 | Charleville | Region 1 | 038 Charleville | ✅ Send |
| 040 | Smithfield | Region 2 | 040 Smithfield | ✅ Send |
| 041 | Atherton Overflow | Region 2 | 041 Overflow Atherton | ✅ Send |
| 042 | Charters Towers Overflow | Region 2 | 042 Overflow Charters Towers | ✅ Send |
| 043 | Ayr | Region 2 | 043 Ayr | ✅ Send |
| 044 | Mareeba | Region 2 | 044 Mareeba | ✅ Send |
| 045 | Calliope | — | — | ❌ No notification — store closed |

> **Closed stores (030, 033, 045):** Transfer files are still exported and Smartsheet is ticked — the export process runs normally. Only the Teams notification is suppressed.
>
> **001 and 002:** These locations use the Warehouse Team → General channel for their per-store notification (same destination as the warehouse notification).

---

## Flow Logic for Notification Routing

In the per-store notification loop, before posting a message check:

```
If location ID is in [030, 033, 045] → skip, do not send
If location ID is in [001, 002] → post to Warehouse Team → General
Otherwise → look up team and channel from the mapping above
```

The Team IDs and Channel IDs are resolved at flow build time using the Power Automate Teams connector dropdowns. The logical names above are sufficient for planning — Power Automate stores the underlying IDs automatically when you select them.
