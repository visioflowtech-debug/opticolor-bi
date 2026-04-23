-- ============================================================================
-- VALIDACIÓN POST-CRON: 8:30 AM EL SALVADOR (10:30 AM VENEZUELA)
-- Verificar que los datos se sincronizaron correctamente
-- ============================================================================

PRINT '================================================================================';
PRINT 'VALIDACIÓN POST-CRON 8:30 AM EL SALVADOR';
PRINT 'Hora de ejecución: ' + CONVERT(VARCHAR, GETDATE(), 121);
PRINT '================================================================================';
PRINT '';

-- ============================================================================
-- RESUMEN RÁPIDO: REGISTROS POR TABLA (Cambios desde última ejecución)
-- ============================================================================

PRINT '--- MAESTROS ---';
SELECT 'Maestro_Sucursales' AS Tabla, COUNT(*) AS Registros FROM Maestro_Sucursales
UNION ALL SELECT 'Maestro_Empleados', COUNT(*) FROM Maestro_Empleados
UNION ALL SELECT 'Maestro_Categorias', COUNT(*) FROM Maestro_Categorias
UNION ALL SELECT 'Maestro_Marcas', COUNT(*) FROM Maestro_Marcas
UNION ALL SELECT 'Maestro_Productos', COUNT(*) FROM Maestro_Productos
UNION ALL SELECT 'Maestro_Clientes', COUNT(*) FROM Maestro_Clientes
UNION ALL SELECT 'Maestro_Proveedores', COUNT(*) FROM Maestro_Proveedores
UNION ALL SELECT 'Maestro_Metodos_Pago', COUNT(*) FROM Maestro_Metodos_Pago
ORDER BY Tabla;

PRINT '';
PRINT '--- TRANSACCIONALES ---';
SELECT 'Ventas_Cabecera' AS Tabla, COUNT(*) AS Registros,
       CAST(MIN(fecha_factura) AS DATE) AS Fecha_Min, CAST(MAX(fecha_factura) AS DATE) AS Fecha_Max
FROM Ventas_Cabecera
UNION ALL
SELECT 'Ventas_Pedidos', COUNT(*), CAST(MIN(fecha_pedido) AS DATE), CAST(MAX(fecha_pedido) AS DATE)
FROM Ventas_Pedidos WHERE fecha_pedido IS NOT NULL
UNION ALL
SELECT 'Finanzas_Cobros', COUNT(*), CAST(MIN(fecha_cobro) AS DATE), CAST(MAX(fecha_cobro) AS DATE)
FROM Finanzas_Cobros WHERE fecha_cobro IS NOT NULL
UNION ALL
SELECT 'Finanzas_Tesoreria', COUNT(*), CAST(MIN(fecha_movimiento) AS DATE), CAST(MAX(fecha_movimiento) AS DATE)
FROM Finanzas_Tesoreria WHERE fecha_movimiento IS NOT NULL
UNION ALL
SELECT 'Clinica_Examenes', COUNT(*), CAST(MIN(fecha_examen) AS DATE), CAST(MAX(fecha_examen) AS DATE)
FROM Clinica_Examenes WHERE fecha_examen IS NOT NULL
UNION ALL
SELECT 'Marketing_Citas', COUNT(*), CAST(MIN(fecha_cita_inicio) AS DATE), CAST(MAX(fecha_cita_inicio) AS DATE)
FROM Marketing_Citas
ORDER BY Tabla;

PRINT '';
PRINT '--- OPERACIONALES ---';
SELECT 'Operaciones_Ordenes_Cristales' AS Tabla, COUNT(*) AS Registros,
       CAST(MIN(fecha_creacion) AS DATE) AS Fecha_Min, CAST(MAX(fecha_creacion) AS DATE) AS Fecha_Max
FROM Operaciones_Ordenes_Cristales WHERE fecha_creacion IS NOT NULL
UNION ALL
SELECT 'Operaciones_Inventario', COUNT(*), CAST(MIN(fecha_actualizacion) AS DATE), CAST(MAX(fecha_actualizacion) AS DATE)
FROM Operaciones_Inventario WHERE fecha_actualizacion IS NOT NULL
UNION ALL
SELECT 'Operaciones_Pedidos_Laboratorio', COUNT(*), CAST(MIN(fecha_solicitud) AS DATE), CAST(MAX(fecha_solicitud) AS DATE)
FROM Operaciones_Pedidos_Laboratorio WHERE fecha_solicitud IS NOT NULL
UNION ALL
SELECT 'Operaciones_Recepciones_Lab', COUNT(*), CAST(MIN(fecha_recepcion_exacta) AS DATE), CAST(MAX(fecha_recepcion_exacta) AS DATE)
FROM Operaciones_Recepciones_Lab WHERE fecha_recepcion_exacta IS NOT NULL
ORDER BY Tabla;

PRINT '';
PRINT '--- TOTAL GENERAL ---';
SELECT
    SUM(cnt) AS Total_Registros
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
PRINT 'FIN VALIDACIÓN';
PRINT '================================================================================';
