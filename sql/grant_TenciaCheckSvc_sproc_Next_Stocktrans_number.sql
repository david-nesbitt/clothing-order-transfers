-- Grant TenciaCheckSvc execute permission on sproc_Next_Stocktrans_number
-- Required so the Power Automate clothing order export flow (v15+) can call
-- this procedure via the SQL Server connector on the PP01-SV06 gateway.
-- PP is TRUSTWORTHY so the procedure's cross-db UPDATE on OceanicSquare.SYSTEM_MASTER
-- is already covered — only this EXECUTE grant is needed.
USE [PP];
GO
GRANT EXECUTE ON [dbo].[sproc_Next_Stocktrans_number] TO [PRICESPLUS\TenciaCheckSvc];
GO
