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

# SQL queries
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
ORDER BY st.STOCK_LOCATION, CONVERT(date, st.TRANS_DATE)
"@

$conn.Close()
Write-Host ("Loaded: {0} on-hand, {1} transfers, {2} DRINV sales" -f $dtOnHand.Rows.Count, $dtXfer.Rows.Count, $dtSales.Rows.Count)

# Excel setup
$outFile = Join-Path (Split-Path $PSCommandPath) ("ShirtReport_{0}.xlsx" -f (Get-Date -Format 'yyyyMMdd'))
$xl  = New-Object -ComObject Excel.Application
$xl.Visible       = $false
$xl.DisplayAlerts = $false
$wb  = $xl.Workbooks.Add()

while ($wb.Worksheets.Count -gt 1) { $wb.Worksheets.Item($wb.Worksheets.Count).Delete() }
$ws1 = $wb.Worksheets.Item(1); $ws1.Name = "On Hand"
$ws2 = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $ws1); $ws2.Name = "Store Detail"

# Colour palette
$cBlueHdr  = rgb 68  114 196
$cBlueSub  = rgb 189 215 238
$cGray     = rgb 242 242 242
$cGreen    = rgb 198 239 206
$cRed      = rgb 255 199 206
$cWhite    = rgb 255 255 255

$today = Get-Date -Format 'dd/MM/yyyy'

# ---------------------------------------------------------------
# SHEET 1 - ON HAND PIVOT
# ---------------------------------------------------------------
Write-Host "Building 'On Hand' sheet..."

$nCodes = $shirtCodes.Count

# Title row 1
$ws1.Cells(1,1).Value2 = "Shirt Stock On Hand - $today"
$ws1.Range($ws1.Cells(1,1), $ws1.Cells(1, $nCodes+2)).Merge() | Out-Null
$ws1.Cells(1,1).Font.Bold = $true
$ws1.Cells(1,1).Font.Size = 13

# Row 2 - size labels
$ws1.Cells(2,1).Value2 = "Location"
for ($c = 0; $c -lt $nCodes; $c++) {
    $cell = $ws1.Cells(2, $c+2)
    $cell.Value2 = $shirtSizeMap[$shirtCodes[$c]]
    $cell.HorizontalAlignment = -4108
}
$ws1.Cells(2, $nCodes+2).Value2 = "Total"

# Row 3 - stock codes
for ($c = 0; $c -lt $nCodes; $c++) {
    $cell = $ws1.Cells(3, $c+2)
    $cell.Value2 = $shirtCodes[$c]
    $cell.HorizontalAlignment = -4108
    $cell.Font.Size = 8
}

# Header formatting rows 2-3
$hdr = $ws1.Range($ws1.Cells(2,1), $ws1.Cells(3, $nCodes+2))
$hdr.Interior.Color = $cBlueHdr
$hdr.Font.Color     = $cWhite
$hdr.Font.Bold      = $true

# Data rows
$ohLocs = @($dtOnHand | ForEach-Object { $_.STOCK_LOCATION } | Sort-Object -Unique)

$r = 4; $alt = $false
foreach ($loc in $ohLocs) {
    $ws1.Cells($r,1).Value2 = locLabel $loc
    $rowTotal = 0
    for ($c = 0; $c -lt $nCodes; $c++) {
        $match = @($dtOnHand | Where-Object { $_.STOCK_LOCATION -eq $loc -and $_.STOCK_CODE -eq $shirtCodes[$c] })
        $qty   = if ($match.Count) { n $match[0].ON_HAND_QTY } else { 0.0 }
        if ($qty -gt 0) { setNum $ws1 $r ($c+2) $qty }
        $rowTotal += $qty
    }
    setNum $ws1 $r ($nCodes+2) $rowTotal
    $ws1.Cells.Item($r, $nCodes+2).Font.Bold = $true
    if ($alt) { $ws1.Range($ws1.Cells($r,1), $ws1.Cells($r, $nCodes+2)).Interior.Color = $cGray }
    $alt = -not $alt
    $r++
}

# Totals row
$ws1.Cells($r,1).Value2 = "TOTAL"
$grandTotal = 0
for ($c = 0; $c -lt $nCodes; $c++) {
    $colSum = 0
    foreach ($loc in $ohLocs) {
        $match = @($dtOnHand | Where-Object { $_.STOCK_LOCATION -eq $loc -and $_.STOCK_CODE -eq $shirtCodes[$c] })
        if ($match.Count) { $colSum += n $match[0].ON_HAND_QTY } else { $colSum += 0.0 }
    }
    if ($colSum -gt 0) { setNum $ws1 $r ($c+2) $colSum }
    $grandTotal += $colSum
}
setNum $ws1 $r ($nCodes+2) $grandTotal
$totRange = $ws1.Range($ws1.Cells($r,1), $ws1.Cells($r, $nCodes+2))
$totRange.Interior.Color = $cBlueHdr
$totRange.Font.Color     = $cWhite
$totRange.Font.Bold      = $true

# Number format - blank zeros
$ws1.Range($ws1.Cells(4,2), $ws1.Cells($r, $nCodes+2)).NumberFormat = "#,##0;-#,##0;;"

# Column widths and freeze
$ws1.Columns(1).ColumnWidth = 28
for ($c = 2; $c -le $nCodes+2; $c++) { $ws1.Columns($c).ColumnWidth = 9 }
$ws1.Activate()
$ws1.Cells(4,1).Select() | Out-Null
$xl.ActiveWindow.FreezePanes = $true

# ---------------------------------------------------------------
# SHEET 2 - STORE DETAIL
# ---------------------------------------------------------------
Write-Host "Building 'Store Detail' sheet..."

# Columns: A=Employee, B=Size, C=Stock Code, D=Transfer Date, E=Qty Transferred,
#          F=DRINV Reference, G=Purchase Date, H=Qty Purchased, I=Outstanding
$hdrs2 = @("Employee","Size","Stock Code","Transfer Date","Qty Transferred","DRINV Reference","Purchase Date","Qty Purchased","Outstanding")
$nCol2 = $hdrs2.Count

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
        $totalXfer   = if ($cXfers.Count)  { n (($cXfers  | Measure-Object -Property QTY -Sum).Sum) } else { 0.0 }
        $totalSold   = if ($cSales.Count)  { n (($cSales  | Measure-Object -Property QTY -Sum).Sum) } else { 0.0 }
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
        $outR = $ws2.Range($ws2.Cells($dr,1), $ws2.Cells($dr,$nCol2))
        $outR.Interior.Color = if ($outstanding -gt 0) { $cRed } else { $cGreen }
        $outR.Font.Bold      = $true
        $dr++
    }

    $dr++   # blank gap between stores
}

# Column widths and freeze
$colW = @(30, 7, 11, 14, 14, 16, 14, 14, 12)
for ($c = 0; $c -lt $colW.Count; $c++) { $ws2.Columns($c+1).ColumnWidth = $colW[$c] }
$ws2.Activate()
$ws2.Cells(3,1).Select() | Out-Null
$xl.ActiveWindow.FreezePanes = $true

# Save
$ws1.Activate()
$wb.SaveAs($outFile, 51)
$wb.Close($false)
$xl.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
[System.GC]::Collect()

Write-Host "Saved: $outFile"
