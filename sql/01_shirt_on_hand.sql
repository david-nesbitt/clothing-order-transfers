-- Shirt stock on-hand quantities across all store locations
-- Stock codes 9991001-9991007 = XS through XXXL staff polo shirts
SELECT
    m.[STOCK_CODE],
    m.[STOCK_LOCATION],
    m.[STOCK_DESCRIPTION_1],
    m.[ON_HAND_QTY]
FROM [OceanicSquare].[dbo].[STK_LOCN_MASTER] m
WHERE m.[STOCK_CODE] LIKE '999100%'
  AND m.[COMPANY_CODE] = 'OS'
  AND m.[ON_HAND_QTY] <> 0
ORDER BY m.[STOCK_LOCATION], m.[STOCK_CODE]
