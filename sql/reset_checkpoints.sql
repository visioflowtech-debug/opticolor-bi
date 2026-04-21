-- ============================================================
-- RESETEAR CHECKPOINTS - Opticolor Venezuela
-- Limpia estados de carga para permitir backfill completo
-- Fecha: 2026-04-21
-- ============================================================

PRINT '=== RESETEANDO CHECKPOINTS ==='

-- Mostrar checkpoints actuales
PRINT '--- Checkpoints ANTES de reset ---'
SELECT KeyName, LastValue FROM Etl_Checkpoints
ORDER BY KeyName

-- Limpiar todos los checkpoints
PRINT 'Eliminando todos los checkpoints...'
DELETE FROM Etl_Checkpoints
PRINT 'Checkpoints eliminados.'

-- Verificar
PRINT '--- Checkpoints DESPUÉS de reset ---'
SELECT KeyName, LastValue FROM Etl_Checkpoints

PRINT 'Reset de checkpoints completado exitosamente.'
