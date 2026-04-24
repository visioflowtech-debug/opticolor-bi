-- ============================================================================
-- RBAC FIX — ARQUITECTURA CORREGIDA V2
-- Fecha: 23 Abril 2026 | Semana 3
-- Descripción: Maestro_Sucursales (Gesvision) es única fuente de verdad
-- ============================================================================

USE [db-opticolor-dw];
GO

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║  RBAC FIX — ARQUITECTURA CORREGIDA V2 (10 TAREAS)             ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
GO

-- ============================================================================
-- TAREA 1: LIMPIAR Seguridad_Usuarios_Sucursales
-- ============================================================================
PRINT '';
PRINT '=== TAREA 1: Limpiar Seguridad_Usuarios_Sucursales ===';

DELETE FROM Seguridad_Usuarios_Sucursales;
PRINT CAST(@@ROWCOUNT AS NVARCHAR) + ' registros eliminados ✓';
GO

-- ============================================================================
-- TAREA 2: ELIMINAR Param_Sucursales_Directorio y su FK
-- ============================================================================
PRINT '';
PRINT '=== TAREA 2: Eliminar Param_Sucursales_Directorio ===';

-- Obtener nombre exacto del FK constraint
DECLARE @fk_name NVARCHAR(128);
SELECT @fk_name = fk.name
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.referenced_object_id) = 'Param_Sucursales_Directorio';

IF @fk_name IS NOT NULL
BEGIN
    DECLARE @sql_drop NVARCHAR(MAX) = 'ALTER TABLE Seguridad_Usuarios_Sucursales DROP CONSTRAINT [' + @fk_name + '];';
    EXECUTE sp_executesql @sql_drop;
    PRINT 'FK eliminado: ' + @fk_name + ' ✓';
END;

DROP TABLE IF EXISTS [dbo].[Param_Sucursales_Directorio];
PRINT 'Tabla Param_Sucursales_Directorio eliminada ✓';
GO

-- ============================================================================
-- TAREA 3: ENRIQUECER Maestro_Sucursales CON COLUMNAS NUEVAS
-- ============================================================================
PRINT '';
PRINT '=== TAREA 3: Enriquecer Maestro_Sucursales ===';

-- Agregar columnas faltantes (una por una, verificando existencia)
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Maestro_Sucursales' AND COLUMN_NAME='ciudad')
BEGIN
    ALTER TABLE Maestro_Sucursales ADD ciudad NVARCHAR(100) NULL;
    PRINT 'Columna ciudad agregada ✓';
END;

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Maestro_Sucursales' AND COLUMN_NAME='estado')
BEGIN
    ALTER TABLE Maestro_Sucursales ADD estado NVARCHAR(100) NULL;
    PRINT 'Columna estado agregada ✓';
END;

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Maestro_Sucursales' AND COLUMN_NAME='es_comercial')
BEGIN
    ALTER TABLE Maestro_Sucursales ADD es_comercial BIT NOT NULL DEFAULT 1;
    PRINT 'Columna es_comercial agregada ✓';
END;

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Maestro_Sucursales' AND COLUMN_NAME='alias_excel')
BEGIN
    ALTER TABLE Maestro_Sucursales ADD alias_excel NVARCHAR(150) NULL;
    PRINT 'Columna alias_excel agregada ✓';
END;

PRINT 'Todas las columnas están presentes ✓';
GO

-- ============================================================================
-- TAREA 3.2: ACTUALIZAR DATOS EN Maestro_Sucursales
-- ============================================================================
PRINT '';
PRINT '=== TAREA 3.2: Actualizar datos geográficos y comerciales ===';

-- Entidades internas (no son tiendas)
UPDATE Maestro_Sucursales SET es_comercial=0, ciudad='MARACAIBO', estado='ZULIA' WHERE id_sucursal=3;  -- ALMACEN
UPDATE Maestro_Sucursales SET es_comercial=0, ciudad='MARACAIBO', estado='ZULIA' WHERE id_sucursal=4;  -- LABORATORIO

-- Zulia - Maracaibo (14 sucursales)
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='PUENTE CRISTAL'        WHERE id_sucursal=1;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='CIMA'                  WHERE id_sucursal=2;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='SAMBIL MARACAIBO'      WHERE id_sucursal=5;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='BORGAS'                WHERE id_sucursal=6;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='CARIBE ZULIA'          WHERE id_sucursal=7;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='CHINITA FDS'           WHERE id_sucursal=8;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='CHINITA PLAZA'         WHERE id_sucursal=9;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='GALERIAS MALL'         WHERE id_sucursal=11;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='GRAN BAZAR'            WHERE id_sucursal=12;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='LAGO MALL'             WHERE id_sucursal=13;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='MALL DELICIAS'         WHERE id_sucursal=14;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='MALL SAN FRANCISCO'    WHERE id_sucursal=15;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='METROSOL'              WHERE id_sucursal=16;
UPDATE Maestro_Sucursales SET ciudad='MARACAIBO', estado='ZULIA', alias_excel='TERRAZA 77'            WHERE id_sucursal=18;

-- Zulia - San Francisco (1 sucursal)
UPDATE Maestro_Sucursales SET ciudad='SAN FRANCISCO', estado='ZULIA', alias_excel='COROMOTO'          WHERE id_sucursal=17;

-- Zulia - Cabimas (1 sucursal)
UPDATE Maestro_Sucursales SET ciudad='CABIMAS', estado='ZULIA', alias_excel='TRAKI CABIMAS'           WHERE id_sucursal=19;

-- Lara - Barquisimeto (5 sucursales)
UPDATE Maestro_Sucursales SET ciudad='BARQUISIMETO', estado='LARA', alias_excel='CIUDAD CREPUSCULAR'       WHERE id_sucursal=20;
UPDATE Maestro_Sucursales SET ciudad='BARQUISIMETO', estado='LARA', alias_excel='METROPOLIS BARQUISIMETO'  WHERE id_sucursal=22;
UPDATE Maestro_Sucursales SET ciudad='BARQUISIMETO', estado='LARA', alias_excel='SAMBIL BARQUISIMETO 1'    WHERE id_sucursal=23;
UPDATE Maestro_Sucursales SET ciudad='BARQUISIMETO', estado='LARA', alias_excel='SAMBIL BARQUISIMETO 2'    WHERE id_sucursal=24;
UPDATE Maestro_Sucursales SET ciudad='BARQUISIMETO', estado='LARA', alias_excel='TRINITARIAS'              WHERE id_sucursal=29;

-- Lara - Cabudare (1 sucursal)
UPDATE Maestro_Sucursales SET ciudad='CABUDARE', estado='LARA', alias_excel='TRAKI CABUDARE'           WHERE id_sucursal=28;

-- Falcón - Punto Fijo (3 sucursales)
UPDATE Maestro_Sucursales SET ciudad='PUNTO FIJO', estado='FALCON', alias_excel='LAS VIRTUDES'         WHERE id_sucursal=21;
UPDATE Maestro_Sucursales SET ciudad='PUNTO FIJO', estado='FALCON', alias_excel='SAMBIL PARAGUANA 1'   WHERE id_sucursal=25;
UPDATE Maestro_Sucursales SET ciudad='PUNTO FIJO', estado='FALCON', alias_excel='SAMBIL PARAGUANA 2'   WHERE id_sucursal=26;

-- Táchira - San Cristóbal (1 sucursal)
UPDATE Maestro_Sucursales SET ciudad='SAN CRISTOBAL', estado='TACHIRA', alias_excel='SAMBIL SAN CRISTOBAL' WHERE id_sucursal=27;

PRINT '26 sucursales comerciales enriquecidas ✓';
GO

-- Verificar estado actual
PRINT '';
PRINT 'Estado de Maestro_Sucursales:';
SELECT 'Total sucursales' AS tipo, COUNT(*) AS cantidad FROM Maestro_Sucursales
UNION ALL SELECT 'Comerciales', COUNT(*) FROM Maestro_Sucursales WHERE es_comercial=1
UNION ALL SELECT 'Internas', COUNT(*) FROM Maestro_Sucursales WHERE es_comercial=0;
GO

-- ============================================================================
-- TAREA 4: RESTAURAR FK hacia Maestro_Sucursales
-- ============================================================================
PRINT '';
PRINT '=== TAREA 4: Restaurar FK a Maestro_Sucursales ===';

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('Seguridad_Usuarios_Sucursales')
      AND referenced_object_id = OBJECT_ID('Maestro_Sucursales')
)
BEGIN
    ALTER TABLE Seguridad_Usuarios_Sucursales
    ADD CONSTRAINT FK_UsuariosSucursales_Maestro
    FOREIGN KEY (id_sucursal) REFERENCES Maestro_Sucursales(id_sucursal);
    PRINT 'FK_UsuariosSucursales_Maestro creado ✓';
END
ELSE
BEGIN
    PRINT 'FK ya existe ✓';
END;
GO

-- ============================================================================
-- TAREA 5: CREAR 2 USUARIOS DE PRUEBA
-- ============================================================================
PRINT '';
PRINT '=== TAREA 5: Insertar 2 usuarios de prueba ===';

DECLARE @hash_password NVARCHAR(255) = '$2b$10$SxxjGNFG8Z0EOud7mirugOI2U6lbFcK/HnmbSvz6lxQVpebpipDQO';

INSERT INTO Seguridad_Usuarios
    (email, nombre_completo, password_hash, esta_activo, usuario_creacion, fecha_creacion)
VALUES
('master.test@opticolor.com',
 'MASTER TEST',
 @hash_password,
 1, 'visioflow.tech@gmail.com', GETUTCDATE()),

('supervisor.test@opticolor.com',
 'SUPERVISOR TEST',
 @hash_password,
 1, 'visioflow.tech@gmail.com', GETUTCDATE());

PRINT '2 usuarios de prueba insertados ✓';
GO

-- ============================================================================
-- TAREA 5.3: ASIGNAR ROLES A USUARIOS DE PRUEBA
-- ============================================================================
PRINT '';
PRINT '=== TAREA 5.3: Asignar roles a usuarios de prueba ===';

INSERT INTO Seguridad_Usuarios_Roles (id_usuario, id_rol, fecha_asignacion, esta_vigente)
SELECT id_usuario, 2, GETUTCDATE(), 1
FROM Seguridad_Usuarios WHERE email = 'master.test@opticolor.com';

INSERT INTO Seguridad_Usuarios_Roles (id_usuario, id_rol, fecha_asignacion, esta_vigente)
SELECT id_usuario, 4, GETUTCDATE(), 1
FROM Seguridad_Usuarios WHERE email = 'supervisor.test@opticolor.com';

PRINT 'Roles asignados ✓';
GO

-- ============================================================================
-- TAREA 5.4: ASIGNAR SUCURSAL AL SUPERVISOR TEST
-- ============================================================================
PRINT '';
PRINT '=== TAREA 5.4: Asignar sucursal a SUPERVISOR TEST ===';

INSERT INTO Seguridad_Usuarios_Sucursales (id_usuario, id_sucursal, fecha_asignacion, esta_vigente)
SELECT id_usuario, 13, GETUTCDATE(), 1
FROM Seguridad_Usuarios WHERE email = 'supervisor.test@opticolor.com';

PRINT 'SUPERVISOR TEST asignado a LAGO MALL (id=13) ✓';
GO

-- ============================================================================
-- TAREA 6: RECREAR Vw_RLS_Sucursales
-- ============================================================================
PRINT '';
PRINT '=== TAREA 6: Recrear Vw_RLS_Sucursales ===';

DROP VIEW IF EXISTS [dbo].[Vw_RLS_Sucursales];
GO

CREATE VIEW [dbo].[Vw_RLS_Sucursales] AS

-- SUPER_ADMIN y MASTER: todas las sucursales comerciales
SELECT
    U.id_usuario,
    U.email,
    R.nombre_rol,
    M.id_sucursal,
    M.nombre_sucursal,
    M.ciudad,
    M.estado
FROM Seguridad_Usuarios U
INNER JOIN Seguridad_Usuarios_Roles UR ON UR.id_usuario = U.id_usuario AND UR.esta_vigente = 1
INNER JOIN Seguridad_Roles R ON R.id_rol = UR.id_rol AND R.nombre_rol IN ('SUPER_ADMIN', 'MASTER')
CROSS JOIN Maestro_Sucursales M
WHERE U.esta_activo = 1 AND M.es_comercial = 1

UNION ALL

-- SUPERVISOR: solo sucursales asignadas
SELECT
    U.id_usuario,
    U.email,
    R.nombre_rol,
    M.id_sucursal,
    M.nombre_sucursal,
    M.ciudad,
    M.estado
FROM Seguridad_Usuarios U
INNER JOIN Seguridad_Usuarios_Roles UR ON UR.id_usuario = U.id_usuario AND UR.esta_vigente = 1
INNER JOIN Seguridad_Roles R ON R.id_rol = UR.id_rol AND R.nombre_rol = 'SUPERVISOR'
INNER JOIN Seguridad_Usuarios_Sucursales US ON US.id_usuario = U.id_usuario AND US.esta_vigente = 1
INNER JOIN Maestro_Sucursales M ON M.id_sucursal = US.id_sucursal AND M.es_comercial = 1
WHERE U.esta_activo = 1;
GO

PRINT 'Vista Vw_RLS_Sucursales recreada ✓';
GO

-- ============================================================================
-- TAREA 7: RECREAR Vw_Usuario_Accesos
-- ============================================================================
PRINT '';
PRINT '=== TAREA 7: Recrear Vw_Usuario_Accesos ===';

DROP VIEW IF EXISTS [dbo].[Vw_Usuario_Accesos];
GO

CREATE VIEW [dbo].[Vw_Usuario_Accesos] AS
SELECT
    U.id_usuario,
    U.email,
    U.nombre_completo,
    U.password_hash,
    U.esta_activo,
    R.nombre_rol,
    R.nivel_jerarquico
FROM Seguridad_Usuarios U
INNER JOIN Seguridad_Usuarios_Roles UR ON UR.id_usuario = U.id_usuario AND UR.esta_vigente = 1
INNER JOIN Seguridad_Roles R ON R.id_rol = UR.id_rol
WHERE U.esta_activo = 1;
GO

PRINT 'Vista Vw_Usuario_Accesos recreada ✓';
GO

-- ============================================================================
-- TAREA 8: VERIFICACIÓN FINAL
-- ============================================================================
PRINT '';
PRINT '=== TAREA 8: Verificación Final ===';
PRINT '';

PRINT 'Conteo de registros:';
SELECT 'Usuarios' AS tabla, COUNT(*) AS filas FROM Seguridad_Usuarios
UNION ALL SELECT 'Usuarios_Roles', COUNT(*) FROM Seguridad_Usuarios_Roles
UNION ALL SELECT 'Usuarios_Sucursales', COUNT(*) FROM Seguridad_Usuarios_Sucursales
UNION ALL SELECT 'Maestro_Sucursales (total)', COUNT(*) FROM Maestro_Sucursales
UNION ALL SELECT 'Maestro_Sucursales (comerciales)', COUNT(*) FROM Maestro_Sucursales WHERE es_comercial=1;

PRINT '';
PRINT 'Conteo esperado: Usuarios=29, Usuarios_Roles=28, Usuarios_Sucursales=1, total=28, comerciales=26';

PRINT '';
PRINT 'Test de vista RLS (sucursales visibles por usuario):';
SELECT
    email,
    nombre_rol,
    COUNT(*) AS sucursales_visibles
FROM Vw_RLS_Sucursales
WHERE email IN (
    'visioflow.tech@gmail.com',
    'master.test@opticolor.com',
    'supervisor.test@opticolor.com'
)
GROUP BY email, nombre_rol
ORDER BY email;

PRINT '';
PRINT 'Esperado:';
PRINT '  visioflow.tech@gmail.com       → SUPER_ADMIN → 26 sucursales';
PRINT '  master.test@opticolor.com      → MASTER      → 26 sucursales';
PRINT '  supervisor.test@opticolor.com  → SUPERVISOR  →  1 sucursal (LAGO MALL)';

PRINT '';
PRINT 'Detalle de SUPERVISOR TEST (verificar asignación):';
SELECT email, nombre_rol, nombre_sucursal, ciudad, estado
FROM Vw_RLS_Sucursales
WHERE email = 'supervisor.test@opticolor.com'
ORDER BY nombre_sucursal;

PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║  ✓ RBAC FIX V2 COMPLETADO EXITOSAMENTE                        ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
