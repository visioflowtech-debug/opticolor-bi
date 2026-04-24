USE [db-opticolor-dw];
GO

PRINT '=== VALIDACIÓN FINAL RBAC FIX ===';
PRINT '';

-- Conteo de registros
PRINT 'CONTEO DE REGISTROS:';
SELECT 'Usuarios' AS tabla, COUNT(*) AS filas FROM Seguridad_Usuarios
UNION ALL SELECT 'Usuarios_Roles', COUNT(*) FROM Seguridad_Usuarios_Roles
UNION ALL SELECT 'Usuarios_Sucursales', COUNT(*) FROM Seguridad_Usuarios_Sucursales
UNION ALL SELECT 'Maestro_Sucursales (total)', COUNT(*) FROM Maestro_Sucursales
UNION ALL SELECT 'Maestro_Sucursales (comerciales)', COUNT(*) FROM Maestro_Sucursales WHERE es_comercial=1
ORDER BY tabla;

PRINT '';
PRINT 'VISTA RLS — SUCURSALES VISIBLES:';
SELECT
    email,
    nombre_rol,
    COUNT(DISTINCT id_sucursal) AS sucursales_visibles
FROM Vw_RLS_Sucursales
WHERE email IN (
    'visioflow.tech@gmail.com',
    'master.test@opticolor.com',
    'supervisor.test@opticolor.com'
)
GROUP BY email, nombre_rol
ORDER BY email;

PRINT '';
PRINT 'DETALLE DE SUPERVISOR TEST:';
SELECT
    email,
    nombre_rol,
    id_sucursal,
    nombre_sucursal,
    ciudad,
    estado
FROM Vw_RLS_Sucursales
WHERE email = 'supervisor.test@opticolor.com'
ORDER BY nombre_sucursal;

PRINT '';
PRINT 'USUARIOS DE PRUEBA EN VISTA ACCESOS:';
SELECT
    id_usuario,
    email,
    nombre_completo,
    nombre_rol,
    nivel_jerarquico
FROM Vw_Usuario_Accesos
WHERE email IN (
    'visioflow.tech@gmail.com',
    'master.test@opticolor.com',
    'supervisor.test@opticolor.com'
)
ORDER BY email;

PRINT '';
PRINT 'ESTRUCTURA ACTUALIZADA DE MAESTRO_SUCURSALES:';
SELECT TOP 5
    id_sucursal,
    nombre_sucursal,
    ciudad,
    estado,
    es_comercial,
    alias_excel
FROM Maestro_Sucursales
WHERE es_comercial = 1
ORDER BY id_sucursal;

PRINT '';
PRINT '✓ VALIDACIÓN COMPLETADA';
