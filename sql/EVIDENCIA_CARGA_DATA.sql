-- ============================================================================
-- EVIDENCIA DE CARGA ETL - OPTICOLOR BI VENEZUELA
-- Reporte completo de tablas cargadas con conteos y rangos de fechas
-- ============================================================================

SET NOCOUNT ON;

PRINT '================================================================================';
PRINT 'REPORTE DE CARGA ETL - OPTICOLOR BI VENEZUELA';
PRINT 'Fecha de Generación: ' + CONVERT(VARCHAR, GETDATE(), 121);
PRINT '================================================================================';
PRINT '';

-- ============================================================================
-- SECCIÓN 1: TABLAS MAESTRO (Sin fechas)
-- ============================================================================
PRINT '--- TABLAS MAESTRO (Dimensiones) ---';
PRINT '';

SELECT
    'Maestro_Sucursales' AS [Tabla],
    COUNT(*) AS [Registros]
FROM Maestro_Sucursales
UNION ALL
SELECT
    'Maestro_Empleados',
    COUNT(*)
FROM Maestro_Empleados
UNION ALL
SELECT
    'Maestro_Categorias',
    COUNT(*)
FROM Maestro_Categorias
UNION ALL
SELECT
    'Maestro_Marcas',
    COUNT(*)
FROM Maestro_Marcas
UNION ALL
SELECT
    'Maestro_Productos',
    COUNT(*)
FROM Maestro_Productos
UNION ALL
SELECT
    'Maestro_Clientes',
    COUNT(*)
FROM Maestro_Clientes
UNION ALL
SELECT
    'Maestro_Proveedores',
    COUNT(*)
FROM Maestro_Proveedores
UNION ALL
SELECT
    'Maestro_Metodos_Pago',
    COUNT(*)
FROM Maestro_Metodos_Pago
ORDER BY [Tabla];

PRINT '';

-- ============================================================================
-- SECCIÓN 2: TABLAS TRANSACCIONALES CON FECHAS
-- ============================================================================
PRINT '--- TABLAS TRANSACCIONALES (Con Rangos de Fechas) ---';
PRINT '';

-- Ventas_Cabecera
SELECT
    'Ventas_Cabecera' AS [Tabla],
    COUNT(*) AS [Registros],
    CAST(MIN(CAST(fecha_factura AS DATE)) AS NVARCHAR(10)) AS [Fecha_Minima],
    CAST(MAX(CAST(fecha_factura AS DATE)) AS NVARCHAR(10)) AS [Fecha_Maxima]
FROM Ventas_Cabecera
UNION ALL
-- Ventas_Pedidos
SELECT
    'Ventas_Pedidos',
    COUNT(*),
    CAST(MIN(CAST(fecha_pedido AS DATE)) AS NVARCHAR(10)),
    CAST(MAX(CAST(fecha_pedido AS DATE)) AS NVARCHAR(10))
FROM Ventas_Pedidos
WHERE fecha_pedido IS NOT NULL
UNION ALL
-- Finanzas_Cobros
SELECT
    'Finanzas_Cobros',
    COUNT(*),
    CAST(MIN(CAST(fecha_cobro AS DATE)) AS NVARCHAR(10)),
    CAST(MAX(CAST(fecha_cobro AS DATE)) AS NVARCHAR(10))
FROM Finanzas_Cobros
WHERE fecha_cobro IS NOT NULL
UNION ALL
-- Finanzas_Tesoreria
SELECT
    'Finanzas_Tesoreria',
    COUNT(*),
    CAST(MIN(CAST(fecha_movimiento AS DATE)) AS NVARCHAR(10)),
    CAST(MAX(CAST(fecha_movimiento AS DATE)) AS NVARCHAR(10))
FROM Finanzas_Tesoreria
WHERE fecha_movimiento IS NOT NULL
UNION ALL
-- Clinica_Examenes
SELECT
    'Clinica_Examenes',
    COUNT(*),
    CAST(MIN(CAST(fecha_examen AS DATE)) AS NVARCHAR(10)),
    CAST(MAX(CAST(fecha_examen AS DATE)) AS NVARCHAR(10))
FROM Clinica_Examenes
WHERE fecha_examen IS NOT NULL
UNION ALL
-- Marketing_Citas
SELECT
    'Marketing_Citas',
    COUNT(*),
    CAST(MIN(CAST(fecha_cita_inicio AS DATE)) AS NVARCHAR(10)),
    CAST(MAX(CAST(fecha_cita_inicio AS DATE)) AS NVARCHAR(10))
FROM Marketing_Citas
ORDER BY [Tabla];

PRINT '';

-- ============================================================================
-- SECCIÓN 3: TABLAS OPERACIONALES CON FECHAS
-- ============================================================================
PRINT '--- TABLAS OPERACIONALES (Con Rangos de Fechas) ---';
PRINT '';

-- Operaciones_Ordenes_Cristales
SELECT
    'Operaciones_Ordenes_Cristales' AS [Tabla],
    COUNT(*) AS [Registros],
    CAST(MIN(CAST(fecha_creacion AS DATE)) AS NVARCHAR(10)) AS [Fecha_Minima],
    CAST(MAX(CAST(fecha_creacion AS DATE)) AS NVARCHAR(10)) AS [Fecha_Maxima]
FROM [dbo].[Operaciones_Ordenes_Cristales]
WHERE fecha_creacion IS NOT NULL
UNION ALL
-- Operaciones_Inventario
SELECT
    'Operaciones_Inventario',
    COUNT(*),
    CAST(MIN(CAST(fecha_actualizacion AS DATE)) AS NVARCHAR(10)),
    CAST(MAX(CAST(fecha_actualizacion AS DATE)) AS NVARCHAR(10))
FROM [dbo].[Operaciones_Inventario]
WHERE fecha_actualizacion IS NOT NULL
UNION ALL
-- Operaciones_Pedidos_Laboratorio
SELECT
    'Operaciones_Pedidos_Laboratorio',
    COUNT(*),
    CAST(MIN(CAST(fecha_solicitud AS DATE)) AS NVARCHAR(10)),
    CAST(MAX(CAST(fecha_solicitud AS DATE)) AS NVARCHAR(10))
FROM Operaciones_Pedidos_Laboratorio
WHERE fecha_solicitud IS NOT NULL
UNION ALL
-- Operaciones_Recepciones_Lab
SELECT
    'Operaciones_Recepciones_Lab',
    COUNT(*),
    CAST(MIN(CAST(fecha_recepcion_exacta AS DATE)) AS NVARCHAR(10)),
    CAST(MAX(CAST(fecha_recepcion_exacta AS DATE)) AS NVARCHAR(10))
FROM Operaciones_Recepciones_Lab
WHERE fecha_recepcion_exacta IS NOT NULL
ORDER BY [Tabla];

PRINT '';

-- ============================================================================
-- SECCIÓN 4: RESUMEN GENERAL
-- ============================================================================
PRINT '--- RESUMEN TOTAL DE REGISTROS ---';
PRINT '';

SELECT
    SUM(cnt) AS [Total_Registros_ETL]
FROM (
    SELECT COUNT(*) AS cnt FROM Maestro_Sucursales
    UNION ALL SELECT COUNT(*) FROM Maestro_Empleados
    UNION ALL SELECT COUNT(*) FROM Maestro_Categorias
    UNION ALL SELECT COUNT(*) FROM Maestro_Marcas
    UNION ALL SELECT COUNT(*) FROM Maestro_Productos
    UNION ALL SELECT COUNT(*) FROM Maestro_Clientes
    UNION ALL SELECT COUNT(*) FROM Maestro_Proveedores
    UNION ALL SELECT COUNT(*) FROM Maestro_Metodos_Pago
    UNION ALL SELECT COUNT(*) FROM Ventas_Cabecera
    UNION ALL SELECT COUNT(*) FROM Ventas_Pedidos
    UNION ALL SELECT COUNT(*) FROM Finanzas_Cobros
    UNION ALL SELECT COUNT(*) FROM Finanzas_Tesoreria
    UNION ALL SELECT COUNT(*) FROM Clinica_Examenes
    UNION ALL SELECT COUNT(*) FROM Marketing_Citas
    UNION ALL SELECT COUNT(*) FROM Operaciones_Ordenes_Cristales
    UNION ALL SELECT COUNT(*) FROM Operaciones_Inventario
    UNION ALL SELECT COUNT(*) FROM Operaciones_Pedidos_Laboratorio
    UNION ALL SELECT COUNT(*) FROM Operaciones_Recepciones_Lab
) AS resumen;

PRINT '';
PRINT '================================================================================';
PRINT 'FIN DEL REPORTE';
PRINT '================================================================================';
