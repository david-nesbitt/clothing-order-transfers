<#
.SYNOPSIS
    Generates an Excel workbook: shirt on-hand pivot + per-store transfer/purchase/outstanding detail.
.OUTPUTS
    ShirtReport_<yyyyMMdd>.xlsx saved next to this script.
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Data

# Location name lookup
$locationNames = @{
    '001'='Warehouse DC';    '002'='Support Office';  '012'='Bowen'
    '014'='Blackwater';      '017'='Mossman';         '018'='Hermit Park'
    '019'='Inverell';        '021'='Brassall';        '022'='Bribie Island'
    '023'='Moranbah';        '026'='Innisfail';       '027'='Tully'
    '028'='Ingham';          '029'='Woodlands';       '030'='Charters Towers'
    '031'='Toowoomba';       '032'='Kingaroy';        '033'='Willows'
    '034'='Muswellbrook';    '036'='Atherton';        '037'='Longreach'
    '038'='Charleville';     '040'='Smithfield';      '041'='Atherton Overflow'
    '042'='CT Overflow';     '043'='Ayr';             '044'='Mareeba'
    '045'='Calliope'
}

$shirtCodes   = @('9991001','9991002','9991003','9991004','9991005','9991006','9991007')
$shirtSizeMap = @{
    '9991001'='XS'; '9991002'='S'; '9991003'='M'; '9991004'='L'
    '9991005'='XL'; '9991006'='XXL'; '9991007'='XXXL'
}

function locLabel($code)  { if ($locationNames[$code]) { "$code  $($locationNames[$code])" } else { $code } }
function sizeLabel($code) { if ($shirtSizeMap[$code])  { $shirtSizeMap[$code] }              else { $code } }

# Excel OLE colour from R,G,B
function rgb($r,$g,$b) { $r + ($g * 256) + ($b * 65536) }

# Safe numeric value for Excel COM (Decimal from DataTable doesn't marshal directly)
function n($v) { [System.Convert]::ToDouble($v) }

# Set a numeric cell value — uses Formula= (string property) to avoid PS5.1 COM dispatch issue
# with Value2 when the worksheet is passed as a function parameter.
function setNum($ws, $r, $c, $v) {
    $ws.Cells.Item($r, $c).Formula = "$([System.Convert]::ToDouble($v))"
}

# ---------------------------------------------------------------
# SQL QUERIES
# ---------------------------------------------------------------
$connStr = "Server=PP01-SV10;Database=OceanicSquare;Integrated Security=True;TrustServerCertificate=True"
$conn    = New-Object System.Data.SqlClient.SqlConnection($connStr)
$conn.Open()
Write-Host "Connected to OceanicSquare"

function qry($sql) {
    $cmd = New-Object System.Data.SqlClient.SqlCommand($sql, $conn)
    $da  = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt  = New-Object System.Data.DataTable
    $da.Fill($dt) | Out-Null
    $dt
}

$dtOnHand = qry @"
SELECT m.STOCK_CODE, m.STOCK_LOCATION, m.ON_HAND_QTY
FROM   dbo.STK_LOCN_MASTER m
WHERE  m.STOCK_CODE LIKE '999100%' AND m.COMPANY_CODE = 'OS' AND m.ON_HAND_QTY <> 0
ORDER  BY m.STOCK_LOCATION, m.STOCK_CODE
"@

$dtXfer = qry @"
SELECT
    st.STOCK_LOCATION   AS STORE,
    st.DESCRIPTION      AS EMPLOYEE,
    st.USER_FIELD_3     AS PICKED_DATE,
    st.STOCK_CODE,
    st.ENTERED_QTY      AS QTY
FROM dbo.STK_TRANS st
WHERE st.TRANS_TYPE   = 'STTRF'
  AND st.USER_FIELD_2 = 'SHIRT ORDER'
  AND st.STOCK_CODE  LIKE '999100%'
  AND st.COMPANY_CODE = 'OS'
  AND st.ENTERED_QTY  > 0
ORDER BY st.STOCK_LOCATION, st.USER_FIELD_3, st.DESCRIPTION
"@

$dtSales = qry @"
SELECT
    st.STOCK_LOCATION              AS STORE,
    st.REFERENCE_NBR               AS DRINV_REF,
    CONVERT(date, st.TRANS_DATE)   AS SALE_DATE,
    st.STOCK_CODE,
    ABS(st.ENTERED_QTY)            AS QTY
FROM dbo.STK_TRANS st
WHERE st.TRANS_TYPE  = 'DRINV'
  AND st.STOCK_CODE LIKE '999100%'
  AND st.COMPANY_CODE = 'OS'
  AND CONVERT(date, st.TRANS_DATE) >= (
      SELECT MIN(CONVERT(date, t.TRANS_DATE))
      FROM   dbo.STK_TRANS t
      WHERE  t.TRANS_TYPE   = 'STTRF'
        AND  t.USER_FIELD_2 = 'SHIRT ORDER'
        AND  t.STOCK_CODE   = st.STOCK_CODE
        AND  t.STOCK_LOCATION = st.STOCK_LOCATION
        AND  t.COMPANY_CODE = 'OS'
        AND  t.ENTERED_QTY  > 0
  )
ORDER BY st.STOCK_LOCATION, CONVERT(date, st.TRANS_DATE)
"@

$conn.Close()
Write-Host ("Loaded: {0} on-hand, {1} transfers, {2} DRINV sales" -f $dtOnHand.Rows.Count, $dtXfer.Rows.Count, $dtSales.Rows.Count)

# ---------------------------------------------------------------
# PRE-COMPUTE OUTSTANDING MAP (store+code -> outstanding qty)
# ---------------------------------------------------------------
$outstandingMap = @{}
$allXferStores = @($dtXfer | ForEach-Object { $_.STORE } | Sort-Object -Unique)
foreach ($st in $allXferStores) {
    $stX = @($dtXfer  | Where-Object { $_.STORE -eq $st })
    $stS = @($dtSales | Where-Object { $_.STORE -eq $st })
    $stCodes = (($stX | ForEach-Object { $_.STOCK_CODE }) + ($stS | ForEach-Object { $_.STOCK_CODE })) | Sort-Object -Unique
    foreach ($cd in $stCodes) {
        $cX = @($stX | Where-Object { $_.STOCK_CODE -eq $cd })
        $cS = @($stS | Where-Object { $_.STOCK_CODE -eq $cd })
        $xT = if ($cX.Count) { n (($cX | Measure-Object -Property QTY -Sum).Sum) } else { 0.0 }
        $sT = if ($cS.Count) { n (($cS | Measure-Object -Property QTY -Sum).Sum) } else { 0.0 }
        $outstandingMap["${st}|${cd}"] = $xT - $sT
    }
}

function getOutstanding($store, $code) {
    $key = "${store}|${code}"
    if ($outstandingMap.ContainsKey($key)) { $outstandingMap[$key] } else { 0.0 }
}

function getOnHand($loc, $code) {
    $m = @($dtOnHand | Where-Object { $_.STOCK_LOCATION -eq $loc -and $_.STOCK_CODE -eq $code })
    if ($m.Count) { n $m[0].ON_HAND_QTY } else { 0.0 }
}

function getEmployees($store, $code) {
    $rows = @($dtXfer | Where-Object { $_.STORE -eq $store -and $_.STOCK_CODE -eq $code })
    ($rows | ForEach-Object { $_.EMPLOYEE }) -join ', '
}

# ---------------------------------------------------------------
# EXCEL SETUP
# ---------------------------------------------------------------
$outFile = Join-Path (Split-Path $PSCommandPath) ("ShirtReport_{0}.xlsx" -f (Get-Date -Format 'yyyyMMdd'))
$xl  = New-Object -ComObject Excel.Application
$xl.Visible       = $false
$xl.DisplayAlerts = $false
$wb  = $xl.Workbooks.Add()

while ($wb.Worksheets.Count -gt 1) { $wb.Worksheets.Item($wb.Worksheets.Count).Delete() }
$ws1 = $wb.Worksheets.Item(1); $ws1.Name = "On Hand"
$ws2 = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $ws1); $ws2.Name = "Store Detail"
$ws3 = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $ws2); $ws3.Name = "Outstanding"

# Colour palette
$cBlueHdr  = rgb 68  114 196   # main header blue
$cBlueSub  = rgb 189 215 238   # store section header light blue
$cAmberHdr = rgb 197  90  17   # outstanding header dark orange
$cAmberLt  = rgb 255 230 153   # outstanding column fill light amber
$cGray     = rgb 242 242 242   # alternating row
$cGreen    = rgb 198 239 206   # purchase / fully paid
$cRed      = rgb 255 199 206   # outstanding > 0
$cWhite    = rgb 255 255 255

$today = Get-Date -Format 'dd/MM/yyyy'

# ---------------------------------------------------------------
# SHEET 1 - ON HAND PIVOT  (with Outstanding columns)
# ---------------------------------------------------------------
Write-Host "Building 'On Hand' sheet..."

$nCodes    = $shirtCodes.Count   # 7
# Column layout:
#   1          = Location
#   2..(n+1)   = On Hand per size  (cols 2-8)
#   n+2        = Total On Hand     (col 9)
#   n+3        = separator         (col 10)
#   n+4..(2n+3)= Outstanding per size (cols 11-17)
#   2n+4       = Total Outstanding (col 18)
$sepCol    = $nCodes + 3          # 10
$outStart  = $nCodes + 4          # 11
$outEnd    = 2 * $nCodes + 3      # 17
$outTotal  = 2 * $nCodes + 4      # 18
$totalCols = $outTotal            # 18

# Title row 1 — merged across all columns
$ws1.Cells(1,1).Value2 = "Shirt Stock On Hand and Outstanding - $today"
$ws1.Range($ws1.Cells(1,1), $ws1.Cells(1, $totalCols)).Merge() | Out-Null
$ws1.Cells(1,1).Font.Bold = $true
$ws1.Cells(1,1).Font.Size = 13

# Row 2 - On Hand size labels
$ws1.Cells(2,1).Value2 = "Location"
for ($c = 0; $c -lt $nCodes; $c++) {
    $cell = $ws1.Cells(2, $c+2)
    $cell.Value2 = $shirtSizeMap[$shirtCodes[$c]]
    $cell.HorizontalAlignment = -4108
}
$ws1.Cells(2, $nCodes+2).Value2 = "Total On Hand"

# Row 2 - Outstanding size labels
for ($c = 0; $c -lt $nCodes; $c++) {
    $cell = $ws1.Cells(2, $outStart + $c)
    $cell.Value2 = $shirtSizeMap[$shirtCodes[$c]]
    $cell.HorizontalAlignment = -4108
}
$ws1.Cells(2, $outTotal).Value2 = "Total Outstanding"

# Row 3 - stock codes (both blocks)
for ($c = 0; $c -lt $nCodes; $c++) {
    $cell = $ws1.Cells(3, $c+2)
    $cell.Value2 = $shirtCodes[$c]
    $cell.HorizontalAlignment = -4108
    $cell.Font.Size = 8
    $cell2 = $ws1.Cells(3, $outStart + $c)
    $cell2.Value2 = $shirtCodes[$c]
    $cell2.HorizontalAlignment = -4108
    $cell2.Font.Size = 8
}

# Header formatting — Blue for On Hand block, Amber for Outstanding block
$ws1.Range($ws1.Cells(2,1), $ws1.Cells(3, $nCodes+2)).Interior.Color = $cBlueHdr
$ws1.Range($ws1.Cells(2,1), $ws1.Cells(3, $nCodes+2)).Font.Color     = $cWhite
$ws1.Range($ws1.Cells(2,1), $ws1.Cells(3, $nCodes+2)).Font.Bold      = $true
$ws1.Range($ws1.Cells(2,$outStart), $ws1.Cells(3, $outTotal)).Interior.Color = $cAmberHdr
$ws1.Range($ws1.Cells(2,$outStart), $ws1.Cells(3, $outTotal)).Font.Color     = $cWhite
$ws1.Range($ws1.Cells(2,$outStart), $ws1.Cells(3, $outTotal)).Font.Bold      = $true

# Data rows
$ohLocs = @($dtOnHand | ForEach-Object { $_.STOCK_LOCATION } | Sort-Object -Unique)

$r = 4; $alt = $false
foreach ($loc in $ohLocs) {
    $ws1.Cells($r,1).Value2 = locLabel $loc
    $rowOHTotal  = 0.0
    $rowOutTotal = 0.0

    for ($c = 0; $c -lt $nCodes; $c++) {
        # On Hand
        $ohQty = getOnHand $loc $shirtCodes[$c]
        if ($ohQty -gt 0) { setNum $ws1 $r ($c+2) $ohQty }
        $rowOHTotal += $ohQty

        # Outstanding
        $outQty = getOutstanding $loc $shirtCodes[$c]
        if ($outQty -ne 0) { setNum $ws1 $r ($outStart+$c) $outQty }
        $rowOutTotal += $outQty
    }
    setNum $ws1 $r ($nCodes+2) $rowOHTotal
    $ws1.Cells.Item($r, $nCodes+2).Font.Bold = $true
    if ($rowOutTotal -ne 0) {
        setNum $ws1 $r $outTotal $rowOutTotal
        $ws1.Cells.Item($r, $outTotal).Font.Bold = $true
    }

    # Alternating row colour (only on-hand block — outstanding block gets amber tint)
    $rowFill = if ($alt) { $cGray } else { $cWhite }
    $ws1.Range($ws1.Cells($r,1), $ws1.Cells($r, $nCodes+2)).Interior.Color = $rowFill
    $ws1.Range($ws1.Cells($r,$outStart), $ws1.Cells($r,$outTotal)).Interior.Color = $cAmberLt
    $alt = -not $alt
    $r++
}

# Totals row
$ws1.Cells($r,1).Value2 = "TOTAL"
$grandOH  = 0.0
$grandOut = 0.0
for ($c = 0; $c -lt $nCodes; $c++) {
    $colOH  = 0.0
    $colOut = 0.0
    foreach ($loc in $ohLocs) {
        $colOH  += getOnHand    $loc $shirtCodes[$c]
        $colOut += getOutstanding $loc $shirtCodes[$c]
    }
    if ($colOH  -gt 0) { setNum $ws1 $r ($c+2)        $colOH  }
    if ($colOut -ne 0) { setNum $ws1 $r ($outStart+$c) $colOut }
    $grandOH  += $colOH
    $grandOut += $colOut
}
setNum $ws1 $r ($nCodes+2) $grandOH
if ($grandOut -ne 0) { setNum $ws1 $r $outTotal $grandOut }

$ws1.Range($ws1.Cells($r,1), $ws1.Cells($r, $nCodes+2)).Interior.Color = $cBlueHdr
$ws1.Range($ws1.Cells($r,1), $ws1.Cells($r, $nCodes+2)).Font.Color     = $cWhite
$ws1.Range($ws1.Cells($r,1), $ws1.Cells($r, $nCodes+2)).Font.Bold      = $true
$ws1.Range($ws1.Cells($r,$outStart), $ws1.Cells($r,$outTotal)).Interior.Color = $cAmberHdr
$ws1.Range($ws1.Cells($r,$outStart), $ws1.Cells($r,$outTotal)).Font.Color     = $cWhite
$ws1.Range($ws1.Cells($r,$outStart), $ws1.Cells($r,$outTotal)).Font.Bold      = $true

# Number format — blank zeros across all data cells
$ws1.Range($ws1.Cells(4,2), $ws1.Cells($r, $nCodes+2)).NumberFormat  = "#,##0;-#,##0;;"
$ws1.Range($ws1.Cells(4,$outStart), $ws1.Cells($r, $outTotal)).NumberFormat = "#,##0;-#,##0;;"

# Column widths
$ws1.Columns(1).ColumnWidth = 28
for ($c = 2; $c -le $nCodes+2; $c++) { $ws1.Columns($c).ColumnWidth = 9 }
$ws1.Columns($sepCol).ColumnWidth = 3    # narrow separator
for ($c = $outStart; $c -le $outTotal; $c++) { $ws1.Columns($c).ColumnWidth = 9 }

$ws1.Activate()
$ws1.Cells(4,1).Select() | Out-Null
$xl.ActiveWindow.FreezePanes = $true

# ---------------------------------------------------------------
# SHEET 2 - STORE DETAIL
# ---------------------------------------------------------------
Write-Host "Building 'Store Detail' sheet..."

# Columns: A=Employee, B=Size, C=Stock Code, D=Transfer Date, E=Qty Transferred,
#          F=DRINV Reference, G=Purchase Date, H=Qty Purchased, I=Outstanding, J=On Hand
$hdrs2 = @("Employee","Size","Stock Code","Transfer Date","Qty Transferred","DRINV Reference","Purchase Date","Qty Purchased","Outstanding","On Hand")
$nCol2 = $hdrs2.Count   # 10

# Title
$ws2.Cells(1,1).Value2 = "Shirt Transfers, Purchases and Outstanding - $today"
$ws2.Range($ws2.Cells(1,1), $ws2.Cells(1,$nCol2)).Merge() | Out-Null
$ws2.Cells(1,1).Font.Bold = $true
$ws2.Cells(1,1).Font.Size = 13

# Column headers
for ($c = 0; $c -lt $nCol2; $c++) { $ws2.Cells(2, $c+1).Value2 = $hdrs2[$c] }
$hdr2 = $ws2.Range($ws2.Cells(2,1), $ws2.Cells(2,$nCol2))
$hdr2.Interior.Color = $cBlueHdr
$hdr2.Font.Color     = $cWhite
$hdr2.Font.Bold      = $true

$dr = 3
$xferStores = @($dtXfer | ForEach-Object { $_.STORE } | Sort-Object -Unique)

foreach ($store in $xferStores) {

    # Store header row
    $storeRange = $ws2.Range($ws2.Cells($dr,1), $ws2.Cells($dr,$nCol2))
    $storeRange.Merge() | Out-Null
    $storeRange.Interior.Color = $cBlueSub
    $storeRange.Font.Bold      = $true
    $storeRange.Font.Size      = 11
    $ws2.Cells($dr,1).Value2   = locLabel $store
    $dr++

    $sXfers = @($dtXfer  | Where-Object { $_.STORE -eq $store })
    $sSales = @($dtSales | Where-Object { $_.STORE -eq $store })
    $sCodes = (($sXfers | ForEach-Object { $_.STOCK_CODE }) + ($sSales | ForEach-Object { $_.STOCK_CODE })) | Sort-Object -Unique

    foreach ($code in $sCodes) {
        $cXfers      = @($sXfers  | Where-Object { $_.STOCK_CODE -eq $code })
        $cSales      = @($sSales  | Where-Object { $_.STOCK_CODE -eq $code })
        $totalXfer   = if ($cXfers.Count) { n (($cXfers | Measure-Object -Property QTY -Sum).Sum) } else { 0.0 }
        $totalSold   = if ($cSales.Count) { n (($cSales | Measure-Object -Property QTY -Sum).Sum) } else { 0.0 }
        $outstanding = $totalXfer - $totalSold

        # Transfer rows
        $altT = $false
        foreach ($x in $cXfers) {
            $ws2.Cells($dr,1).Value2 = $x.EMPLOYEE
            $ws2.Cells($dr,2).Value2 = sizeLabel $code
            $ws2.Cells($dr,3).Value2 = $code
            $ws2.Cells($dr,4).Value2 = $x.PICKED_DATE
            setNum $ws2 $dr 5 $x.QTY
            $ws2.Range($ws2.Cells($dr,1), $ws2.Cells($dr,$nCol2)).Interior.Color = if ($altT) { $cGray } else { $cWhite }
            $altT = -not $altT
            $dr++
        }

        # Purchase (DRINV) rows
        foreach ($s in $cSales) {
            $ws2.Cells($dr,1).Value2 = "Purchase"
            $ws2.Cells($dr,2).Value2 = sizeLabel $code
            $ws2.Cells($dr,3).Value2 = $code
            $ws2.Cells($dr,6).Value2 = $s.DRINV_REF
            $ws2.Cells($dr,7).Value2 = ([datetime]$s.SALE_DATE).ToString("dd/MM/yyyy")
            setNum $ws2 $dr 8 $s.QTY
            $ws2.Range($ws2.Cells($dr,1), $ws2.Cells($dr,$nCol2)).Interior.Color = $cGreen
            $ws2.Cells($dr,1).Font.Italic = $true
            $dr++
        }

        # Outstanding summary row
        $ws2.Cells($dr,1).Value2 = "OUTSTANDING"
        $ws2.Cells($dr,2).Value2 = sizeLabel $code
        $ws2.Cells($dr,3).Value2 = $code
        setNum $ws2 $dr 5 $totalXfer
        setNum $ws2 $dr 8 $totalSold
        setNum $ws2 $dr 9 $outstanding
        # On Hand in col 10 — only on outstanding row
        $ohVal = getOnHand $store $code
        if ($ohVal -gt 0) { setNum $ws2 $dr 10 $ohVal }
        $outR = $ws2.Range($ws2.Cells($dr,1), $ws2.Cells($dr,$nCol2))
        $outR.Interior.Color = if ($outstanding -gt 0) { $cRed } else { $cGreen }
        $outR.Font.Bold      = $true
        $dr++
    }

    $dr++   # blank gap between stores
}

# Column widths and freeze
$colW = @(30, 7, 11, 14, 14, 16, 14, 14, 12, 10)
for ($c = 0; $c -lt $colW.Count; $c++) { $ws2.Columns($c+1).ColumnWidth = $colW[$c] }
$ws2.Activate()
$ws2.Cells(3,1).Select() | Out-Null
$xl.ActiveWindow.FreezePanes = $true

# ---------------------------------------------------------------
# SHEET 3 - OUTSTANDING ONLY (blocks per store)
# ---------------------------------------------------------------
Write-Host "Building 'Outstanding' sheet..."

# Columns: A=Size, B=Stock Code, C=Qty Transferred, D=Qty Purchased, E=Outstanding, F=Employees, G=On Hand
$hdrs3 = @("Size","Stock Code","Qty Transferred","Qty Purchased","Outstanding","Employees","On Hand")
$nCol3 = $hdrs3.Count   # 7

# Title
$ws3.Cells(1,1).Value2 = "Outstanding Shirts by Store - $today"
$ws3.Range($ws3.Cells(1,1), $ws3.Cells(1,$nCol3)).Merge() | Out-Null
$ws3.Cells(1,1).Font.Bold = $true
$ws3.Cells(1,1).Font.Size = 13

# Column headers
for ($c = 0; $c -lt $nCol3; $c++) { $ws3.Cells(2, $c+1).Value2 = $hdrs3[$c] }
$hdr3 = $ws3.Range($ws3.Cells(2,1), $ws3.Cells(2,$nCol3))
$hdr3.Interior.Color = $cBlueHdr
$hdr3.Font.Color     = $cWhite
$hdr3.Font.Bold      = $true

$er = 3
foreach ($store in $xferStores) {
    $sXfers = @($dtXfer  | Where-Object { $_.STORE -eq $store })
    $sSales = @($dtSales | Where-Object { $_.STORE -eq $store })
    $sCodes = (($sXfers | ForEach-Object { $_.STOCK_CODE }) + ($sSales | ForEach-Object { $_.STOCK_CODE })) | Sort-Object -Unique

    # Collect outstanding rows for this store
    $storeOutRows = @()
    foreach ($code in $sCodes) {
        $cX = @($sXfers | Where-Object { $_.STOCK_CODE -eq $code })
        $cS = @($sSales | Where-Object { $_.STOCK_CODE -eq $code })
        $xT = if ($cX.Count) { n (($cX | Measure-Object -Property QTY -Sum).Sum) } else { 0.0 }
        $sT = if ($cS.Count) { n (($cS | Measure-Object -Property QTY -Sum).Sum) } else { 0.0 }
        $out = $xT - $sT
        if ($out -gt 0) {
            $storeOutRows += [PSCustomObject]@{
                Code        = $code
                XferTotal   = $xT
                SoldTotal   = $sT
                Outstanding = $out
                Employees   = getEmployees $store $code
                OnHand      = getOnHand $store $code
            }
        }
    }

    if ($storeOutRows.Count -eq 0) { continue }   # skip stores with nothing outstanding

    # Store header row
    $sr = $ws3.Range($ws3.Cells($er,1), $ws3.Cells($er,$nCol3))
    $sr.Merge() | Out-Null
    $sr.Interior.Color = $cBlueSub
    $sr.Font.Bold      = $true
    $sr.Font.Size      = 11
    $ws3.Cells($er,1).Value2 = locLabel $store
    $er++

    foreach ($row in $storeOutRows) {
        $ws3.Cells($er,1).Value2 = sizeLabel $row.Code
        $ws3.Cells($er,2).Value2 = $row.Code
        setNum $ws3 $er 3 $row.XferTotal
        setNum $ws3 $er 4 $row.SoldTotal
        setNum $ws3 $er 5 $row.Outstanding
        $ws3.Cells($er,6).Value2 = $row.Employees
        if ($row.OnHand -gt 0) { setNum $ws3 $er 7 $row.OnHand }
        $ws3.Range($ws3.Cells($er,1), $ws3.Cells($er,$nCol3)).Interior.Color = $cRed
        $ws3.Range($ws3.Cells($er,1), $ws3.Cells($er,$nCol3)).Font.Bold      = $true
        $er++
    }

    $er++   # blank gap between stores
}

# Column widths and freeze
$colW3 = @(8, 11, 14, 14, 12, 60, 10)
for ($c = 0; $c -lt $colW3.Count; $c++) { $ws3.Columns($c+1).ColumnWidth = $colW3[$c] }
$ws3.Activate()
$ws3.Cells(3,1).Select() | Out-Null
$xl.ActiveWindow.FreezePanes = $true

# ---------------------------------------------------------------
# SAVE
# ---------------------------------------------------------------
$ws1.Activate()
$wb.SaveAs($outFile, 51)
$wb.Close($false)
$xl.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
[System.GC]::Collect()

Write-Host "Saved: $outFile"
