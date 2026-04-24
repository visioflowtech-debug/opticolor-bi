-- ============================================================================
-- RBAC SETUP — OPTICOLOR BI VENEZUELA
-- Fecha: 23 Abril 2026 | Semana 3
-- Descripción: Configuración completa de roles, usuarios y RLS
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
-- 1.3 CREAR TABLA: Param_Sucursales_Directorio
-- ============================================================================
PRINT '=== 1.3 Creando tabla Param_Sucursales_Directorio ===';

-- Verificar si tabla existe y eliminarla
IF OBJECT_ID('[dbo].[Param_Sucursales_Directorio]', 'U') IS NOT NULL
BEGIN
    DROP TABLE [dbo].[Param_Sucursales_Directorio];
    PRINT 'Tabla anterior eliminada';
END;

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
GO

-- ============================================================================
-- 1.4 INSERTAR 103 SUCURSALES EN Param_Sucursales_Directorio
-- ============================================================================
PRINT '=== 1.4 Insertando 103 sucursales del directorio ===';

INSERT INTO [dbo].[Param_Sucursales_Directorio]
(id_sucursal, nombre, ciudad, estado, es_corporativo)
VALUES
(1,'Catia','CARACAS','MIRANDA',0),
(2,'Los Proceres','CARACAS','MIRANDA',0),
(3,'La Cascada','LOS TEQUES','MIRANDA',0),
(4,'Metrocenter 1','CARACAS','MIRANDA',0),
(5,'Metrocenter 2','CARACAS','MIRANDA',0),
(6,'Multiplaza','CARACAS','MIRANDA',0),
(7,'Candelaria Center','CARACAS','MIRANDA',0),
(8,'Sambil Candelaria Miranda','CARACAS','MIRANDA',0),
(9,'Sambil Candelaria AB','CARACAS','MIRANDA',0),
(10,'El Recreo','CARACAS','MIRANDA',0),
(11,'Expresso Chacaito','CARACAS','MIRANDA',0),
(12,'Millenium','CARACAS','MIRANDA',0),
(13,'Sambil Chacao Autopista','CARACAS','MIRANDA',0),
(14,'CC Líder','CARACAS','MIRANDA',0),
(15,'El Márquez','CARACAS','MIRANDA',0),
(16,'Petare','CARACAS','MIRANDA',0),
(17,'Caracas Outlet','CARACAS','MIRANDA',0),
(18,'Expresso Baruta','CARACAS','MIRANDA',0),
(19,'Traki Trinidad','CARACAS','MIRANDA',0),
(20,'El Hatillo','CARACAS','MIRANDA',0),
(21,'CCCT 2','CARACAS','MIRANDA',0),
(22,'San Ignacio','CARACAS','MIRANDA',0),
(23,'Sambil Chacao Feria','CARACAS','MIRANDA',0),
(24,'Sambil Chacao Libertador','CARACAS','MIRANDA',0),
(25,'CCCT 1','CARACAS','MIRANDA',0),
(26,'Cerro Verde 1','CARACAS','MIRANDA',0),
(27,'Cerro Verde 2','CARACAS','MIRANDA',0),
(28,'Tolon','CARACAS','MIRANDA',0),
(29,'La Guaira','LA GUAIRA','VARGAS',0),
(30,'Centro Lido','CARACAS','MIRANDA',0),
(31,'Forum Guarenas','GUARENAS','MIRANDA',0),
(32,'Forum Guarire','GUATIRE','MIRANDA',0),
(33,'Forum La Urbina','CARACAS','MIRANDA',0),
(34,'Forum San Bernardino','CARACAS','MIRANDA',0),
(35,'Calle Libertad','PUERTO LA CRUZ','ANZOATEGUI',0),
(36,'Puente Real','BARCELONA','ANZOATEGUI',0),
(37,'Cumaná','CUMANA','SUCRE',0),
(38,'Plaza Mayor','LECHERIA','ANZOATEGUI',0),
(39,'Las Olas Lecheria','LECHERIA','ANZOATEGUI',0),
(40,'La Vela','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(41,'Margarita City Place','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(42,'Sambil Margarita','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(43,'Oro','CIUDAD GUAYANA','BOLIVAR',0),
(44,'San Félix','SAN FELIX','BOLIVAR',0),
(45,'Alta Vista','CIUDAD GUAYANA','BOLIVAR',0),
(46,'SanTome','CIUDAD GUAYANA','BOLIVAR',0),
(47,'Acero','CIUDAD GUAYANA','BOLIVAR',0),
(48,'Aviadores 1','MARACAY','ARAGUA',0),
(49,'Aviadores Aeropuerto','MARACAY','ARAGUA',0),
(50,'Hyperjumbo','MARACAY','ARAGUA',0),
(51,'Las Américas','MARACAY','ARAGUA',0),
(52,'Parque Aragua','MARACAY','ARAGUA',0),
(53,'Galerías Plaza 1','MARACAY','ARAGUA',0),
(54,'Galerías Plaza 2','MARACAY','ARAGUA',0),
(55,'Estación Central','MARACAY','ARAGUA',0),
(56,'Unicentro','MARACAY','ARAGUA',0),
(57,'Metrópolis Valencia','VALENCIA','CARABOBO',0),
(58,'El Viñedo','VALENCIA','CARABOBO',0),
(59,'Sambil Valencia','VALENCIA','CARABOBO',0),
(60,'La Granja','VALENCIA','CARABOBO',0),
(61,'Traki Guacara','GUACARA','CARABOBO',0),
(62,'Traki Cabudare','CABUDARE','LARA',0),
(63,'Trinitarias','BARQUISIMETO','LARA',0),
(64,'Ciudad Crepuscular','BARQUISIMETO','LARA',0),
(65,'Metrópolis Barquisimeto','BARQUISIMETO','LARA',0),
(66,'Sambil Barquisimeto 2','BARQUISIMETO','LARA',0),
(67,'Sambil Barquisimeto 1','BARQUISIMETO','LARA',0),
(68,'Sambil Paraguaná 1','PUNTO FIJO','FALCON',0),
(69,'Sambil Paraguaná 2','PUNTO FIJO','FALCON',0),
(70,'Las Virtudes','PUNTO FIJO','FALCON',0),
(71,'Sambil San Cristóbal','SAN CRISTOBAL','TACHIRA',0),
(72,'Lago Mall','MARACAIBO','ZULIA',0),
(73,'MetroSol','MARACAIBO','ZULIA',0),
(74,'Chinita Plaza','MARACAIBO','ZULIA',0),
(75,'Chinita FDS','MARACAIBO','ZULIA',0),
(76,'Puente Cristal','MARACAIBO','ZULIA',0),
(77,'Caribe Zulia','MARACAIBO','ZULIA',0),
(78,'Cima','MARACAIBO','ZULIA',0),
(79,'Galerías Mall','MARACAIBO','ZULIA',0),
(80,'Gran Bazar','MARACAIBO','ZULIA',0),
(81,'Coromoto','SAN FRANCISCO','ZULIA',0),
(82,'Mall San Francisco','SAN FRANCISCO','ZULIA',0),
(83,'Traki Cabimas','CABIMAS','ZULIA',0),
(84,'Borgas','CABIMAS','ZULIA',0),
(85,'Terraza 77','MARACAIBO','ZULIA',0),
(86,'Mall Delicias','MARACAIBO','ZULIA',0),
(87,'Sambil Maracaibo','MARACAIBO','ZULIA',0),
(88,'Corporativo Caracas','CARACAS','MIRANDA',1),
(89,'Corporativo Zulia','MARACAIBO','ZULIA',1),
(90,'Corporativo Aragua','MARACAY','ARAGUA',1),
(91,'Corporativo Carabobo','VALENCIA','CARABOBO',1),
(92,'SOLE Tolon','CARACAS','MIRANDA',0),
(93,'Metrópolis Valencia 2','VALENCIA','LARA',0),
(94,'Metrópolis Barquisimeto 2','BARQUISIMETO','LARA',0),
(95,'Llano Mall','ACARIGUA','PORTUGUESA',0),
(96,'Forum Los Teques','LOS TEQUES','MIRANDA',0),
(97,'Forum Charallave','CARACAS','MIRANDA',0),
(98,'Forum La California','CARACAS','MIRANDA',0),
(99,'Forum San Martin','CARACAS','MIRANDA',0),
(100,'Forum Cagua','CAGUA','ARAGUA',0),
(101,'Forum Maturin 1','MATURIN','MONAGAS',0),
(102,'Forum Maturin 2','MATURIN','MONAGAS',0),
(103,'Forum Ciudad Bolívar','CIUDAD BOLIVAR','BOLIVAR',0);

PRINT 'Insertadas 103 sucursales ✓';
GO

-- ============================================================================
-- 1.5 INSERTAR 26 USUARIOS CON PASSWORD HASHEADO
-- ============================================================================
PRINT '=== 1.5 Insertando 26 usuarios (5 MASTER + 21 SUPERVISOR) ===';

-- Hash bcrypt de 'Opticolor2026!' con cost=10
DECLARE @password_hash NVARCHAR(255) = '$2b$10$GhPPhvEvRsUK3FK.BI3kQej2T1Q9iJMsn3JRXDnoGvUSuYgLoXW0u';

-- Habilitar IDENTITY_INSERT para insertar IDs explícitos
SET IDENTITY_INSERT Seguridad_Usuarios ON;

-- Insertar 5 usuarios MASTER
INSERT INTO Seguridad_Usuarios
(id_usuario, email, nombre_completo, password_hash, esta_activo, fecha_creacion, usuario_creacion)
VALUES
(2, 'gmartinez@grupoopticolor.com', 'GUSTAVO MARTINEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(3, 'jhernandez@grupoopticolor.com', 'JUNIELSY HERNANDEZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(4, 'rarangel@grupoopticolor.com', 'REINALDO A RANGEL', @password_hash, 1, GETUTCDATE(), 'sistema'),
(5, 'rrangel@grupoopticolor.com', 'REINALDO J RANGEL', @password_hash, 1, GETUTCDATE(), 'sistema'),
(6, 'emartinez@grupoopticolor.com', 'EDUARDO MARTINEZ', @password_hash, 1, GETUTCDATE(), 'sistema');

-- Insertar 21 usuarios SUPERVISOR
INSERT INTO Seguridad_Usuarios
(id_usuario, email, nombre_completo, password_hash, esta_activo, fecha_creacion, usuario_creacion)
VALUES
(7, 'hquintero@grupoopticolor.com', 'HERNAN QUINTERO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(8, 'malvarez@grupoopticolor.com', 'MARIA ALVAREZ', @password_hash, 1, GETUTCDATE(), 'sistema'),
(9, 'khurtado@grupoopticolor.com', 'KATHERIN HURTADO', @password_hash, 1, GETUTCDATE(), 'sistema'),
(10, 'bbolivar@opticolor.com.ve', 'BABARA BOLIVAR', @password_hash, 1, GETUTCDATE(), 'sistema'),
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

-- Limpiar asignaciones previas (si existen conflictos)
DELETE FROM Seguridad_Usuarios_Roles
WHERE id_usuario BETWEEN 2 AND 27;

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

-- 1 usuario SUPER_ADMIN (id_usuario 1 → id_rol 1) — actualizar si ya existe
UPDATE Seguridad_Usuarios_Roles
SET esta_vigente = 1
WHERE id_usuario = 1 AND id_rol = 1;

PRINT 'Roles asignados ✓';
GO

-- ============================================================================
-- 1.7 ASIGNAR SUCURSALES A SUPERVISORS EN Seguridad_Usuarios_Sucursales
-- ============================================================================
PRINT '=== 1.7 Asignando sucursales a supervisores ===';

-- Limpiar asignaciones anteriores (si existen)
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
PRINT '=== 1.8 Actualizar foreign key a Param_Sucursales_Directorio ===';

-- Obtener nombre del FK actual (si existe)
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

-- Crear FK nuevo apuntando a Param_Sucursales_Directorio
ALTER TABLE [dbo].[Seguridad_Usuarios_Sucursales]
ADD CONSTRAINT FK_Usuarios_Sucursales_Directorio
FOREIGN KEY (id_sucursal)
REFERENCES [dbo].[Param_Sucursales_Directorio] (id_sucursal);

PRINT 'FK nuevo creado: FK_Usuarios_Sucursales_Directorio ✓';
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

SELECT 'Roles' AS tabla, COUNT(*) AS filas FROM Seguridad_Roles
UNION ALL SELECT 'Usuarios', COUNT(*) FROM Seguridad_Usuarios
UNION ALL SELECT 'Directorio', COUNT(*) FROM Param_Sucursales_Directorio
UNION ALL SELECT 'Usuarios_Roles', COUNT(*) FROM Seguridad_Usuarios_Roles
UNION ALL SELECT 'Usuarios_Sucursales', COUNT(*) FROM Seguridad_Usuarios_Sucursales;

PRINT '';
PRINT '=== RESUMEN ===';
PRINT 'Roles esperados: 5 (SUPER_ADMIN, MASTER, SUPERVISOR, ETL_SERVICE, PORTAL_SERVICE)';
PRINT 'Usuarios esperados: 27 (1 SUPER_ADMIN + 5 MASTER + 21 SUPERVISOR)';
PRINT 'Directorio esperado: 103 sucursales';
PRINT 'Usuarios_Roles esperado: 27 asignaciones';
PRINT 'Usuarios_Sucursales esperado: 21 (solo SUPERVISOR tienen asignaciones)';
PRINT '';
PRINT '✓ SCRIPT RBAC SETUP COMPLETADO';
