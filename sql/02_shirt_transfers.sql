-- All shirt order transfers processed by the clothing order flow
-- ENTERED_QTY > 0 selects only the store-receiving side (excludes the warehouse deduction row)
-- USER_FIELD_6 (EmployeeID-StockCode) + USER_FIELD_3 (Picked Date) uniquely identifies each order line
SELECT
    st.REFERENCE_NBR,
    CONVERT(date, st.TRANS_DATE)   AS TRANS_DATE,
    st.STOCK_LOCATION              AS STORE_LOCATION,
    st.STOCK_CODE,
    st.DESCRIPTION                 AS SHIRT_DESCRIPTION,
    st.ENTERED_QTY                 AS QTY_TRANSFERRED,
    st.USER_FIELD_1                AS EMPLOYEE_ID,
    st.USER_FIELD_3                AS PICKED_DATE,
    st.USER_FIELD_6                AS EMPLOYEE_STOCK_KEY
FROM [OceanicSquare].[dbo].[STK_TRANS] st
WHERE st.TRANS_TYPE   = 'STTRF'
  AND st.USER_FIELD_2 = 'SHIRT ORDER'
  AND st.STOCK_CODE  LIKE '999100%'
  AND st.COMPANY_CODE = 'OS'
  AND st.ENTERED_QTY  > 0
ORDER BY CONVERT(date, st.TRANS_DATE) DESC, st.STOCK_LOCATION, st.USER_FIELD_1
