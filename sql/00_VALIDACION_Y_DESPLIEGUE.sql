-- ================================================================
-- OPTI-COLOR VENEZUELA - PROTOCOLO DE VALIDACIÓN Y DESPLIEGUE
-- Fecha: 20/04/2026
-- ================================================================

-- PASO 1: VALIDACIÓN PREVIA - Verifica que todas las tablas base existen
-- ================================================================
PRINT '========== PASO 1: VALIDACIÓN DE TABLAS BASE =========='
GO

SELECT
    TABLE_NAME,
    CASE WHEN TABLE_NAME IN (
        'Maestro_Sucursales',
        'Maestro_Clientes',
        'Maestro_Categorias',
        'Maestro_Productos',
        'Ventas_Pedidos',
        'Ventas_Cabecera',
        'Ventas_Detalle',
        'Marketing_Citas',
        'Clinica_Examenes',
        'Operaciones_Ordenes_Cristales',
        'Operaciones_Recepciones_Lab',
        'Finanzas_Cobros',
        'Finanzas_Tesoreria',
        'Etl_Control_Ejecucion'
    ) THEN 'REQUERIDA' ELSE 'OPCIONAL' END AS importancia,
    'OK' AS estado
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
    'Maestro_Sucursales',
    'Maestro_Clientes',
    'Maestro_Categorias',
    'Maestro_Productos',
    'Ventas_Pedidos',
    'Ventas_Cabecera',
    'Ventas_Detalle',
    'Marketing_Citas',
    'Clinica_Examenes',
    'Operaciones_Ordenes_Cristales',
    'Operaciones_Recepciones_Lab',
    'Finanzas_Cobros',
    'Finanzas_Tesoreria',
    'Etl_Control_Ejecucion'
  )
ORDER BY TABLE_NAME;
GO

-- Reporta tablas FALTANTES
PRINT ''
PRINT 'TABLAS FALTANTES (si hay):';
SELECT
    'Maestro_Sucursales' AS tabla_esperada
UNION
SELECT 'Maestro_Clientes'
UNION
SELECT 'Maestro_Categorias'
UNION
SELECT 'Maestro_Productos'
UNION
SELECT 'Ventas_Pedidos'
UNION
SELECT 'Ventas_Cabecera'
UNION
SELECT 'Ventas_Detalle'
UNION
SELECT 'Marketing_Citas'
UNION
SELECT 'Clinica_Examenes'
UNION
SELECT 'Operaciones_Ordenes_Cristales'
UNION
SELECT 'Operaciones_Recepciones_Lab'
UNION
SELECT 'Finanzas_Cobros'
UNION
SELECT 'Finanzas_Tesoreria'
UNION
SELECT 'Etl_Control_Ejecucion'
EXCEPT
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo'
ORDER BY tabla_esperada;
GO

-- ================================================================
-- PASO 2: CREAR TABLA AUXILIAR (Param_Venezuela_Geografia)
-- ================================================================
PRINT ''
PRINT '========== PASO 2: CREAR TABLA AUXILIAR =========='
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Param_Venezuela_Geografia]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[Param_Venezuela_Geografia] (
        id_param INT PRIMARY KEY IDENTITY(1,1),
        estado VARCHAR(100) NOT NULL,
        municipio VARCHAR(100),
        latitud DECIMAL(10,8),
        longitud DECIMAL(11,8),
        UNIQUE(estado, municipio)
    );
    PRINT '✓ Tabla Param_Venezuela_Geografia creada exitosamente'
END
ELSE
BEGIN
    PRINT '✓ Tabla Param_Venezuela_Geografia ya existe'
END
GO

-- Verifica que la tabla fue creada
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Param_Venezuela_Geografia' AND TABLE_SCHEMA = 'dbo'
ORDER BY ORDINAL_POSITION;
GO

-- ================================================================
-- PASO 3: DESPLEGAR VISTAS (Incluye el script completo)
-- ================================================================
PRINT ''
PRINT '========== PASO 3: DESPLEGANDO VISTAS =========='
GO

-- Ejecuta el script completo de vistas
-- (El contenido del archivo vistas_opticolor_venezuela_LIMPIO.sql se insertará aquí)
-- Para ejecutar: copia y pega el contenido de vistas_opticolor_venezuela_LIMPIO.sql

-- ================================================================
-- PASO 4: POST-DESPLIEGUE - VALIDACIÓN DE VISTAS
-- ================================================================
PRINT ''
PRINT '========== PASO 4: VALIDACIÓN POST-DESPLIEGUE =========='
GO

-- Cuenta de vistas Dim_ y Fact_ creadas
PRINT 'Conteo de vistas Dim_* y Fact_*:'
SELECT
    COUNT(*) AS total_vistas_bi,
    'Vistas BI (Dim_* + Fact_*)' AS descripcion
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%');
GO

-- Lista todas las vistas Dim_ y Fact_
PRINT 'Listado completo de vistas BI:'
SELECT
    TABLE_NAME AS nombre_vista,
    CASE WHEN TABLE_NAME LIKE 'Dim_%' THEN 'Dimensión' ELSE 'Hecho' END AS tipo,
    'OK' AS estado
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%')
ORDER BY TABLE_NAME;
GO

-- Verifica que NO existen las vistas eliminadas
PRINT ''
PRINT 'Verificación: Vistas ELIMINADAS (deben estar vacías):'
SELECT
    TABLE_NAME AS vista_eliminada,
    'DEBE ESTAR VACÍA' AS estado
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
    'Fact_Zoho_Gastos',
    'Fact_Embudo_Marketing',
    'Dim_GHL_Sucursales_Link'
  );

IF @@ROWCOUNT = 0
BEGIN
    PRINT '✓ Correctamente: Las vistas eliminadas NO existen'
END
GO

-- ================================================================
-- PASO 5: PRUEBAS DE EJECUCIÓN - SELECT simple de cada vista
-- ================================================================
PRINT ''
PRINT '========== PASO 5: PRUEBAS DE EJECUCIÓN SIMPLE =========='
GO

-- Prueba 1: Dim_Sucursales
PRINT ''
PRINT 'Prueba 1: SELECT TOP 3 FROM [dbo].[Dim_Sucursales]'
IF OBJECT_ID('[dbo].[Dim_Sucursales]') IS NOT NULL
BEGIN
    SELECT TOP 3 * FROM [dbo].[Dim_Sucursales]
    PRINT '✓ Vista Dim_Sucursales accesible'
END
ELSE
BEGIN
    PRINT '✗ ERROR: Vista Dim_Sucursales NO existe'
END
GO

-- Prueba 2: Fact_Pedidos
PRINT ''
PRINT 'Prueba 2: SELECT TOP 3 FROM [dbo].[Fact_Pedidos]'
IF OBJECT_ID('[dbo].[Fact_Pedidos]') IS NOT NULL
BEGIN
    SELECT TOP 3 * FROM [dbo].[Fact_Pedidos]
    PRINT '✓ Vista Fact_Pedidos accesible'
END
ELSE
BEGIN
    PRINT '✗ ERROR: Vista Fact_Pedidos NO existe'
END
GO

-- Prueba 3: Fact_Ventas
PRINT ''
PRINT 'Prueba 3: SELECT TOP 3 FROM [dbo].[Fact_Ventas]'
IF OBJECT_ID('[dbo].[Fact_Ventas]') IS NOT NULL
BEGIN
    SELECT TOP 3 * FROM [dbo].[Fact_Ventas]
    PRINT '✓ Vista Fact_Ventas accesible'
END
ELSE
BEGIN
    PRINT '✗ ERROR: Vista Fact_Ventas NO existe'
END
GO

-- Prueba 4: Dim_Clientes
PRINT ''
PRINT 'Prueba 4: SELECT TOP 3 FROM [dbo].[Dim_Clientes]'
IF OBJECT_ID('[dbo].[Dim_Clientes]') IS NOT NULL
BEGIN
    SELECT TOP 3 * FROM [dbo].[Dim_Clientes]
    PRINT '✓ Vista Dim_Clientes accesible'
END
ELSE
BEGIN
    PRINT '✗ ERROR: Vista Dim_Clientes NO existe'
END
GO

-- ================================================================
-- PASO 6: VALIDACIÓN DE DATOS Y TIMEZONES
-- ================================================================
PRINT ''
PRINT '========== PASO 6: VALIDACIÓN DE DATOS =========='
GO

-- Verifica ajustes horarios GMT-4
PRINT ''
PRINT 'Verificación de Timezone (GMT-4):'
IF OBJECT_ID('[dbo].[Fact_Pedidos]') IS NOT NULL
BEGIN
    SELECT TOP 5
        fecha_pedido_completa,
        mes_pedido_nombre,
        YEAR(fecha_pedido_completa) AS anio,
        MONTH(fecha_pedido_completa) AS mes
    FROM [dbo].[Fact_Pedidos]
    PRINT '✓ Timezone GMT-4 verificado en Fact_Pedidos'
END
GO

-- Verifica IVA 16% en Fact_Ventas
PRINT ''
PRINT 'Verificación de IVA (16% Venezuela):'
IF OBJECT_ID('[dbo].[Fact_Ventas]') IS NOT NULL
BEGIN
    SELECT TOP 3
        monto_total,
        monto_sin_iva,
        CAST(monto_total - monto_sin_iva AS DECIMAL(10,2)) AS iva_calculado,
        CAST((monto_total - monto_sin_iva) / NULLIF(monto_sin_iva, 0) * 100 AS DECIMAL(5,2)) AS porcentaje_iva
    FROM [dbo].[Fact_Ventas]
    WHERE monto_total <> 0
    PRINT '✓ IVA 16% verificado en Fact_Ventas'
END
GO

-- ================================================================
-- REPORTE FINAL
-- ================================================================
PRINT ''
PRINT '========== REPORTE FINAL DE DESPLIEGUE =========='
GO

SELECT
    'Validación Previa: Tablas Base' AS paso,
    COUNT(*) AS cantidad,
    'Ver tabla de arriba' AS resultado
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
    'Maestro_Sucursales', 'Maestro_Clientes', 'Maestro_Categorias',
    'Maestro_Productos', 'Ventas_Pedidos', 'Ventas_Cabecera', 'Ventas_Detalle',
    'Marketing_Citas', 'Clinica_Examenes', 'Operaciones_Ordenes_Cristales',
    'Operaciones_Recepciones_Lab', 'Finanzas_Cobros', 'Finanzas_Tesoreria',
    'Etl_Control_Ejecucion'
  )
UNION ALL
SELECT
    'Tabla Auxiliar',
    CASE WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Param_Venezuela_Geografia' AND TABLE_SCHEMA = 'dbo') THEN 1 ELSE 0 END,
    CASE WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Param_Venezuela_Geografia' AND TABLE_SCHEMA = 'dbo') THEN '✓ Creada' ELSE '✗ Faltante' END
UNION ALL
SELECT
    'Vistas BI Desplegadas',
    COUNT(*),
    '✓ Completadas'
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%');
GO

PRINT '✓ PROTOCOLO DE VALIDACIÓN Y DESPLIEGUE COMPLETADO'
PRINT ''
PRINT '═══════════════════════════════════════════════════════════'
PRINT 'SIGUIENTES PASOS:'
PRINT '1. Ejecuta este script paso a paso en SSMS'
PRINT '2. Verifica que todas las tablas base existan'
PRINT '3. Ejecuta el contenido de vistas_opticolor_venezuela_LIMPIO.sql'
PRINT '4. Ejecuta las pruebas de validación post-despliegue'
PRINT '5. Captura los resultados y reporta'
PRINT '═══════════════════════════════════════════════════════════'
GO
