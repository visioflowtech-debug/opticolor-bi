-- ============================================================================
-- RBAC SETUP V2 — OPTICOLOR BI VENEZUELA (IDEMPOTENTE)
-- Fecha: 23 Abril 2026 | Semana 3
-- Descripción: Configuración completa de roles, usuarios y RLS
-- Versión 2: Maneja objetos existentes sin dropar
-- ============================================================================

USE [db-opticolor-dw];
GO

-- ============================================================================
-- 1.1 LIMPIAR ROLES OBSOLETOS
-- ============================================================================
PRINT '=== 1.1 Eliminando roles obsoletos (GERENTE_ZONA, CONSULTOR) ===';

DELETE FROM Seguridad_Roles_Permisos WHERE id_rol IN (3, 5);
DELETE FROM Seguridad_Usuarios_Roles WHERE id_rol IN (3, 5);
DELETE FROM Seguridad_Roles WHERE id_rol IN (3, 5);

PRINT 'Roles obsoletos eliminados ✓';
GO

-- ============================================================================
-- 1.2 ACTUALIZAR ROL ADMIN → MASTER
-- ============================================================================
PRINT '=== 1.2 Renombrando ADMIN a MASTER ===';

UPDATE Seguridad_Roles
SET nombre_rol = 'MASTER',
    descripcion = 'Acceso total — todas las sucursales Opticolor',
    nivel_jerarquico = 2
WHERE id_rol = 2;

PRINT 'Rol ADMIN renombrado a MASTER ✓';
GO

-- ============================================================================
-- 1.3 CREAR O VACIAR TABLA: Param_Sucursales_Directorio
-- ============================================================================
PRINT '=== 1.3 Preparando tabla Param_Sucursales_Directorio ===';

-- Si la tabla NO existe, crearla
IF OBJECT_ID('[dbo].[Param_Sucursales_Directorio]', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Param_Sucursales_Directorio] (
        id_sucursal           INT            NOT NULL PRIMARY KEY,
        nombre                NVARCHAR(150)  NOT NULL,
        ciudad                NVARCHAR(100)  NULL,
        estado                NVARCHAR(100)  NULL,
        es_corporativo        BIT            NULL DEFAULT 0,
        esta_activo           BIT            NULL DEFAULT 1,
        fecha_carga           DATETIME2      NULL DEFAULT GETUTCDATE()
    );
    PRINT 'Tabla Param_Sucursales_Directorio creada ✓';
END
ELSE
BEGIN
    -- Si existe, vaciar datos existentes
    DELETE FROM [dbo].[Param_Sucursales_Directorio];
    PRINT 'Tabla Param_Sucursales_Directorio vaciada ✓';
END;
GO

-- ============================================================================
-- 1.4 INSERTAR 103 SUCURSALES EN Param_Sucursales_Directorio
-- ============================================================================
PRINT '=== 1.4 Insertando 103 sucursales del directorio ===';

INSERT INTO [dbo].[Param_Sucursales_Directorio]
(id_sucursal, nombre, ciudad, estado, es_corporativo)
VALUES
(1,'CATIA','CARACAS','MIRANDA',0),
(2,'LOS PROCERES','CARACAS','MIRANDA',0),
(3,'LA CASCADA','LOS TEQUES','MIRANDA',0),
(4,'METROCENTER 1','CARACAS','MIRANDA',0),
(5,'METROCENTER 2','CARACAS','MIRANDA',0),
(6,'MULTIPLAZA','CARACAS','MIRANDA',0),
(7,'CANDELARIA CENTER','CARACAS','MIRANDA',0),
(8,'SAMBIL CANDELARIA MIRANDA','CARACAS','MIRANDA',0),
(9,'SAMBIL CANDELARIA AB','CARACAS','MIRANDA',0),
(10,'EL RECREO','CARACAS','MIRANDA',0),
(11,'EXPRESSO CHACAITO','CARACAS','MIRANDA',0),
(12,'MILLENIUM','CARACAS','MIRANDA',0),
(13,'SAMBIL CHACAO AUTOPISTA','CARACAS','MIRANDA',0),
(14,'CC LIDER','CARACAS','MIRANDA',0),
(15,'EL MARQUEZ','CARACAS','MIRANDA',0),
(16,'PETARE','CARACAS','MIRANDA',0),
(17,'CARACAS OUTLET','CARACAS','MIRANDA',0),
(18,'EXPRESSO BARUTA','CARACAS','MIRANDA',0),
(19,'TRAKI TRINIDAD','CARACAS','MIRANDA',0),
(20,'EL HATILLO','CARACAS','MIRANDA',0),
(21,'CCCT 2','CARACAS','MIRANDA',0),
(22,'SAN IGNACIO','CARACAS','MIRANDA',0),
(23,'SAMBIL CHACAO FERIA','CARACAS','MIRANDA',0),
(24,'SAMBIL CHACAO LIBERTADOR','CARACAS','MIRANDA',0),
(25,'CCCT 1','CARACAS','MIRANDA',0),
(26,'CERRO VERDE 1','CARACAS','MIRANDA',0),
(27,'CERRO VERDE 2','CARACAS','MIRANDA',0),
(28,'TOLON','CARACAS','MIRANDA',0),
(29,'LA GUAIRA','LA GUAIRA','VARGAS',0),
(30,'CENTRO LIDO','CARACAS','MIRANDA',0),
(31,'FORUM GUARENAS','GUARENAS','MIRANDA',0),
(32,'FORUM GUARIRE','GUATIRE','MIRANDA',0),
(33,'FORUM LA URBINA','CARACAS','MIRANDA',0),
(34,'FORUM SAN BERNARDINO','CARACAS','MIRANDA',0),
(35,'CALLE LIBERTAD','PUERTO LA CRUZ','ANZOATEGUI',0),
(36,'PUENTE REAL','BARCELONA','ANZOATEGUI',0),
(37,'CUMANA','CUMANA','SUCRE',0),
(38,'PLAZA MAYOR','LECHERIA','ANZOATEGUI',0),
(39,'LAS OLAS LECHERIA','LECHERIA','ANZOATEGUI',0),
(40,'LA VELA','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(41,'MARGARITA CITY PLACE','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(42,'SAMBIL MARGARITA','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(43,'ORO','CIUDAD GUAYANA','BOLIVAR',0),
(44,'SAN FELIX','SAN FELIX','BOLIVAR',0),
(45,'ALTA VISTA','CIUDAD GUAYANA','BOLIVAR',0),
(46,'SANTOME','CIUDAD GUAYANA','BOLIVAR',0),
(47,'ACERO','CIUDAD GUAYANA','BOLIVAR',0),
(48,'AVIADORES 1','MARACAY','ARAGUA',0),
(49,'AVIADORES AEROPUERTO','MARACAY','ARAGUA',0),
(50,'HYPERJUMBO','MARACAY','ARAGUA',0),
(51,'LAS AMERICAS','MARACAY','ARAGUA',0),
(52,'PARQUE ARAGUA','MARACAY','ARAGUA',0),
(53,'GALERIAS PLAZA 1','MARACAY','ARAGUA',0),
(54,'GALERIAS PLAZA 2','MARACAY','ARAGUA',0),
(55,'ESTACION CENTRAL','MARACAY','ARAGUA',0),
(56,'UNICENTRO','MARACAY','ARAGUA',0),
(57,'METROPOLIS VALENCIA','VALENCIA','CARABOBO',0),
(58,'EL VINEDO','VALENCIA','CARABOBO',0),
(59,'SAMBIL VALENCIA','VALENCIA','CARABOBO',0),
(60,'LA GRANJA','VALENCIA','CARABOBO',0),
(61,'TRAKI GUACARA','GUACARA','CARABOBO',0),
(62,'TRAKI CABUDARE','CABUDARE','LARA',0),
(63,'TRINITARIAS','BARQUISIMETO','LARA',0),
(64,'CIUDAD CREPUSCULAR','BARQUISIMETO','LARA',0),
(65,'METROPOLIS BARQUISIMETO','BARQUISIMETO','LARA',0),
(66,'SAMBIL BARQUISIMETO 2','BARQUISIMETO','LARA',0),
(67,'SAMBIL BARQUISIMETO 1','BARQUISIMETO','LARA',0),
(68,'SAMBIL PARAGUANA 1','PUNTO FIJO','FALCON',0),
(69,'SAMBIL PARAGUANA 2','PUNTO FIJO','FALCON',0),
(70,'LAS VIRTUDES','PUNTO FIJO','FALCON',0),
(71,'SAMBIL SAN CRISTOBAL','SAN CRISTOBAL','TACHIRA',0),
(72,'LAGO MALL','MARACAIBO','ZULIA',0),
(73,'METROSOL','MARACAIBO','ZULIA',0),
(74,'CHINITA PLAZA','MARACAIBO','ZULIA',0),
(75,'CHINITA FDS','MARACAIBO','ZULIA',0),
(76,'PUENTE CRISTAL','MARACAIBO','ZULIA',0),
(77,'CARIBE ZULIA','MARACAIBO','ZULIA',0),
(78,'CIMA','MARACAIBO','ZULIA',0),
(79,'GALERIAS MALL','MARACAIBO','ZULIA',0),
(80,'GRAN BAZAR','MARACAIBO','ZULIA',0),
(81,'COROMOTO','SAN FRANCISCO','ZULIA',0),
(82,'MALL SAN FRANCISCO','SAN FRANCISCO','ZULIA',0),
(83,'TRAKI CABIMAS','CABIMAS','ZULIA',0),
(84,'BORGAS','CABIMAS','ZULIA',0),
(85,'TERRAZA 77','MARACAIBO','ZULIA',0),
(86,'MALL DELICIAS','MARACAIBO','ZULIA',0),
(87,'SAMBIL MARACAIBO','MARACAIBO','ZULIA',0),
(88,'CORPORATIVO CARACAS','CARACAS','MIRANDA',1),
(89,'CORPORATIVO ZULIA','MARACAIBO','ZULIA',1),
(90,'CORPORATIVO ARAGUA','MARACAY','ARAGUA',1),
(91,'CORPORATIVO CARABOBO','VALENCIA','CARABOBO',1),
(92,'SOLE TOLON','CARACAS','MIRANDA',0),
(93,'METROPOLIS VALENCIA 2','VALENCIA','LARA',0),
(94,'METROPOLIS BARQUISIMETO 2','BARQUISIMETO','LARA',0),
(95,'LLANO MALL','ACARIGUA','PORTUGUESA',0),
(96,'FORUM LOS TEQUES','LOS TEQUES','MIRANDA',0),
(97,'FORUM CHARALLAVE','CARACAS','MIRANDA',0),
(98,'FORUM LA CALIFORNIA','CARACAS','MIRANDA',0),
(99,'FORUM SAN MARTIN','CARACAS','MIRANDA',0),
(100,'FORUM CAGUA','CAGUA','ARAGUA',0),
(101,'FORUM MATURIN 1','MATURIN','MONAGAS',0),
(102,'FORUM MATURIN 2','MATURIN','MONAGAS',0),
(103,'FORUM CIUDAD BOLIVAR','CIUDAD BOLIVAR','BOLIVAR',0);

PRINT 'Insertadas 103 sucursales ✓';
GO

-- ============================================================================
-- 1.5 INSERTAR 26 USUARIOS CON PASSWORD HASHEADO
-- ============================================================================
PRINT '=== 1.5 Insertando 26 usuarios (5 MASTER + 21 SUPERVISOR) ===';

DECLARE @password_hash NVARCHAR(255) = '$2b$10$GhPPhvEvRsUK3FK.BI3kQej2T1Q9iJMsn3JRXDnoGvUSuYgLoXW0u';

-- Limpiar usuarios existentes (excepto SUPER_ADMIN id=1)
DELETE FROM Seguridad_Usuarios WHERE id_usuario > 1;

-- Habilitar IDENTITY_INSERT para insertar IDs explícitos
SET IDENTITY_INSERT Seguridad_Usuarios ON;

-- Insertar 5 usuarios MASTER
INSERT INTO Seguridad_Usuarios
(id_usuario, email, nombre_completo, password_hash, esta_activo, fecha_creacion, usuario_creacion)
VALUES
(2, 'gmartinez@grupoopticolor.com', 'GUSTAVO MARTINEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(3, 'jhernandez@grupoopticolor.com', 'JUNIELSY HERNANDEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(4, 'rarangel@grupoopticolor.com', 'REINALDO A. RANGEL', @password_hash, 1, GETUTCDATE(), 'sistema'),
(5, 'rrangel@grupoopticolor.com', 'REINALDO J. RANGEL', @password_hash, 1, GETUTCDATE(), 'sistema'),
(6, 'emartinez@grupoopticolor.com', 'EDUARDO MARTINEZ', @password_hash, 1, GETUTCDATE(), 'sistema');

-- Insertar 21 usuarios SUPERVISOR
INSERT INTO Seguridad_Usuarios
(id_usuario, email, nombre_completo, password_hash, esta_activo, fecha_creacion, usuario_creacion)
VALUES
(7, 'hquintero@grupoopticolor.com', 'HERNAN QUINTERO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(8, 'malvarez@grupoopticolor.com', 'MARIA ALVAREZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(9, 'khurtado@grupoopticolor.com', 'KATHERIN HURTADO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(10, 'bbolivar@opticolor.com.ve', 'BARBARA BOLIVAR', @password_hash, 1, GETUTCDATE(), 'sistema'),
(11, 'egarcia@opticolor.com.ve', 'EDITH GARCIA', @password_hash, 1, GETUTCDATE(), 'sistema'),
(12, 'jsoto@grupoopticolor.com', 'JOSE SOTO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(13, 'rpina@opticolor.com.ve', 'ROSAIDA PINA', @password_hash, 1, GETUTCDATE(), 'sistema'),
(14, 'kjimenez@grupoopticolor.com', 'KARLA JIMENEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(15, 'ytadino@opticolor.com.ve', 'YOLIBERT TADINO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(16, 'yanez@grupoopticolor.com', 'JENNY ANEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(17, 'arodriguez@grupoopticolor.com', 'ADELAIDA RODRIGUEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(18, 'kgarcia@grupoopticolor.com', 'KERVIN GARCIA', @password_hash, 1, GETUTCDATE(), 'sistema'),
(19, 'yrodriguez@grupoopticolor.com', 'YASMIRA RODRIGUEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(20, 'vaponte@grupoopticolor.com', 'VICKY APONTE', @password_hash, 1, GETUTCDATE(), 'sistema'),
(21, 'lvillarroel@grupoopticolor.com', 'LANYEINY VILLARROEL', @password_hash, 1, GETUTCDATE(), 'sistema'),
(22, 'janez@grupoopticolor.com', 'JOANGEL ANEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(23, 'wcaballero@grupoopticolor.com', 'WILFREDO CABALLERO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(24, 'kcastillo@croven.com.ve', 'KENNITH CASTILLO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(25, 'ymoreno@opticolor.com.ve', 'YILBERT MORENO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(26, 'oherrera@grupoopticolor.com', 'OHAMBRA HERRERA', @password_hash, 1, GETUTCDATE(), 'sistema'),
(27, 'egonzalez@grupoopticolor.com', 'EDMAIRA GONZALEZ', @password_hash, 1, GETUTCDATE(), 'sistema');

-- Deshabilitar IDENTITY_INSERT después de insertar
SET IDENTITY_INSERT Seguridad_Usuarios OFF;

PRINT 'Insertados 26 usuarios ✓';
GO

-- ============================================================================
-- 1.6 ASIGNAR ROLES EN Seguridad_Usuarios_Roles
-- ============================================================================
PRINT '=== 1.6 Asignando roles a usuarios ===';

-- Limpiar asignaciones previas (todos excepto SUPER_ADMIN)
DELETE FROM Seguridad_Usuarios_Roles WHERE id_usuario > 1;

-- 5 usuarios MASTER (id_usuario 2-6 → id_rol 2)
INSERT INTO Seguridad_Usuarios_Roles
(id_usuario, id_rol, fecha_asignacion, esta_vigente)
VALUES
(2, 2, GETUTCDATE(), 1),
(3, 2, GETUTCDATE(), 1),
(4, 2, GETUTCDATE(), 1),
(5, 2, GETUTCDATE(), 1),
(6, 2, GETUTCDATE(), 1);

-- 21 usuarios SUPERVISOR (id_usuario 7-27 → id_rol 4)
INSERT INTO Seguridad_Usuarios_Roles
(id_usuario, id_rol, fecha_asignacion, esta_vigente)
SELECT id_usuario, 4, GETUTCDATE(), 1
FROM Seguridad_Usuarios
WHERE id_usuario BETWEEN 7 AND 27;

-- SUPER_ADMIN (id_usuario 1 → id_rol 1) — asegurar que existe
IF NOT EXISTS (SELECT 1 FROM Seguridad_Usuarios_Roles WHERE id_usuario = 1 AND id_rol = 1)
BEGIN
    INSERT INTO Seguridad_Usuarios_Roles
    (id_usuario, id_rol, fecha_asignacion, esta_vigente)
    VALUES (1, 1, GETUTCDATE(), 1);
END;

PRINT 'Roles asignados ✓';
GO

-- ============================================================================
-- 1.7 ASIGNAR SUCURSALES A SUPERVISORS EN Seguridad_Usuarios_Sucursales
-- ============================================================================
PRINT '=== 1.7 Asignando sucursales a supervisores ===';

-- Limpiar asignaciones anteriores (excepto usuarios no supervisores)
DELETE FROM Seguridad_Usuarios_Sucursales
WHERE id_usuario BETWEEN 7 AND 27;

-- Insertar asignaciones supervisor → sucursal
INSERT INTO Seguridad_Usuarios_Sucursales
(id_usuario, id_sucursal, fecha_asignacion, esta_vigente)
VALUES
(7, 2, GETUTCDATE(), 1),     -- HERNAN QUINTERO → sucursal 2
(8, 3, GETUTCDATE(), 1),     -- MARIA ALVAREZ → sucursal 3
(9, 8, GETUTCDATE(), 1),     -- KATHERIN HURTADO → sucursal 8
(10, 9, GETUTCDATE(), 1),    -- BABARA BOLIVAR → sucursal 9
(11, 10, GETUTCDATE(), 1),   -- EDITH GARCIA → sucursal 10
(12, 11, GETUTCDATE(), 1),   -- JOSE SOTO → sucursal 11
(13, 12, GETUTCDATE(), 1),   -- ROSAIDA PINA → sucursal 12
(14, 13, GETUTCDATE(), 1),   -- KARLA JIMENEZ → sucursal 13
(15, 14, GETUTCDATE(), 1),   -- YOLIBERT TADINO → sucursal 14
(16, 15, GETUTCDATE(), 1),   -- JENNY ANEZ → sucursal 15
(17, 16, GETUTCDATE(), 1),   -- ADELAIDA RODRIGUEZ → sucursal 16
(18, 17, GETUTCDATE(), 1),   -- KERVIN GARCIA → sucursal 17
(19, 18, GETUTCDATE(), 1),   -- YASMIRA RODRIGUEZ → sucursal 18
(20, 19, GETUTCDATE(), 1),   -- VICKY APONTE → sucursal 19
(21, 20, GETUTCDATE(), 1),   -- LANYEINY VILLARROEL → sucursal 20
(22, 21, GETUTCDATE(), 1),   -- JOANGEL ANEZ → sucursal 21
(23, 22, GETUTCDATE(), 1),   -- WILFREDO CABALLERO → sucursal 22
(24, 23, GETUTCDATE(), 1),   -- KENNITH CASTILLO → sucursal 23
(25, 24, GETUTCDATE(), 1),   -- YILBERT MORENO → sucursal 24
(26, 25, GETUTCDATE(), 1),   -- OHAMBRA HERRERA → sucursal 25
(27, 26, GETUTCDATE(), 1);   -- EDMAIRA GONZALEZ → sucursal 26

PRINT 'Sucursales asignadas a supervisores ✓';
GO

-- ============================================================================
-- 1.8 ACTUALIZAR FK EN Seguridad_Usuarios_Sucursales
-- ============================================================================
PRINT '=== 1.8 Gestionar foreign key a Param_Sucursales_Directorio ===';

-- Obtener nombre del FK actual que apunta a Maestro_Sucursales
DECLARE @fk_name NVARCHAR(128);
SELECT @fk_name = name FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID('Seguridad_Usuarios_Sucursales')
  AND referenced_object_id = OBJECT_ID('Maestro_Sucursales');

-- Eliminar FK viejo si existe
IF @fk_name IS NOT NULL
BEGIN
    DECLARE @sql_drop NVARCHAR(MAX) = 'ALTER TABLE [dbo].[Seguridad_Usuarios_Sucursales] DROP CONSTRAINT [' + @fk_name + '];';
    EXECUTE sp_executesql @sql_drop;
    PRINT 'FK anterior eliminado: ' + @fk_name;
END;

-- Crear FK nuevo apuntando a Param_Sucursales_Directorio (solo si no existe)
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('Seguridad_Usuarios_Sucursales')
      AND referenced_object_id = OBJECT_ID('Param_Sucursales_Directorio')
)
BEGIN
    ALTER TABLE [dbo].[Seguridad_Usuarios_Sucursales]
    ADD CONSTRAINT FK_Usuarios_Sucursales_Directorio
    FOREIGN KEY (id_sucursal)
    REFERENCES [dbo].[Param_Sucursales_Directorio] (id_sucursal);
    PRINT 'FK nuevo creado: FK_Usuarios_Sucursales_Directorio ✓';
END;
GO

-- ============================================================================
-- 1.9 RECREAR VISTA: Vw_RLS_Sucursales
-- ============================================================================
PRINT '=== 1.9 Recreando vista Vw_RLS_Sucursales ===';

IF OBJECT_ID('dbo.Vw_RLS_Sucursales', 'V') IS NOT NULL
    DROP VIEW dbo.Vw_RLS_Sucursales;
GO

CREATE VIEW [dbo].[Vw_RLS_Sucursales] AS
-- BLOQUE 1: SUPER_ADMIN y MASTER (acceso a TODAS las sucursales)
SELECT DISTINCT
    u.id_usuario,
    u.email,
    r.nombre_rol,
    d.id_sucursal,
    d.nombre,
    d.ciudad,
    d.estado,
    d.es_corporativo
FROM Seguridad_Usuarios u
INNER JOIN Seguridad_Usuarios_Roles ur ON u.id_usuario = ur.id_usuario
INNER JOIN Seguridad_Roles r ON ur.id_rol = r.id_rol
CROSS JOIN Param_Sucursales_Directorio d
WHERE ur.esta_vigente = 1
  AND u.esta_activo = 1
  AND r.nombre_rol IN ('SUPER_ADMIN', 'MASTER')
  AND d.esta_activo = 1

UNION ALL

-- BLOQUE 2: SUPERVISOR (acceso solo a sucursales asignadas)
SELECT DISTINCT
    u.id_usuario,
    u.email,
    r.nombre_rol,
    d.id_sucursal,
    d.nombre,
    d.ciudad,
    d.estado,
    d.es_corporativo
FROM Seguridad_Usuarios u
INNER JOIN Seguridad_Usuarios_Roles ur ON u.id_usuario = ur.id_usuario
INNER JOIN Seguridad_Roles r ON ur.id_rol = r.id_rol
INNER JOIN Seguridad_Usuarios_Sucursales us ON u.id_usuario = us.id_usuario
INNER JOIN Param_Sucursales_Directorio d ON us.id_sucursal = d.id_sucursal
WHERE ur.esta_vigente = 1
  AND us.esta_vigente = 1
  AND u.esta_activo = 1
  AND r.nombre_rol = 'SUPERVISOR'
  AND d.esta_activo = 1;

GO
PRINT 'Vista Vw_RLS_Sucursales recreada ✓';
GO

-- ============================================================================
-- 1.10 RECREAR VISTA: Vw_Usuario_Accesos (para NextAuth)
-- ============================================================================
PRINT '=== 1.10 Recreando vista Vw_Usuario_Accesos ===';

IF OBJECT_ID('dbo.Vw_Usuario_Accesos', 'V') IS NOT NULL
    DROP VIEW dbo.Vw_Usuario_Accesos;
GO

CREATE VIEW [dbo].[Vw_Usuario_Accesos] AS
SELECT
    u.id_usuario,
    u.email,
    u.nombre_completo,
    u.password_hash,
    u.esta_activo,
    r.nombre_rol,
    r.nivel_jerarquico
FROM Seguridad_Usuarios u
LEFT JOIN Seguridad_Usuarios_Roles ur ON u.id_usuario = ur.id_usuario AND ur.esta_vigente = 1
LEFT JOIN Seguridad_Roles r ON ur.id_rol = r.id_rol
WHERE u.esta_activo = 1;

GO
PRINT 'Vista Vw_Usuario_Accesos recreada ✓';
GO

-- ============================================================================
-- 1.11 VERIFICACIÓN POST-EJECUCIÓN
-- ============================================================================
PRINT '=== 1.11 VERIFICACIÓN FINAL ===';
PRINT '';

SELECT 'Roles' AS tabla, COUNT(*) AS filas FROM Seguridad_Roles
UNION ALL SELECT 'Usuarios', COUNT(*) FROM Seguridad_Usuarios
UNION ALL SELECT 'Directorio', COUNT(*) FROM Param_Sucursales_Directorio
UNION ALL SELECT 'Usuarios_Roles', COUNT(*) FROM Seguridad_Usuarios_Roles
UNION ALL SELECT 'Usuarios_Sucursales', COUNT(*) FROM Seguridad_Usuarios_Sucursales;

PRINT '';
PRINT '=== RESUMEN ESPERADO ===';
PRINT 'Roles: 5 (SUPER_ADMIN, MASTER, SUPERVISOR, ETL_SERVICE, PORTAL_SERVICE)';
PRINT 'Usuarios: 27 (1 SUPER_ADMIN + 5 MASTER + 21 SUPERVISOR)';
PRINT 'Directorio: 103 sucursales';
PRINT 'Usuarios_Roles: 27 asignaciones';
PRINT 'Usuarios_Sucursales: 21 (solo SUPERVISOR)';
PRINT '';
PRINT '✓ SCRIPT RBAC SETUP V2 COMPLETADO';
