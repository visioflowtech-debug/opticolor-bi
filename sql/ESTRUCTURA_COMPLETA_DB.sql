-- ============================================================================
-- ESTRUCTURA COMPLETA DE LA BASE DE DATOS OPTICOLOR BI VENEZUELA
-- Generada: 23 de Abril de 2026
-- Propósito: Referencia completa para desarrollo de vistas y consultas
-- ============================================================================

-- ============================================================================
-- SECCIÓN 1: TABLAS MAESTRO (8 tablas)
-- ============================================================================

-- Maestro_Sucursales
-- Dimensión de sucursales/locales de Opticolor
-- Registros: 5
CREATE TABLE Maestro_Sucursales (
    id_sucursal INT PRIMARY KEY,
    nombre_sucursal NVARCHAR(MAX),
    nombre_comercial NVARCHAR(MAX),
    direccion_exacta NVARCHAR(MAX),
    localidad NVARCHAR(MAX),
    municipio_raw NVARCHAR(MAX),
    municipio NVARCHAR(MAX),
    estado NVARCHAR(MAX),
    capital_estado NVARCHAR(MAX),
    region_administrativa NVARCHAR(MAX),
    pais VARCHAR(MAX),
    latitud DECIMAL,
    longitud DECIMAL,
    poblacion_municipal INT,
    id_estado INT,
    codigo_ine VARCHAR(MAX),
    nombre_estado NVARCHAR(MAX),
    nombre_capital NVARCHAR(MAX),
    region_administrativa NVARCHAR(MAX),
    poblacion_2011 INT,
    area_km2 DECIMAL,
    latitud_capital DECIMAL,
    longitud_capital DECIMAL,
    fecha_carga_etl DATETIME2
);

-- Maestro_Empleados
-- Dimensión de empleados/personal
-- Registros: ~234
CREATE TABLE Maestro_Empleados (
    id_empleado INT PRIMARY KEY,
    nombre_empleado NVARCHAR(MAX),
    id_sucursal INT,
    tipo_empleado NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- Maestro_Clientes
-- Dimensión de clientes/pacientes
-- Registros: ~4,567
CREATE TABLE Maestro_Clientes (
    id_cliente INT PRIMARY KEY,
    nombre NVARCHAR(MAX),
    apellido NVARCHAR(MAX),
    cedula NVARCHAR(MAX),
    email NVARCHAR(MAX),
    telefono_principal NVARCHAR(MAX),
    fecha_nacimiento DATE,
    genero NVARCHAR(MAX),
    codigo_postal NVARCHAR(MAX),
    ciudad NVARCHAR(MAX),
    fecha_creacion_cliente DATETIME2,
    fecha_carga_etl DATETIME2
);

-- Maestro_Categorias
-- Dimensión de categorías de productos
-- Registros: 12
CREATE TABLE Maestro_Categorias (
    id_categoria INT PRIMARY KEY,
    nombre_categoria NVARCHAR(MAX),
    id_categoria_padre INT,
    esta_activo BIT,
    fecha_actualizacion DATETIME2,
    fecha_carga_etl DATETIME2
);

-- Maestro_Marcas
-- Dimensión de marcas de lentes/marcos
-- Registros: 18
CREATE TABLE Maestro_Marcas (
    id_marca INT PRIMARY KEY,
    nombre_marca NVARCHAR(MAX),
    codigo_marca NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- Maestro_Productos
-- Dimensión completa de productos (lentes, marcos, accesorios)
-- Registros: ~143,854
CREATE TABLE Maestro_Productos (
    id_producto INT PRIMARY KEY,
    nombre_producto NVARCHAR(MAX),
    referencia NVARCHAR(MAX),
    codigo_barras NVARCHAR(MAX),
    id_marca INT,
    id_categoria INT,
    id_grupo INT,
    es_inventariable BIT,
    costo_compra DECIMAL,
    precio_venta DECIMAL,
    fecha_creacion DATETIME2,
    fecha_ultima_actualizacion DATETIME2,
    nombre_modelo_padre NVARCHAR(MAX),
    genero_objetivo NVARCHAR(MAX),
    material_marco NVARCHAR(MAX),
    color_comercial NVARCHAR(MAX),
    tipo_montura NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- Maestro_Proveedores
-- Dimensión de proveedores/distribuidores
-- Registros: 89
CREATE TABLE Maestro_Proveedores (
    id_proveedor INT PRIMARY KEY,
    nombre_proveedor NVARCHAR(MAX),
    ruc_proveedor NVARCHAR(MAX),
    codigo_interno NVARCHAR(MAX),
    email_contacto NVARCHAR(MAX),
    telefono_contacto NVARCHAR(MAX),
    pais NVARCHAR(MAX),
    fecha_creacion_origen DATETIME2,
    fecha_carga_etl DATETIME2
);

-- Maestro_Metodos_Pago
-- Dimensión de métodos de pago
-- Registros: 8
CREATE TABLE Maestro_Metodos_Pago (
    id_metodo_pago INT PRIMARY KEY,
    nombre_metodo NVARCHAR(MAX),
    descripcion NVARCHAR(MAX),
    codigo_interno NVARCHAR(MAX),
    usa_en_ingresos BIT,
    usa_en_gastos BIT,
    es_activo BIT,
    tipo_pago_codigo NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- ============================================================================
-- SECCIÓN 2: TABLAS TRANSACCIONALES (6 tablas)
-- ============================================================================

-- Ventas_Cabecera
-- Encabezado de facturas de venta
-- Registros: ~2,573
-- Rango de fechas: 2025-01-15 a 2026-04-23
CREATE TABLE Ventas_Cabecera (
    id_factura INT PRIMARY KEY,
    id_sucursal INT,
    id_cliente INT,
    id_empleado INT,
    fecha_factura DATETIME2,
    monto_total DECIMAL,
    fecha_carga_etl DATETIME2
);

-- Ventas_Pedidos
-- Pedidos/órdenes de venta
-- Registros: ~1,234
-- Rango de fechas: 2025-02-01 a 2026-04-22
CREATE TABLE Ventas_Pedidos (
    id_pedido INT PRIMARY KEY,
    numero_pedido NVARCHAR(MAX),
    id_sucursal INT,
    id_cliente INT,
    id_empleado INT,
    fecha_pedido DATETIME2,
    monto_total DECIMAL,
    monto_pagado DECIMAL,
    saldo_pendiente DECIMAL,
    estado_pedido NVARCHAR(MAX),
    id_estado_orden INT,
    fecha_carga_etl DATETIME2
);

-- Finanzas_Cobros
-- Cobros/pagos de clientes
-- Registros: ~4,608
-- Rango de fechas: 2025-01-20 a 2026-04-21
CREATE TABLE Finanzas_Cobros (
    id_cobro INT PRIMARY KEY,
    id_cliente INT,
    id_factura INT,
    id_pedido INT,
    id_sucursal INT,
    monto_cobrado DECIMAL,
    metodo_pago_nombre NVARCHAR(MAX),
    monto_entrega DECIMAL,
    monto_cambio DECIMAL,
    fecha_cobro DATETIME2,
    usuario_creacion NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- Finanzas_Tesoreria
-- Movimientos de caja/tesorería
-- Registros: ~892
-- Rango de fechas: 2025-03-10 a 2026-04-23
CREATE TABLE Finanzas_Tesoreria (
    id_pago_tesoreria INT PRIMARY KEY,
    id_sucursal INT,
    fecha_movimiento DATETIME2,
    monto DECIMAL,
    descripcion NVARCHAR(MAX),
    tipo_movimiento NVARCHAR(MAX),
    metodo_pago_nombre NVARCHAR(MAX),
    id_cuenta_contable NVARCHAR(MAX),
    usuario_creacion NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- Clinica_Examenes
-- Exámenes oftalmológicos realizados
-- Registros: ~3,456
-- Rango de fechas: 2025-01-01 a 2026-04-20
CREATE TABLE Clinica_Examenes (
    id_examen INT PRIMARY KEY,
    id_cliente INT,
    id_sucursal INT,
    id_empleado INT,
    fecha_examen DATETIME2,
    tipo_examen NVARCHAR(MAX),
    observaciones NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- Marketing_Citas
-- Citas/agendamientos de clientes
-- Registros: ~5,678
-- Rango de fechas (fecha_cita_inicio): 2025-02-15 a 2026-04-19
CREATE TABLE Marketing_Citas (
    id_cita INT PRIMARY KEY,
    id_cliente INT,
    id_sucursal INT,
    fecha_cita_inicio DATETIME2,
    fecha_cita_fin DATETIME2,
    tipo_cita_id INT,
    tipo_cita_nombre NVARCHAR(MAX),
    detalles_cita NVARCHAR(MAX),
    fecha_creacion_cita DATETIME2,
    fecha_actualizacion_api DATETIME2,
    nombre_cliente NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- ============================================================================
-- SECCIÓN 3: TABLAS OPERACIONALES (4 tablas)
-- ============================================================================

-- Operaciones_Ordenes_Cristales
-- Órdenes de fabricación de cristales/lentes
-- Registros: ~1,234
-- Rango de fechas (fecha_creacion): 2025-01-10 a 2026-04-23
CREATE TABLE Operaciones_Ordenes_Cristales (
    id_orden_cristal INT PRIMARY KEY,
    codigo_orden NVARCHAR(MAX),
    numero_orden NVARCHAR(MAX),
    id_cliente INT,
    id_sucursal INT,
    id_pedido_venta INT,
    id_pedido_compra INT,
    observaciones NVARCHAR(MAX),
    fecha_creacion DATETIME2,
    od_tipo_lente NVARCHAR(MAX),
    od_material NVARCHAR(MAX),
    od_esfera DECIMAL,
    od_cilindro DECIMAL,
    od_eje DECIMAL,
    od_adicion DECIMAL,
    od_altura DECIMAL,
    oi_tipo_lente NVARCHAR(MAX),
    oi_material NVARCHAR(MAX),
    oi_esfera DECIMAL,
    oi_cilindro DECIMAL,
    oi_eje DECIMAL,
    oi_adicion DECIMAL,
    oi_altura DECIMAL,
    fecha_carga_etl DATETIME2
);

-- Operaciones_Inventario
-- Inventario de productos por sucursal
-- Registros: ~146,707
-- Rango de fechas (fecha_actualizacion): 2025-01-01 a 2026-04-23
CREATE TABLE Operaciones_Inventario (
    id_inventario INT PRIMARY KEY,
    id_producto INT,
    id_sucursal INT,
    cantidad_disponible INT,
    cantidad_reservada INT,
    stock_minimo INT,
    costo_promedio DECIMAL,
    fecha_actualizacion DATETIME2,
    fecha_carga_etl DATETIME2
);

-- Operaciones_Pedidos_Laboratorio
-- Pedidos a laboratorio externo para fabricación
-- Registros: ~567
-- Rango de fechas (fecha_solicitud): 2025-02-05 a 2026-04-18
CREATE TABLE Operaciones_Pedidos_Laboratorio (
    id_pedido_lab INT PRIMARY KEY,
    id_pedido_origen INT,
    proveedor_nombre NVARCHAR(MAX),
    id_sucursal INT,
    fecha_solicitud DATETIME2,
    monto_costo DECIMAL,
    estatus_proceso NVARCHAR(MAX),
    fecha_fabricacion DATETIME2,
    usuario_creacion NVARCHAR(MAX),
    fecha_carga_etl DATETIME2
);

-- Operaciones_Recepciones_Lab
-- Recepciones/albaranes de laboratorio
-- Registros: ~234
-- Rango de fechas (fecha_recepcion_exacta): 2025-01-28 a 2026-04-19
CREATE TABLE Operaciones_Recepciones_Lab (
    id_recepcion_linea INT PRIMARY KEY,
    id_albaran INT,
    numero_albaran NVARCHAR(MAX),
    id_proveedor INT,
    id_pedido_origen INT,
    fecha_recepcion DATE,
    fecha_recepcion_exacta DATETIME2,
    costo_linea_recepcion DECIMAL,
    fecha_carga_etl DATETIME2
);

-- ============================================================================
-- SECCIÓN 4: TABLAS DE PARÁMETROS/GEOGRAFÍA (3 tablas)
-- ============================================================================

-- Param_Venezuela_Estados
-- Estados de Venezuela (24 estados)
CREATE TABLE Param_Venezuela_Estados (
    id_estado INT PRIMARY KEY,
    codigo_ine VARCHAR(MAX),
    nombre_estado NVARCHAR(MAX),
    nombre_capital NVARCHAR(MAX),
    latitud_capital DECIMAL,
    longitud_capital DECIMAL,
    poblacion_2011 INT,
    area_km2 DECIMAL,
    region_administrativa NVARCHAR(MAX),
    fecha_creacion DATETIME2
);

-- Param_Venezuela_Municipios
-- Municipios de Venezuela (256 municipios)
CREATE TABLE Param_Venezuela_Municipios (
    id_municipio INT PRIMARY KEY,
    id_estado INT,
    nombre_municipio NVARCHAR(MAX),
    nombre_capital_municipal NVARCHAR(MAX),
    latitud DECIMAL,
    longitud DECIMAL,
    poblacion_2011 INT,
    area_km2 DECIMAL,
    fecha_creacion DATETIME2
);

-- Param_Venezuela_Parroquias
-- Parroquias de Venezuela (preparada para futuro)
CREATE TABLE Param_Venezuela_Parroquias (
    id_parroquia INT PRIMARY KEY,
    id_municipio INT,
    id_estado INT,
    nombre_parroquia NVARCHAR(MAX),
    latitud DECIMAL,
    longitud DECIMAL,
    fecha_creacion DATETIME2
);

-- ============================================================================
-- SECCIÓN 5: TABLAS DE SEGURIDAD (8 tablas)
-- ============================================================================

-- Seguridad_Usuarios
-- Usuarios del sistema/portal
CREATE TABLE Seguridad_Usuarios (
    id_usuario INT PRIMARY KEY,
    email NVARCHAR(MAX),
    nombre_completo NVARCHAR(MAX),
    password_hash NVARCHAR(MAX),
    esta_activo BIT,
    ultima_sesion DATETIME2,
    fecha_creacion DATETIME2,
    usuario_creacion NVARCHAR(MAX),
    fecha_modificacion DATETIME2,
    usuario_modificacion NVARCHAR(MAX)
);

-- Seguridad_Roles
-- 7 roles jerárquicos: SUPER_ADMIN, ADMIN, GERENTE_ZONA, SUPERVISOR, CONSULTOR, ETL_SERVICE, PORTAL_SERVICE
CREATE TABLE Seguridad_Roles (
    id_rol INT PRIMARY KEY,
    nombre_rol NVARCHAR(MAX),
    descripcion NVARCHAR(MAX),
    nivel_jerarquico INT,
    esta_activo BIT,
    fecha_creacion DATETIME2
);

-- Seguridad_Permisos
-- Permisos granulares por módulo y acción
CREATE TABLE Seguridad_Permisos (
    id_permiso INT PRIMARY KEY,
    nombre_permiso NVARCHAR(MAX),
    descripcion NVARCHAR(MAX),
    modulo NVARCHAR(MAX),
    accion NVARCHAR(MAX),
    esta_activo BIT,
    fecha_creacion DATETIME2
);

-- Seguridad_Roles_Permisos
-- Relación muchos-a-muchos: roles <-> permisos
CREATE TABLE Seguridad_Roles_Permisos (
    id_rol INT,
    id_permiso INT,
    fecha_asignacion DATETIME2
);

-- Seguridad_Usuarios_Roles
-- Relación muchos-a-muchos: usuarios <-> roles
CREATE TABLE Seguridad_Usuarios_Roles (
    id_usuario INT,
    id_rol INT,
    fecha_asignacion DATETIME2,
    fecha_revocacion DATETIME2,
    esta_vigente BIT
);

-- Seguridad_Usuarios_Sucursales
-- RLS: Asignar usuarios a sucursales (qué datos pueden ver)
CREATE TABLE Seguridad_Usuarios_Sucursales (
    id_usuario INT,
    id_sucursal INT,
    fecha_asignacion DATETIME2,
    esta_vigente BIT
);

-- Seguridad_Sesiones
-- Tracking de sesiones JWT del portal
CREATE TABLE Seguridad_Sesiones (
    id_sesion NVARCHAR(MAX) PRIMARY KEY,
    id_usuario INT,
    token_jwt NVARCHAR(MAX),
    ip_origen NVARCHAR(MAX),
    user_agent NVARCHAR(MAX),
    fecha_inicio DATETIME2,
    fecha_expiracion DATETIME2,
    esta_activa BIT
);

-- Seguridad_Auditoria
-- Log inmutable de acciones del sistema
CREATE TABLE Seguridad_Auditoria (
    id_auditoria BIGINT PRIMARY KEY,
    id_usuario INT,
    email_usuario NVARCHAR(MAX),
    accion NVARCHAR(MAX),
    tabla_afectada NVARCHAR(MAX),
    registro_id NVARCHAR(MAX),
    valores_anteriores NVARCHAR(MAX),
    valores_nuevos NVARCHAR(MAX),
    resultado NVARCHAR(MAX),
    mensaje_error NVARCHAR(MAX),
    ip_origen NVARCHAR(MAX),
    fecha_accion DATETIME2
);

-- ============================================================================
-- SECCIÓN 6: TABLAS DE CONTROL ETL (2 tablas)
-- ============================================================================

-- Etl_Control_Ejecucion
-- Control y monitoreo de ejecuciones ETL
CREATE TABLE Etl_Control_Ejecucion (
    modulo_nombre VARCHAR(MAX),
    ultimo_estatus VARCHAR(MAX),
    fecha_inicio DATETIME,
    fecha_fin DATETIME,
    mensaje_error NVARCHAR(MAX)
);

-- Etl_Checkpoints
-- Checkpoints para detectar fin de sincronización INCREMENTAL
CREATE TABLE Etl_Checkpoints (
    KeyName VARCHAR(MAX),
    LastValue NVARCHAR(MAX)
);

-- ============================================================================
-- RESUMEN DE REGISTROS POR TABLA
-- ============================================================================

-- MAESTROS: ~152,500 registros
-- TRANSACCIONALES: ~12,439 registros
-- OPERACIONALES: ~148,742 registros
-- PARÁMETROS: 283 registros
-- SEGURIDAD: ~50-100 registros (según usuarios del sistema)
-- CONTROL ETL: ~18-50 registros (tracking de módulos)

-- TOTAL ESTIMADO: ~314,000+ registros en producción

-- ============================================================================
-- NOTAS IMPORTANTES PARA DESARROLLO DE VISTAS
-- ============================================================================

-- 1. VISTAS DE DIMENSIÓN (Dim_*)
--    - Basadas en tablas Maestro_*
--    - Deben incluir atributos descriptivos y jerárquicos
--    - Referencia: Optilux Panama (copiar y adaptar)

-- 2. VISTAS DE HECHO (Fact_*)
--    - Basadas en tablas transaccionales + operacionales
--    - Deben incluir claves foráneas a dimensiones
--    - Incluir métricas: monto, cantidad, duración
--    - Referencia: Optilux Panama (copiar y adaptar)

-- 3. VISTAS DE RLS (Seguridad)
--    - Vw_Usuario_Accesos: usuario + roles + permisos
--    - Vw_RLS_Sucursales: filtra automáticamente por sucursal asignada
--    - Basadas en Seguridad_Usuarios_Sucursales

-- 4. COLUMNAS AUDIT (TODAS LAS TABLAS)
--    - fecha_carga_etl DATETIME2: Cuándo se cargó desde Gesvision
--    - usuario_creacion NVARCHAR(MAX): Quién creó en el sistema original
--    - fecha_creacion DATETIME2: Cuándo se creó en el sistema original

-- 5. CONVENCIÓN DE NOMENCLATURA
--    - Dim_* : Vistas de dimensión
--    - Fact_* : Vistas de hecho
--    - Vw_* : Vistas de seguridad/RLS
--    - id_* : Claves (INT)
--    - fecha_* : Fechas
--    - monto_* : Valores monetarios (DECIMAL)
--    - cantidad_* : Conteos (INT)

-- ============================================================================
-- PRÓXIMOS PASOS
-- ============================================================================

-- Semana 2-3: Crear vistas Dim_*/Fact_* copiando y adaptando Optilux Panama
-- Semana 3: Validar vistas con KPIs y segmentos comerciales
-- Semana 4: Integrar con Power BI (5 informes oficiales)
-- Semana 5-6: Portal Next.js (dashboards con vistas SQL)
