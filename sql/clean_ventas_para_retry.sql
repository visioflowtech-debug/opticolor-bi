-- ============================================================
-- LIMPIAR TABLAS DE VENTAS PARA RETRY
-- Opticolor Venezuela - 2026-04-21
-- ============================================================

PRINT '=== LIMPIEZA DE TABLAS DE VENTAS PARA RETRY ==='

-- 1. LIMPIAR Ventas_Detalle (primero por FK)
PRINT 'Eliminando registros de Ventas_Detalle...'
DELETE FROM Ventas_Detalle
PRINT 'Ventas_Detalle vaciada.'

-- 2. LIMPIAR Ventas_Cabecera
PRINT 'Eliminando registros de Ventas_Cabecera...'
DELETE FROM Ventas_Cabecera
PRINT 'Ventas_Cabecera vaciada.'

-- 3. VERIFICAR
PRINT '=== VERIFICACIÓN FINAL ==='
SELECT 'Ventas_Cabecera' AS tabla, COUNT(*) AS registros FROM Ventas_Cabecera
UNION ALL
SELECT 'Ventas_Detalle' AS tabla, COUNT(*) AS registros FROM Ventas_Detalle

PRINT 'Limpieza completada exitosamente.'
