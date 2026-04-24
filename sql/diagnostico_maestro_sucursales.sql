USE [db-opticolor-dw];
GO

-- Ver estructura actual de Maestro_Sucursales
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Maestro_Sucursales'
ORDER BY ORDINAL_POSITION;

-- Ver datos de ejemplo
SELECT TOP 10 * FROM Maestro_Sucursales;
