-- ============================================================
-- RESET COMPLETO PARA PRODUCTOS - Opticolor Venezuela
-- Limpia tabla + checkpoint para hacer backfill desde CERO
-- Fecha: 2026-04-21
-- ============================================================

PRINT '=== RESET COMPLETO PARA PRODUCTOS ==='

-- 1. Limpiar tabla Maestro_Productos
PRINT 'Eliminando registros de Maestro_Productos...'
DELETE FROM Maestro_Productos
PRINT 'Maestro_Productos vaciada.'

-- 2. Limpiar checkpoint
PRINT 'Eliminando checkpoint de PRODUCTOS...'
DELETE FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_products_skip'
PRINT 'Checkpoint eliminado.'

-- 3. Verificar
PRINT '=== VERIFICACIÓN FINAL ==='
SELECT 'Maestro_Productos' AS tabla, COUNT(*) AS registros FROM Maestro_Productos
UNION ALL
SELECT 'Checkpoint', COUNT(*) AS registros FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_products_skip'

PRINT 'Reset completo de PRODUCTOS finalizado.'
