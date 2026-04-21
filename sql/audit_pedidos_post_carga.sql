-- ============================================================
-- AUDITORÍA PEDIDOS POST-CARGA - OPTICOLOR VENEZUELA
-- Fecha: 2026-04-21 (después de ejecutar HISTÓRICOS)
-- Propósito: Validar integridad de carga PEDIDOS (HISTORICAL)
-- ============================================================

-- 1. CONTEO TOTAL PEDIDOS
PRINT '
--- RESUMEN PEDIDOS ---';
SELECT
    COUNT(*) as total_pedidos,
    COUNT(DISTINCT id_cliente) as clientes_unicos,
    COUNT(DISTINCT id_sucursal) as sucursales_unicas,
    COUNT(DISTINCT id_empleado) as empleados_unicos
FROM Ventas_Pedidos;

-- 2. RANGO DE FECHAS PEDIDOS
PRINT '
--- RANGO DE FECHAS PEDIDOS ---';
SELECT
    COUNT(*) as total_pedidos,
    MIN(fecha_pedido) as fecha_minima,
    MAX(fecha_pedido) as fecha_maxima,
    MIN(fecha_carga_etl) as primera_carga_etl,
    MAX(fecha_carga_etl) as ultima_carga_etl
FROM Ventas_Pedidos;

-- 3. DISTRIBUCIÓN POR ESTADO
PRINT '
--- DISTRIBUCIÓN POR ESTADO_PEDIDO ---';
SELECT
    estado_pedido,
    COUNT(*) as cantidad,
    SUM(monto_total) as monto_total_estado,
    SUM(monto_pagado) as monto_pagado_estado,
    SUM(saldo_pendiente) as saldo_pendiente_estado
FROM Ventas_Pedidos
GROUP BY estado_pedido
ORDER BY cantidad DESC;

-- 4. VALIDACIÓN MONTOS (Integridad: monto_total = monto_pagado + saldo_pendiente)
PRINT '
--- VALIDACIÓN MONTOS (Integridad) ---';
DECLARE @pedidos_sin_error INT = (
    SELECT COUNT(*) FROM Ventas_Pedidos
    WHERE ABS(monto_total - (monto_pagado + saldo_pendiente)) < 0.01
);
DECLARE @pedidos_con_error INT = (
    SELECT COUNT(*) FROM Ventas_Pedidos
    WHERE ABS(monto_total - (monto_pagado + saldo_pendiente)) >= 0.01
);
SELECT
    @pedidos_sin_error as pedidos_validados,
    @pedidos_con_error as pedidos_con_discrepancia,
    @pedidos_sin_error + @pedidos_con_error as total;

-- 5. CHECKPOINT PEDIDOS
PRINT '
--- CHECKPOINT PEDIDOS ---';
SELECT KeyName, LastValue FROM Etl_Checkpoints
WHERE KeyName LIKE '%order%'
ORDER BY KeyName;

-- 6. TOP 10 PEDIDOS POR MONTO
PRINT '
--- TOP 10 PEDIDOS (POR MONTO TOTAL) ---';
SELECT TOP 10
    id_pedido, numero_pedido, fecha_pedido,
    id_cliente, id_sucursal, monto_total,
    monto_pagado, saldo_pendiente, estado_pedido
FROM Ventas_Pedidos
ORDER BY monto_total DESC;

-- 7. RESUMEN FINAL
PRINT '
=== RESUMEN AUDITORÍA PEDIDOS ===';
DECLARE @total_pedidos INT = (SELECT COUNT(*) FROM Ventas_Pedidos);
DECLARE @monto_total_pedidos DECIMAL(18,4) = (SELECT SUM(monto_total) FROM Ventas_Pedidos);
DECLARE @monto_pagado_total DECIMAL(18,4) = (SELECT SUM(monto_pagado) FROM Ventas_Pedidos);
DECLARE @saldo_total DECIMAL(18,4) = (SELECT SUM(saldo_pendiente) FROM Ventas_Pedidos);

SELECT
    @total_pedidos as [Total Pedidos],
    @monto_total_pedidos as [Monto Total],
    @monto_pagado_total as [Monto Pagado],
    @saldo_total as [Saldo Pendiente];
