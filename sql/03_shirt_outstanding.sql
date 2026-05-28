-- Outstanding shirts: transferred to stores but not yet sold (paid for by employee)
-- Transfers = STTRF with USER_FIELD_2 = 'SHIRT ORDER' (clothing order flow records only)
-- Sales = DRINV debtor invoices processed at the store against shirt stock codes
-- A positive QTY_OUTSTANDING means shirts at that store are not yet paid for
SELECT
    t.STORE_LOCATION,
    t.STOCK_CODE,
    t.QTY_TRANSFERRED,
    ISNULL(s.QTY_SOLD, 0)                              AS QTY_SOLD,
    t.QTY_TRANSFERRED - ISNULL(s.QTY_SOLD, 0)         AS QTY_OUTSTANDING,
    t.EMPLOYEES
FROM (
    -- Shirts transferred to each store (store-receiving side only)
    SELECT
        st.STOCK_LOCATION                              AS STORE_LOCATION,
        st.STOCK_CODE,
        SUM(st.ENTERED_QTY)                            AS QTY_TRANSFERRED,
        STRING_AGG(st.DESCRIPTION, ', ')
            WITHIN GROUP (ORDER BY st.USER_FIELD_1)    AS EMPLOYEES
    FROM [OceanicSquare].[dbo].[STK_TRANS] st
    WHERE st.TRANS_TYPE   = 'STTRF'
      AND st.USER_FIELD_2 = 'SHIRT ORDER'
      AND st.STOCK_CODE  LIKE '999100%'
      AND st.COMPANY_CODE = 'OS'
      AND st.ENTERED_QTY  > 0
    GROUP BY st.STOCK_LOCATION, st.STOCK_CODE
) t
LEFT JOIN (
    -- Shirts sold at each store via debtor invoice (ENTERED_QTY is negative on sales)
    SELECT
        st.STOCK_LOCATION                              AS STORE_LOCATION,
        st.STOCK_CODE,
        SUM(ABS(st.ENTERED_QTY))                       AS QTY_SOLD
    FROM [OceanicSquare].[dbo].[STK_TRANS] st
    WHERE st.TRANS_TYPE  = 'DRINV'
      AND st.STOCK_CODE LIKE '999100%'
      AND st.COMPANY_CODE = 'OS'
    GROUP BY st.STOCK_LOCATION, st.STOCK_CODE
) s ON  s.STORE_LOCATION = t.STORE_LOCATION
    AND s.STOCK_CODE     = t.STOCK_CODE
WHERE t.QTY_TRANSFERRED - ISNULL(s.QTY_SOLD, 0) > 0
ORDER BY t.STORE_LOCATION, t.STOCK_CODE
