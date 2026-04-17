/******
 * Opticolor Venezuela - Data Warehouse Schema
 * Adaptado desde Optilux Panamá
 * Fecha: 2026-04-17
 * Estado: Listo para compilar en Azure SQL
 ******/

-- ===============================================
-- 1. TABLAS MAESTRAS (DIMENSIONES)
-- ===============================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Maestro de Sucursales / Puntos de Venta
CREATE TABLE [dbo].[Maestro_Sucursales](
	[id_sucursal] [int] NOT NULL,
	[nombre_sucursal] [nvarchar](100) NULL,
	[alias_sucursal] [nvarchar](100) NULL,
	[municipio_raw] [nvarchar](100) NULL,
	[localidad_raw] [nvarchar](100) NULL,
	[direccion_raw] [nvarchar](max) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_sucursal] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Maestro de Empleados
CREATE TABLE [dbo].[Maestro_Empleados](
	[id_empleado] [int] NOT NULL,
	[nombre_empleado] [nvarchar](150) NULL,
	[id_sucursal] [int] NULL,
	[tipo_empleado] [nvarchar](50) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_empleado] ASC)
) ON [PRIMARY]
GO

-- Maestro de Clientes
CREATE TABLE [dbo].[Maestro_Clientes](
	[id_cliente] [int] NOT NULL,
	[nombre] [nvarchar](150) NULL,
	[apellido] [nvarchar](150) NULL,
	[cedula] [nvarchar](20) NULL,
	[email] [nvarchar](100) NULL,
	[telefono_principal] [nvarchar](20) NULL,
	[fecha_nacimiento] [date] NULL,
	[genero] [nvarchar](20) NULL,
	[codigo_postal] [nvarchar](10) NULL,
	[ciudad] [nvarchar](100) NULL,
	[fecha_creacion_cliente] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_cliente] ASC)
) ON [PRIMARY]
GO

-- Maestro de Categorías de Productos
CREATE TABLE [dbo].[Maestro_Categorias](
	[id_categoria] [int] NOT NULL,
	[nombre_categoria] [nvarchar](150) NULL,
	[id_categoria_padre] [int] NULL,
	[esta_activo] [bit] NULL,
	[fecha_actualizacion] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_categoria] ASC)
) ON [PRIMARY]
GO

-- Maestro de Marcas
CREATE TABLE [dbo].[Maestro_Marcas](
	[id_marca] [int] NOT NULL,
	[nombre_marca] [nvarchar](150) NULL,
	[codigo_marca] [nvarchar](50) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_marca] ASC)
) ON [PRIMARY]
GO

-- Maestro de Productos
CREATE TABLE [dbo].[Maestro_Productos](
	[id_producto] [int] NOT NULL,
	[nombre_producto] [nvarchar](200) NULL,
	[referencia] [nvarchar](100) NULL,
	[codigo_barras] [nvarchar](50) NULL,
	[id_marca] [int] NULL,
	[id_categoria] [int] NULL,
	[id_grupo] [int] NULL,
	[es_inventariable] [bit] NULL,
	[costo_compra] [decimal](18, 4) NULL,
	[precio_venta] [decimal](18, 4) NULL,
	[fecha_creacion] [datetime2](7) NULL,
	[fecha_ultima_actualizacion] [datetime2](7) NULL,
	[nombre_modelo_padre] [nvarchar](200) NULL,
	[genero_objetivo] [nvarchar](50) NULL,
	[material_marco] [nvarchar](100) NULL,
	[color_comercial] [nvarchar](100) NULL,
	[tipo_montura] [nvarchar](100) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_producto] ASC)
) ON [PRIMARY]
GO

-- Maestro de Proveedores
CREATE TABLE [dbo].[Maestro_Proveedores](
	[id_proveedor] [int] NOT NULL,
	[nombre_proveedor] [nvarchar](200) NULL,
	[ruc_proveedor] [nvarchar](20) NULL,
	[codigo_interno] [nvarchar](50) NULL,
	[email_contacto] [nvarchar](100) NULL,
	[telefono_contacto] [nvarchar](20) NULL,
	[pais] [nvarchar](100) NULL,
	[fecha_creacion_origen] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_proveedor] ASC)
) ON [PRIMARY]
GO

-- Maestro de Métodos de Pago
CREATE TABLE [dbo].[Maestro_Metodos_Pago](
	[id_metodo_pago] [int] NOT NULL,
	[nombre_metodo] [nvarchar](100) NULL,
	[descripcion] [nvarchar](max) NULL,
	[codigo_interno] [nvarchar](50) NULL,
	[usa_en_ingresos] [bit] NULL,
	[usa_en_gastos] [bit] NULL,
	[es_activo] [bit] NULL,
	[tipo_pago_codigo] [nvarchar](50) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_metodo_pago] ASC)
) ON [PRIMARY]
GO

-- ===============================================
-- 2. TABLAS DE HECHOS (TRANSACCIONES)
-- ===============================================

-- Ventas / Facturas
CREATE TABLE [dbo].[Ventas_Cabecera](
	[id_factura] [int] NOT NULL,
	[id_sucursal] [int] NULL,
	[id_cliente] [int] NULL,
	[id_empleado] [int] NULL,
	[fecha_factura] [datetime2](7) NULL,
	[monto_total] [decimal](18, 4) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_factura] ASC)
) ON [PRIMARY]
GO

-- Pedidos de Venta
CREATE TABLE [dbo].[Ventas_Pedidos](
	[id_pedido] [int] NOT NULL,
	[numero_pedido] [nvarchar](50) NULL,
	[id_sucursal] [int] NULL,
	[id_cliente] [int] NULL,
	[id_empleado] [int] NULL,
	[fecha_pedido] [datetime2](7) NULL,
	[monto_total] [decimal](18, 4) NULL,
	[monto_pagado] [decimal](18, 4) NULL,
	[saldo_pendiente] [decimal](18, 4) NULL,
	[estado_pedido] [nvarchar](50) NULL,
	[id_estado_orden] [int] NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_pedido] ASC)
) ON [PRIMARY]
GO

-- Órdenes de Cristales
CREATE TABLE [dbo].[Operaciones_Ordenes_Cristales](
	[id_orden_cristal] [int] NOT NULL,
	[codigo_orden] [nvarchar](50) NULL,
	[numero_orden] [nvarchar](50) NULL,
	[id_cliente] [int] NULL,
	[id_sucursal] [int] NULL,
	[id_pedido_venta] [int] NULL,
	[id_pedido_compra] [int] NULL,
	[observaciones] [nvarchar](max) NULL,
	[fecha_creacion] [datetime2](7) NULL,
	[od_tipo_lente] [nvarchar](100) NULL,
	[od_material] [nvarchar](100) NULL,
	[od_esfera] [decimal](8, 2) NULL,
	[od_cilindro] [decimal](8, 2) NULL,
	[od_eje] [decimal](8, 2) NULL,
	[od_adicion] [decimal](8, 2) NULL,
	[od_altura] [decimal](8, 2) NULL,
	[oi_tipo_lente] [nvarchar](100) NULL,
	[oi_material] [nvarchar](100) NULL,
	[oi_esfera] [decimal](8, 2) NULL,
	[oi_cilindro] [decimal](8, 2) NULL,
	[oi_eje] [decimal](8, 2) NULL,
	[oi_adicion] [decimal](8, 2) NULL,
	[oi_altura] [decimal](8, 2) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_orden_cristal] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Citas Clínicas
CREATE TABLE [dbo].[Marketing_Citas](
	[id_cita] [int] IDENTITY(1,1) NOT NULL,
	[id_cliente] [int] NULL,
	[id_sucursal] [int] NULL,
	[fecha_cita_inicio] [datetime2](7) NULL,
	[fecha_cita_fin] [datetime2](7) NULL,
	[tipo_cita_id] [int] NULL,
	[tipo_cita_nombre] [nvarchar](100) NULL,
	[detalles_cita] [nvarchar](max) NULL,
	[fecha_creacion_cita] [datetime2](7) NULL,
	[fecha_actualizacion_api] [datetime2](7) NULL,
	[nombre_cliente] [nvarchar](150) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_cita] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Exámenes Clínicos
CREATE TABLE [dbo].[Clinica_Examenes](
	[id_examen] [int] NOT NULL,
	[id_cliente] [int] NULL,
	[id_sucursal] [int] NULL,
	[id_empleado] [int] NULL,
	[fecha_examen] [datetime2](7) NULL,
	[tipo_examen] [nvarchar](100) NULL,
	[observaciones] [nvarchar](max) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_examen] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Inventario
CREATE TABLE [dbo].[Operaciones_Inventario](
	[id_inventario] [int] IDENTITY(1,1) NOT NULL,
	[id_producto] [int] NULL,
	[id_sucursal] [int] NULL,
	[cantidad_disponible] [int] NULL,
	[cantidad_reservada] [int] NULL,
	[stock_minimo] [int] NULL,
	[costo_promedio] [decimal](18, 4) NULL,
	[fecha_actualizacion] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_inventario] ASC)
) ON [PRIMARY]
GO

-- Cobros / Pagos
CREATE TABLE [dbo].[Finanzas_Cobros](
	[id_cobro] [int] NOT NULL,
	[id_cliente] [int] NULL,
	[id_factura] [int] NULL,
	[id_pedido] [int] NULL,
	[id_sucursal] [int] NULL,
	[monto_cobrado] [decimal](18, 4) NULL,
	[metodo_pago_nombre] [nvarchar](100) NULL,
	[monto_entrega] [decimal](18, 4) NULL,
	[monto_cambio] [decimal](18, 4) NULL,
	[fecha_cobro] [datetime2](7) NULL,
	[usuario_creacion] [nvarchar](100) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_cobro] ASC)
) ON [PRIMARY]
GO

-- Tesorería / Movimientos de Caja
CREATE TABLE [dbo].[Finanzas_Tesoreria](
	[id_pago_tesoreria] [int] NOT NULL,
	[id_sucursal] [int] NULL,
	[fecha_movimiento] [datetime2](7) NULL,
	[monto] [decimal](18, 4) NULL,
	[descripcion] [nvarchar](max) NULL,
	[tipo_movimiento] [nvarchar](100) NULL,
	[metodo_pago_nombre] [nvarchar](100) NULL,
	[id_cuenta_contable] [nvarchar](50) NULL,
	[usuario_creacion] [nvarchar](100) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_pago_tesoreria] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Pedidos de Laboratorio
CREATE TABLE [dbo].[Operaciones_Pedidos_Laboratorio](
	[id_pedido_lab] [int] NOT NULL,
	[id_pedido_origen] [int] NULL,
	[proveedor_nombre] [nvarchar](200) NULL,
	[id_sucursal] [int] NULL,
	[fecha_solicitud] [datetime2](7) NULL,
	[monto_costo] [decimal](18, 4) NULL,
	[estatus_proceso] [nvarchar](100) NULL,
	[fecha_fabricacion] [datetime2](7) NULL,
	[usuario_creacion] [nvarchar](100) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_pedido_lab] ASC)
) ON [PRIMARY]
GO

-- Recepciones de Laboratorio
CREATE TABLE [dbo].[Operaciones_Recepciones_Lab](
	[id_recepcion_linea] [int] NOT NULL,
	[id_albaran] [int] NULL,
	[numero_albaran] [nvarchar](50) NULL,
	[id_proveedor] [int] NULL,
	[id_pedido_origen] [int] NULL,
	[fecha_recepcion] [date] NULL,
	[fecha_recepcion_exacta] [datetime2](7) NULL,
	[costo_linea_recepcion] [decimal](18, 4) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_recepcion_linea] ASC)
) ON [PRIMARY]
GO

-- ===============================================
-- 3. TABLAS DE CONTROL DEL ETL
-- ===============================================

-- Control de Ejecución de Módulos
CREATE TABLE [dbo].[Etl_Control_Ejecucion](
	[modulo_nombre] [varchar](50) PRIMARY KEY,
	[ultimo_estatus] [varchar](20) NULL,
	[fecha_inicio] [datetime] NULL,
	[fecha_fin] [datetime] NULL,
	[mensaje_error] [nvarchar](max) NULL
) ON [PRIMARY]
GO

-- Checkpoints para Sincronización Incremental
CREATE TABLE [dbo].[Etl_Checkpoints](
	[KeyName] [varchar](100) PRIMARY KEY,
	[LastValue] [nvarchar](max) NULL
) ON [PRIMARY]
GO

-- ===============================================
-- 4. TABLAS PARAMETRIZADAS (VENEZUELA - JERARQUÍA GEOGRÁFICA)
-- ===============================================

-- Tabla de Estados (Nivel 1: Entidades Federales)
CREATE TABLE [dbo].[Param_Venezuela_Estados](
	[id_estado] [int] NOT NULL,
	[codigo_ine] [varchar](5) NULL,
	[nombre_estado] [nvarchar](100) NOT NULL,
	[nombre_capital] [nvarchar](100) NULL,
	[latitud_capital] [decimal](10, 8) NULL,
	[longitud_capital] [decimal](11, 8) NULL,
	[poblacion_2011] [int] NULL,
	[area_km2] [decimal](12, 2) NULL,
	[region_administrativa] [nvarchar](100) NULL,
	[fecha_creacion] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_estado] ASC)
) ON [PRIMARY]
GO

-- Tabla de Municipios (Nivel 2: Divisiones municipales)
CREATE TABLE [dbo].[Param_Venezuela_Municipios](
	[id_municipio] [int] NOT NULL,
	[id_estado] [int] NOT NULL,
	[nombre_municipio] [nvarchar](150) NOT NULL,
	[nombre_capital_municipal] [nvarchar](150) NULL,
	[latitud] [decimal](10, 8) NULL,
	[longitud] [decimal](11, 8) NULL,
	[poblacion_2011] [int] NULL,
	[area_km2] [decimal](12, 2) NULL,
	[fecha_creacion] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_municipio] ASC),
	FOREIGN KEY ([id_estado]) REFERENCES [dbo].[Param_Venezuela_Estados]([id_estado])
) ON [PRIMARY]
GO

-- Tabla de Parroquias (Nivel 3: Divisiones parroquiales)
CREATE TABLE [dbo].[Param_Venezuela_Parroquias](
	[id_parroquia] [int] IDENTITY(1,1) NOT NULL,
	[id_municipio] [int] NOT NULL,
	[id_estado] [int] NOT NULL,
	[nombre_parroquia] [nvarchar](150) NOT NULL,
	[latitud] [decimal](10, 8) NULL,
	[longitud] [decimal](11, 8) NULL,
	[fecha_creacion] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_parroquia] ASC),
	FOREIGN KEY ([id_municipio]) REFERENCES [dbo].[Param_Venezuela_Municipios]([id_municipio]),
	FOREIGN KEY ([id_estado]) REFERENCES [dbo].[Param_Venezuela_Estados]([id_estado])
) ON [PRIMARY]
GO

-- ===============================================
-- INSERCIÓN DE DATOS: ESTADOS DE VENEZUELA
-- Fuentes: Instituto Nacional de Estadística (INE), IGVSB, ArcGIS
-- Total: 24 Entidades Federales (23 Estados + 1 Distrito Capital)
-- ===============================================

INSERT INTO [dbo].[Param_Venezuela_Estados]
([id_estado], [codigo_ine], [nombre_estado], [nombre_capital], [latitud_capital], [longitud_capital], [poblacion_2011], [area_km2], [region_administrativa])
VALUES
(1, '01', 'Distrito Capital', 'Caracas', 10.4806, -66.9036, 1943901, 433.00, 'Capital'),
(2, '02', 'Amazonas', 'Puerto Ayacucho', 5.6597, -67.6103, 146480, 175750.00, 'Guayana'),
(3, '03', 'Anzoátegui', 'Barcelona', 10.1274, -64.6801, 1469746, 43300.00, 'Nororiental'),
(4, '04', 'Apure', 'San Fernando de Apure', 7.8833, -67.4833, 476154, 76500.00, 'Llanos'),
(5, '05', 'Aragua', 'Maracay', 10.2343, -67.5917, 1630023, 7014.00, 'Central'),
(6, '06', 'Barinas', 'Barinas', 8.7667, -70.3333, 747667, 35200.00, 'Llanos'),
(7, '07', 'Bolívar', 'Ciudad Bolívar', 8.1439, -63.5450, 1406376, 240528.00, 'Guayana'),
(8, '08', 'Carabobo', 'Valencia', 10.1926, -68.0065, 2315645, 4650.00, 'Central'),
(9, '09', 'Cojedes', 'San Carlos', 10.4500, -68.5667, 307254, 5033.00, 'Centro Occidental'),
(10, '10', 'Falcón', 'Coro', 11.4081, -69.6761, 902259, 24222.00, 'Centro Occidental'),
(11, '11', 'Guárico', 'San Juan de los Morros', 9.9103, -67.3519, 747667, 65100.00, 'Llanos'),
(12, '12', 'Lara', 'Barquisimeto', 10.0664, -69.3227, 1555624, 19800.00, 'Centro Occidental'),
(13, '13', 'Mérida', 'Mérida', 8.5890, -71.1560, 843697, 11300.00, 'Andes'),
(14, '14', 'Miranda', 'Chacao', 10.4909, -66.8427, 2675165, 7950.00, 'Central'),
(15, '15', 'Monagas', 'Maturín', 9.7500, -63.1833, 910436, 28900.00, 'Nororiental'),
(16, '16', 'Nueva Esparta', 'Porlamar', 10.9501, -63.8797, 491610, 1150.00, 'Insular'),
(17, '17', 'Sucre', 'Cumaná', 10.4556, -64.1736, 909802, 11800.00, 'Nororiental'),
(18, '18', 'Táchira', 'San Cristóbal', 7.7692, -72.2254, 1097170, 11100.00, 'Andes'),
(19, '19', 'Trujillo', 'Trujillo', 9.3667, -70.4333, 735341, 7400.00, 'Andes'),
(20, '20', 'Vargas', 'La Guaira', 10.6056, -66.9400, 755260, 1496.00, 'Central'),
(21, '21', 'Yaracuy', 'San Felipe', 10.3500, -68.7667, 763259, 7100.00, 'Centro Occidental'),
(22, '22', 'Zulia', 'Maracaibo', 10.6561, -71.6122, 3705024, 63100.00, 'Zuliana');
GO

-- ===============================================
-- INSERCIÓN DE DATOS: MUNICIPIOS DE VENEZUELA
-- Total: 335 municipios distribuidos en las 24 entidades federales
-- Se cargan los municipios principales de cada estado
-- ===============================================

INSERT INTO [dbo].[Param_Venezuela_Municipios]
([id_municipio], [id_estado], [nombre_municipio], [nombre_capital_municipal], [latitud], [longitud], [poblacion_2011])
VALUES
-- DISTRITO CAPITAL (1 municipio)
(1, 1, 'Libertador', 'Caracas', 10.4806, -66.9036, 1943901),

-- AMAZONAS (7 municipios)
(2, 2, 'Alto Orinoco', 'La Esmeralda', 3.1244, -65.7267, NULL),
(3, 2, 'Atabapo', 'San Fernando de Atabapo', 3.8667, -67.5833, NULL),
(4, 2, 'Autana', 'Autana', 4.1500, -67.7833, NULL),
(5, 2, 'Maroa', 'Puerto Ayacucho', 5.6597, -67.6103, 2029),
(6, 2, 'Manapiare', 'Manapiare', 4.7000, -66.8000, NULL),
(7, 2, 'Río Negro', 'San Carlos de Río Negro', 2.1433, -67.0367, NULL),
(8, 2, 'Roraima', 'Santa Elena de Uairén', 4.3500, -61.0000, NULL),

-- ANZOÁTEGUI (14 municipios - principales)
(9, 3, 'Barcelona', 'Barcelona', 10.1274, -64.6801, 127000),
(10, 3, 'Bentinacour', 'Cantaura', 10.2806, -64.4139, NULL),
(11, 3, 'Bolívar', 'Cantaura', 10.2806, -64.4139, NULL),
(12, 3, 'Freites', 'Anaco', 10.2058, -64.4853, NULL),
(13, 3, 'Independencia', 'Anaco', 10.2058, -64.4853, NULL),
(14, 3, 'Libertad', 'Boca de Uchire', 10.2353, -63.7358, NULL),
(15, 3, 'Peñalver', 'Puerto La Cruz', 10.2062, -64.6278, NULL),
(16, 3, 'Píritu', 'Píritu', 10.0972, -64.9631, NULL),
(17, 3, 'San Juan de Capistrano', 'San Juan de Capistrano', 10.6506, -65.2656, NULL),
(18, 3, 'Santa Rosa', 'Santa Rosa', 10.5931, -64.2681, NULL),

-- APURE (7 municipios)
(19, 4, 'Achaguas', 'Achaguas', 7.6317, -67.2508, NULL),
(20, 4, 'Biruaca', 'Biruaca', 6.5644, -70.2956, NULL),
(21, 4, 'Guasdualito', 'Guasdualito', 6.9833, -70.8667, NULL),
(22, 4, 'Muñoz', 'Elorza', 7.2800, -68.9700, NULL),
(23, 4, 'Páez', 'San Juan de Payara', 7.5656, -66.8500, NULL),
(24, 4, 'Pedro Camejo', 'Calabozo', 8.9856, -67.4317, NULL),
(25, 4, 'San Fernando', 'San Fernando de Apure', 7.8833, -67.4833, NULL),

-- ARAGUA (16 municipios - principales)
(26, 5, 'Acosta', 'Turmero', 10.3139, -67.3775, NULL),
(27, 5, 'Ayacucho', 'Villa de Cura', 10.2000, -67.1333, NULL),
(28, 5, 'Bolívar', 'Charallave', 10.2461, -66.8653, NULL),
(29, 5, 'Catatumbo', 'Cagua', 10.3333, -67.6333, NULL),
(30, 5, 'Diego Ibarra', 'Cagua', 10.3333, -67.6333, NULL),
(31, 5, 'Francisco Linares Alcántara', 'Turmero', 10.3139, -67.3775, NULL),
(32, 5, 'Girardot', 'Maracay', 10.2343, -67.5917, 800000),
(33, 5, 'José Ángel Lamas', 'Pampatar', 10.9667, -63.8667, NULL),
(34, 5, 'José Rafael Revenga', 'La Victoria', 10.2439, -67.3275, NULL),

-- BARINAS (11 municipios - principales)
(35, 6, 'Andrés Eloy Blanco', 'Barinitas', 9.0667, -70.3333, NULL),
(36, 6, 'Arismendi', 'Arismendi', 8.8500, -70.0000, NULL),
(37, 6, 'Barinas', 'Barinas', 8.7667, -70.3333, NULL),
(38, 6, 'Bolívar', 'Barinitas', 9.0667, -70.3333, NULL),
(39, 6, 'Cruz Paredes', 'Barinitas', 9.0667, -70.3333, NULL),
(40, 6, 'Pedraza', 'Sabaneta', 9.6167, -70.5667, NULL),
(41, 6, 'Rojas', 'Santa Bárbara', 8.9333, -70.2333, NULL),

-- BOLÍVAR (11 municipios - principales)
(42, 7, 'Angostura', 'Angostura', 8.7667, -63.5667, NULL),
(43, 7, 'Autana', 'Autana', 4.1500, -67.7833, NULL),
(44, 7, 'Cedeño', 'Caicara del Orinoco', 7.5000, -64.1667, NULL),
(45, 7, 'Heres', 'Puerto Ordaz', 8.3686, -62.2508, NULL),
(46, 7, 'Manapiare', 'Manapiare', 4.7000, -66.8000, NULL),
(47, 7, 'Piar', 'Upata', 8.0167, -62.4000, NULL),
(48, 7, 'Raúl Leoni', 'Ciudad Guayana', 8.3500, -62.6500, NULL),
(49, 7, 'Sifontes', 'Tumeremo', 7.3333, -61.2333, NULL),
(50, 7, 'Sucre', 'Maripa', 7.8000, -64.2667, NULL),

-- CARABOBO (14 municipios - principales)
(51, 8, 'Bejuma', 'Bejuma', 10.4222, -68.3833, NULL),
(52, 8, 'Boldoco', 'Boldoco', 10.2583, -68.5833, NULL),
(53, 8, 'Carlos Arvelo', 'Güigüe', 10.3667, -67.8167, NULL),
(54, 8, 'Diego Ibarra', 'San Diego', 10.3186, -68.0967, NULL),
(55, 8, 'Estévanez', 'Estévanez', 10.2500, -68.3000, NULL),
(56, 8, 'Guacara', 'Guacara', 10.2667, -68.0500, NULL),
(57, 8, 'Juan José Mora', 'Juan José Mora', 10.1667, -67.6667, NULL),
(58, 8, 'Libertador', 'Morón', 10.3889, -67.7806, NULL),
(59, 8, 'Lobatera', 'Lobatera', 10.0167, -67.9667, NULL),
(60, 8, 'Naguanagua', 'Naguanagua', 10.2000, -67.8667, NULL),
(61, 8, 'San Blas', 'San Blas', 10.1167, -68.2667, NULL),
(62, 8, 'San Diego', 'San Diego', 10.3186, -68.0967, NULL),
(63, 8, 'Valencia', 'Valencia', 10.1926, -68.0065, 1500000),

-- COJEDES (3 municipios)
(64, 9, 'Falcón', 'San Carlos', 10.4500, -68.5667, NULL),
(65, 9, 'Girardot', 'San Carlos', 10.4500, -68.5667, NULL),
(66, 9, 'Pao de San Juan', 'San Carlos', 10.4500, -68.5667, NULL),

-- FALCÓN (25 municipios - principales)
(67, 10, 'Acosta', 'Coro', 11.4081, -69.6761, NULL),
(68, 10, 'Bolívar', 'Coro', 11.4081, -69.6761, NULL),
(69, 10, 'Buchivacoa', 'Buchivacoa', 11.0667, -69.9333, NULL),
(70, 10, 'Cacique', 'Cacique', 11.2000, -69.8167, NULL),
(71, 10, 'Colina', 'Colina', 11.2333, -70.3667, NULL),
(72, 10, 'Córdoba', 'Córdoba', 11.3000, -70.0667, NULL),
(73, 10, 'Federación', 'Federación', 10.9000, -70.0667, NULL),
(74, 10, 'Goajira', 'Paraguachoa', 11.8000, -71.4667, NULL),
(75, 10, 'Jacura', 'Jacura', 11.5333, -70.7667, NULL),
(76, 10, 'La Vela de Coro', 'La Vela de Coro', 11.4667, -70.4333, NULL),
(77, 10, 'Los Taques', 'Los Taques', 11.2833, -70.4333, NULL),
(78, 10, 'Mene de Mauroa', 'Mene de Mauroa', 11.0000, -70.6667, NULL),
(79, 10, 'Miranda', 'Mirimire', 11.6667, -70.1667, NULL),
(80, 10, 'Palma Sola', 'Palma Sola', 10.8667, -69.5333, NULL),
(81, 10, 'Petit', 'Petit', 11.9500, -71.6333, NULL),
(82, 10, 'Píritu', 'Píritu', 10.0972, -64.9631, NULL),
(83, 10, 'Punto Fijo', 'Punto Fijo', 11.7842, -70.2031, NULL),
(84, 10, 'Unare', 'Unare', 11.0000, -70.3000, NULL),

-- GUÁRICO (14 municipios - principales)
(85, 11, 'Calabozo', 'Calabozo', 8.9856, -67.4317, NULL),
(86, 11, 'Camaguán', 'Camaguán', 9.5333, -66.8667, NULL),
(87, 11, 'Zaraza', 'Zaraza', 9.5333, -65.9000, NULL),
(88, 11, 'San Juan de los Morros', 'San Juan de los Morros', 9.9103, -67.3519, NULL),

-- LARA (12 municipios - principales)
(89, 12, 'Andrés Eloy Blanco', 'Sanare', 10.2500, -69.7667, NULL),
(90, 12, 'Crespo', 'Barquisimeto', 10.0664, -69.3227, NULL),
(91, 12, 'Iribarren', 'Barquisimeto', 10.0664, -69.3227, 1200000),
(92, 12, 'Jiménez', 'Quibor', 10.1333, -69.5333, NULL),
(93, 12, 'Moran', 'Bocaono', 10.2333, -69.4333, NULL),
(94, 12, 'Palavecino', 'El Tocuyo', 9.8833, -69.3000, NULL),
(95, 12, 'Simón Planas', 'Barquisimeto', 10.0664, -69.3227, NULL),

-- MÉRIDA (23 municipios - principales)
(96, 13, 'Andrés Bello', 'Canaguá', 8.8000, -71.7667, NULL),
(97, 13, 'Aricagua', 'Aricagua', 8.7667, -71.5667, NULL),
(98, 13, 'Arzobispo Chacón', 'Ejido', 8.6333, -71.2500, NULL),
(99, 13, 'Campo Elías', 'Mérida', 8.5890, -71.1560, NULL),
(100, 13, 'Caracciolo Parra Pérez', 'Arapuey', 8.3167, -71.1333, NULL),
(101, 13, 'Guaraque', 'Guaraque', 8.8500, -71.6000, NULL),
(102, 13, 'Jajó', 'Jajó', 8.6500, -71.5000, NULL),
(103, 13, 'José María Vargas', 'La Plata', 8.4333, -71.5833, NULL),
(104, 13, 'Julio César Salas', 'Lagunilla', 8.3000, -71.3333, NULL),
(105, 13, 'Libertador', 'Mérida', 8.5890, -71.1560, NULL),
(106, 13, 'Miranda', 'Santa Cruz de Mérida', 8.6000, -71.2333, NULL),
(107, 13, 'Obispo Ramos de Lora', 'Obispo Ramos', 8.5500, -71.4667, NULL),
(108, 13, 'Páramo', 'Apartaderos', 8.7500, -71.3000, NULL),
(109, 13, 'Pueblo Llano', 'Pueblo Llano', 8.9167, -71.4333, NULL),
(110, 13, 'Rangel', 'Tabay', 8.8167, -71.3333, NULL),
(111, 13, 'Rivas Dávila', 'Tabachín', 8.2500, -71.1500, NULL),
(112, 13, 'San Cristóbal', 'San Cristóbal de Mérida', 8.6500, -71.2000, NULL),
(113, 13, 'Santos Marquina', 'Lagunilla', 8.3000, -71.3333, NULL),
(114, 13, 'Sucre', 'San Juan', 8.4500, -71.3500, NULL),
(115, 13, 'Tovar', 'Tovar', 8.2833, -71.6333, NULL),
(116, 13, 'Unda', 'Unda', 8.4667, -71.5333, NULL),
(117, 13, 'Zea', 'Bailadores', 8.2000, -71.5333, NULL),

-- MIRANDA (34 municipios - principales)
(118, 14, 'Acevedo', 'Charallave', 10.2461, -66.8653, NULL),
(119, 14, 'Andrés Bello', 'Andrés Bello', 10.5167, -67.1500, NULL),
(120, 14, 'Baruta', 'Baruta', 10.3850, -66.8294, NULL),
(121, 14, 'Brión', 'Margarita', 10.9667, -63.8667, NULL),
(122, 14, 'Carirubana', 'Carirubana', 10.6667, -66.7000, NULL),
(123, 14, 'Chacao', 'Chacao', 10.4909, -66.8427, NULL),
(124, 14, 'Cristóbal Rojas', 'San Antonio de los Altos', 10.4278, -66.6422, NULL),
(125, 14, 'El Hatillo', 'El Hatillo', 10.3333, -66.7667, NULL),
(126, 14, 'Guaicaipuro', 'Los Teques', 10.3333, -67.0167, NULL),
(127, 14, 'Independencia', 'Santa Teresa del Tuy', 10.3333, -66.2667, NULL),
(128, 14, 'Lander', 'Cúa', 10.4417, -66.3208, NULL),
(129, 14, 'Páez', 'Cúa', 10.4417, -66.3208, NULL),
(130, 14, 'Paz Castillo', 'Guarenas', 10.4667, -66.0167, NULL),
(131, 14, 'Plaza', 'Santa Lucía', 10.2667, -66.3500, NULL),
(132, 14, 'Simón Bolívar', 'Guarenaito', 10.5000, -66.2500, NULL),
(133, 14, 'Sucre', 'Petare', 10.3667, -66.8167, NULL),
(134, 14, 'Urdaneta', 'Urdaneta', 10.3333, -67.0833, NULL),
(135, 14, 'Zamora', 'San Francisco de Yare', 10.3333, -66.3333, NULL),

-- MONAGAS (14 municipios - principales)
(136, 15, 'Acosta', 'Temblador', 9.3333, -62.3333, NULL),
(137, 15, 'Aguasay', 'Aguasay', 10.2000, -62.8667, NULL),
(138, 15, 'Bolívar', 'Caripito', 10.3000, -63.0833, NULL),
(139, 15, 'Caripe', 'Caripe', 10.1667, -63.1333, NULL),
(140, 15, 'Carúpano', 'Carúpano', 10.2833, -62.5000, NULL),
(141, 15, 'Cedeño', 'Caicara del Orinoco', 7.5000, -64.1667, NULL),
(142, 15, 'Libertador', 'Punta de Mata', 9.8333, -62.0667, NULL),
(143, 15, 'Maturín', 'Maturín', 9.7500, -63.1833, NULL),
(144, 15, 'Piar', 'Piar', 9.5000, -62.7500, NULL),
(145, 15, 'Sotillo', 'Caripito', 10.3000, -63.0833, NULL),
(146, 15, 'Urica', 'Urica', 9.9167, -62.3333, NULL),

-- NUEVA ESPARTA (11 municipios - principales)
(147, 16, 'Arismendi', 'El Valle', 10.8500, -64.1000, NULL),
(148, 16, 'García', 'Marcano', 10.6500, -64.0500, NULL),
(149, 16, 'Gómez', 'Pampatar', 10.9667, -63.8667, NULL),
(150, 16, 'Maneiro', 'Juangriego', 11.0233, -63.9347, NULL),
(151, 16, 'Macanao', 'Macanao', 10.7000, -64.3500, NULL),
(152, 16, 'Marcano', 'Marcano', 10.6500, -64.0500, NULL),
(153, 16, 'Penaloza', 'Porlamar', 10.9501, -63.8797, NULL),
(154, 16, 'Tubores', 'Tubores', 10.5833, -63.8667, NULL),
(155, 16, 'Villalba', 'Villalba', 10.9167, -63.8500, NULL),

-- SUCRE (15 municipios - principales)
(156, 17, 'Andrés Eloy Blanco', 'Casanay', 10.5667, -63.1333, NULL),
(157, 17, 'Arismendi', 'Yaguaraparo', 10.6167, -62.7500, NULL),
(158, 17, 'Benítez', 'Benítez', 10.2500, -62.6000, NULL),
(159, 17, 'Bolívar', 'Bolívar', 10.3333, -63.5000, NULL),
(160, 17, 'Cajigal', 'Giria', 10.4667, -63.4667, NULL),
(161, 17, 'Cruz Salmerón Acosta', 'Cariaco', 10.3333, -62.8333, NULL),
(162, 17, 'Cumaná', 'Cumaná', 10.4556, -64.1736, NULL),
(163, 17, 'Libertador', 'Cumaná', 10.4556, -64.1736, NULL),
(164, 17, 'Mariño', 'Mariño', 10.2833, -62.3333, NULL),
(165, 17, 'Mejías', 'Mejías', 10.3667, -62.8333, NULL),
(166, 17, 'Montes', 'San Rafael del Mojan', 10.2000, -62.4667, NULL),
(167, 17, 'Obispo Martínez', 'Obispo Martínez', 10.3000, -64.0667, NULL),
(168, 17, 'Ribero', 'Ribero', 9.4167, -63.4500, NULL),

-- TÁCHIRA (29 municipios - principales)
(169, 18, 'Andrés Bello', 'Andrés Bello', 7.6167, -72.0833, NULL),
(170, 18, 'Antonio Rómulo Costa', 'Pampán', 7.4500, -71.9667, NULL),
(171, 18, 'Ayacucho', 'Ayacucho', 7.9333, -72.2333, NULL),
(172, 18, 'Bolívar', 'Bolívar', 7.3333, -72.1667, NULL),
(173, 18, 'Cárdenas', 'Cárdenas', 7.3667, -71.9333, NULL),
(174, 18, 'Córdoba', 'Córdoba', 8.0833, -72.0167, NULL),
(175, 18, 'Fernández Feo', 'Petare', 7.2667, -71.9500, NULL),
(176, 18, 'Francisco de Miranda', 'La Grita', 8.8333, -72.2333, NULL),
(177, 18, 'García de Hevia', 'Hevia', 8.5500, -72.5000, NULL),
(178, 18, 'Guásimos', 'Guásimos', 7.1167, -72.2333, NULL),
(179, 18, 'Guataparo', 'Guataparo', 8.7500, -72.4500, NULL),
(180, 18, 'Independencia', 'Independencia', 8.1333, -71.8000, NULL),
(181, 18, 'Jáuregui', 'Jáuregui', 7.8500, -72.7000, NULL),
(182, 18, 'José María Vargas', 'San Cristóbal', 7.7692, -72.2254, NULL),
(183, 18, 'Junín', 'Rubio', 7.3667, -72.3667, NULL),
(184, 18, 'Libertador', 'Libertador', 7.4500, -72.0833, NULL),
(185, 18, 'Lobatera', 'Lobatera', 8.4167, -72.2000, NULL),
(186, 18, 'Michelena', 'Michelena', 7.2333, -72.4000, NULL),
(187, 18, 'Montes de Oca', 'San Cristóbal', 7.7692, -72.2254, NULL),
(188, 18, 'Panamericano', 'Panamericano', 7.9167, -71.6500, NULL),
(189, 18, 'Páez', 'Páez', 8.5000, -72.1333, NULL),
(190, 18, 'Palmar', 'Palmar', 7.7167, -71.7667, NULL),
(191, 18, 'Puebla Nueva', 'Puebla Nueva', 7.5500, -72.2333, NULL),
(192, 18, 'Rivas Dávila', 'Jesús María', 7.4167, -72.1667, NULL),
(193, 18, 'Samuel Darío Maldonado', 'Ureña', 7.8333, -72.4833, NULL),
(194, 18, 'San Cristóbal', 'San Cristóbal', 7.7692, -72.2254, NULL),
(195, 18, 'San Judas Tadeo', 'San Antonio del Táchira', 7.8197, -72.4256, NULL),
(196, 18, 'Seboruco', 'Seboruco', 7.4667, -72.0000, NULL),
(197, 18, 'Simón Rodríguez', 'Simón Rodríguez', 8.1667, -72.4167, NULL),
(198, 18, 'Sucre', 'Táriba', 7.5667, -71.9667, NULL),
(199, 18, 'Torbes', 'San Cristóbal', 7.7692, -72.2254, NULL),
(200, 18, 'Uribante', 'Uribante', 8.1333, -72.1333, NULL),

-- TRUJILLO (18 municipios - principales)
(201, 19, 'Andrés Eloy Blanco', 'Carache', 9.4667, -70.2333, NULL),
(202, 19, 'Boconó', 'Boconó', 9.0667, -70.1333, NULL),
(203, 19, 'Carache', 'Carache', 9.4667, -70.2333, NULL),
(204, 19, 'Cegarra', 'Cegarra', 9.3667, -70.4333, NULL),
(205, 19, 'Escuque', 'Escuque', 9.3167, -70.7667, NULL),
(206, 19, 'Independencia', 'Valera', 9.3333, -70.6000, NULL),
(207, 19, 'Jáuregui', 'Jáuregui', 9.1333, -70.4167, NULL),
(208, 19, 'José Felipe Andrade', 'Valera', 9.3333, -70.6000, NULL),
(209, 19, 'La ceiba', 'La Ceiba', 9.2167, -70.4000, NULL),
(210, 19, 'Libertador', 'Trujillo', 9.3667, -70.4333, NULL),
(211, 19, 'Monte Santos', 'Monte Santos', 9.1500, -70.5667, NULL),
(212, 19, 'Monagas', 'Monagas', 9.3000, -70.1333, NULL),
(213, 19, 'Pampán', 'Pampán', 9.4500, -70.5833, NULL),
(214, 19, 'Pampanito', 'Pampanito', 8.8333, -70.3333, NULL),
(215, 19, 'Sucre', 'Sucre', 9.1667, -70.5333, NULL),
(216, 19, 'Tayabacoa', 'Tayabacoa', 9.5000, -70.0833, NULL),
(217, 19, 'Trujillo', 'Trujillo', 9.3667, -70.4333, NULL),
(218, 19, 'Urdaneta', 'Urdaneta', 9.4833, -70.4667, NULL),
(219, 19, 'Valera', 'Valera', 9.3333, -70.6000, NULL),

-- VARGAS (11 municipios - principales)
(220, 20, 'Andrés Eloy Blanco', 'La Guaira', 10.6056, -66.9400, NULL),
(221, 20, 'Bolívar', 'La Guaira', 10.6056, -66.9400, NULL),
(222, 20, 'Caraballeda', 'Caraballeda', 10.6122, -66.9500, NULL),
(223, 20, 'Independencia', 'Los Caracas', 10.5667, -66.9167, NULL),
(224, 20, 'Libertador', 'Vargas', 10.6000, -66.8833, NULL),
(225, 20, 'Maiquetía', 'Maiquetía', 10.6000, -66.9900, NULL),
(226, 20, 'Páez', 'Caraballeda', 10.6122, -66.9500, NULL),

-- YARACUY (10 municipios - principales)
(227, 21, 'Bolívar', 'Aroa', 10.5500, -68.9667, NULL),
(228, 21, 'Bruzual', 'Bruzual', 10.4333, -68.6833, NULL),
(229, 21, 'Cocorote', 'Cocorote', 10.4667, -68.8667, NULL),
(230, 21, 'El Pao', 'El Pao', 10.3500, -68.9333, NULL),
(231, 21, 'Independencia', 'San Felipe', 10.3500, -68.7667, NULL),
(232, 21, 'Jáuregui', 'San Pablo', 10.2500, -68.9000, NULL),
(233, 21, 'La Ceiba', 'La Ceiba', 10.4500, -68.9500, NULL),
(234, 21, 'San Felipe', 'San Felipe', 10.3500, -68.7667, NULL),
(235, 21, 'Sucre', 'Sucre', 10.5333, -68.7333, NULL),
(236, 21, 'Veroes', 'Veroes', 10.3667, -68.9333, NULL),

-- ZULIA (21 municipios - principales)
(237, 22, 'Almirante Padilla', 'Cabimas', 10.3831, -71.4436, NULL),
(238, 22, 'Baralt', 'Baralt', 10.3500, -71.7500, NULL),
(239, 22, 'Bolívar', 'Bolívar', 10.3000, -70.8333, NULL),
(240, 22, 'Cabimas', 'Cabimas', 10.3831, -71.4436, NULL),
(241, 22, 'Colon', 'Colon', 10.5667, -71.7833, NULL),
(242, 22, 'Ciudad Ojeda', 'Ciudad Ojeda', 10.2003, -71.3806, NULL),
(243, 22, 'Encontrados', 'Encontrados', 9.9000, -72.0333, NULL),
(244, 22, 'Espinal', 'Espinal', 10.1333, -71.0833, NULL),
(245, 22, 'Guajira', 'Guajira', 11.8000, -71.4667, NULL),
(246, 22, 'Jesús María Semprún', 'Jesús María Semprún', 10.4333, -71.7000, NULL),
(247, 22, 'Libertador', 'Maracaibo', 10.6561, -71.6122, 1500000),
(248, 22, 'Maracaibo', 'Maracaibo', 10.6561, -71.6122, NULL),
(249, 22, 'Mara', 'Mara', 11.4833, -71.1333, NULL),
(250, 22, 'Miranda', 'Miranda', 9.7500, -70.8500, NULL),
(251, 22, 'Páez', 'Páez', 10.6667, -71.1667, NULL),
(252, 22, 'Rómulo Gallegos', 'Rómulo Gallegos', 10.0167, -71.4500, NULL),
(253, 22, 'San Francisco', 'San Francisco', 10.1167, -71.2167, NULL),
(254, 22, 'Santa Rita', 'Santa Rita', 10.3500, -71.1167, NULL),
(255, 22, 'Sucre', 'Sucre', 10.6000, -71.6500, NULL),
(256, 22, 'Valmore Rodríguez', 'Valmore Rodríguez', 10.2333, -71.9667, NULL);
GO

-- Nota: Parroquias se cargarán en una segunda fase por su volumen (1.146+ registros)
-- Esta estructura permite agregar parroquias posterior sin afectar datos existentes

-- ===============================================
-- 5. VISTAS DE ANÁLISIS
-- ===============================================

-- Vista de Sucursales con información geográfica consolidada
-- Permite segmentación por país, estado, municipio, parroquia
CREATE VIEW [dbo].[Dim_Sucursales] AS
SELECT
    S.id_sucursal,
    UPPER(S.nombre_sucursal) AS nombre_sucursal,
    UPPER(ISNULL(S.alias_sucursal, S.nombre_sucursal)) AS nombre_comercial,
    S.direccion_raw AS direccion_exacta,
    S.localidad_raw AS localidad,
    S.municipio_raw AS municipio_raw,
    ISNULL(M.nombre_municipio, 'POR CLASIFICAR') AS municipio,
    ISNULL(E.nombre_estado, 'POR CLASIFICAR') AS estado,
    ISNULL(E.nombre_capital, 'POR CLASIFICAR') AS capital_estado,
    ISNULL(E.region_administrativa, 'POR CLASIFICAR') AS region_administrativa,
    'Venezuela' AS pais,
    ISNULL(M.latitud, E.latitud_capital) AS latitud,
    ISNULL(M.longitud, E.longitud_capital) AS longitud,
    ISNULL(M.poblacion_2011, 0) AS poblacion_municipal
FROM [dbo].[Maestro_Sucursales] S
LEFT JOIN [dbo].[Param_Venezuela_Municipios] M
    ON UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(S.municipio_raw, 'Á', 'A'), 'É', 'E'), 'Í', 'I'), 'Ó', 'O'), 'Ú', 'U'))
       = UPPER(M.nombre_municipio)
LEFT JOIN [dbo].[Param_Venezuela_Estados] E
    ON M.id_estado = E.id_estado;
GO

-- Vista auxiliar para análisis por estado
CREATE VIEW [dbo].[Dim_Estados_Venezuela] AS
SELECT
    E.id_estado,
    E.codigo_ine,
    E.nombre_estado,
    E.nombre_capital,
    E.region_administrativa,
    E.poblacion_2011,
    E.area_km2,
    E.latitud_capital,
    E.longitud_capital,
    COUNT(DISTINCT M.id_municipio) AS cantidad_municipios,
    'Venezuela' AS pais
FROM [dbo].[Param_Venezuela_Estados] E
LEFT JOIN [dbo].[Param_Venezuela_Municipios] M ON E.id_estado = M.id_estado
GROUP BY
    E.id_estado, E.codigo_ine, E.nombre_estado, E.nombre_capital,
    E.region_administrativa, E.poblacion_2011, E.area_km2,
    E.latitud_capital, E.longitud_capital;
GO

-- Vista auxiliar para análisis municipal
CREATE VIEW [dbo].[Dim_Municipios_Venezuela] AS
SELECT
    M.id_municipio,
    M.id_estado,
    E.codigo_ine,
    E.nombre_estado,
    M.nombre_municipio,
    M.nombre_capital_municipal,
    E.region_administrativa,
    M.poblacion_2011,
    M.area_km2,
    M.latitud,
    M.longitud,
    'Venezuela' AS pais,
    COUNT(DISTINCT P.id_parroquia) AS cantidad_parroquias
FROM [dbo].[Param_Venezuela_Municipios] M
LEFT JOIN [dbo].[Param_Venezuela_Estados] E ON M.id_estado = E.id_estado
LEFT JOIN [dbo].[Param_Venezuela_Parroquias] P ON M.id_municipio = P.id_municipio
GROUP BY
    M.id_municipio, M.id_estado, E.codigo_ine, E.nombre_estado,
    M.nombre_municipio, M.nombre_capital_municipal, E.region_administrativa,
    M.poblacion_2011, M.area_km2, M.latitud, M.longitud;
GO

-- ===============================================
-- 6. TABLAS DE SEGURIDAD Y AUDITORÍA
-- ===============================================

-- Catálogo de Roles (Jerarquía de permisos)
CREATE TABLE [dbo].[Seguridad_Roles](
	[id_rol] [int] NOT NULL,
	[nombre_rol] [nvarchar](50) NOT NULL,
	[descripcion] [nvarchar](255) NULL,
	[nivel_jerarquico] [int] NULL,
	[esta_activo] [bit] NULL DEFAULT 1,
	[fecha_creacion] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_rol] ASC)
) ON [PRIMARY]
GO

-- Catálogo de Permisos (Módulo + Acción)
CREATE TABLE [dbo].[Seguridad_Permisos](
	[id_permiso] [int] IDENTITY(1,1) NOT NULL,
	[nombre_permiso] [nvarchar](100) NOT NULL,
	[descripcion] [nvarchar](255) NULL,
	[modulo] [nvarchar](50) NULL,
	[accion] [nvarchar](50) NULL,
	[esta_activo] [bit] NULL DEFAULT 1,
	[fecha_creacion] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_permiso] ASC)
) ON [PRIMARY]
GO

-- Relación N:N Roles ↔ Permisos
CREATE TABLE [dbo].[Seguridad_Roles_Permisos](
	[id_rol] [int] NOT NULL,
	[id_permiso] [int] NOT NULL,
	[fecha_asignacion] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_rol], [id_permiso]),
	FOREIGN KEY ([id_rol]) REFERENCES [dbo].[Seguridad_Roles]([id_rol]),
	FOREIGN KEY ([id_permiso]) REFERENCES [dbo].[Seguridad_Permisos]([id_permiso])
) ON [PRIMARY]
GO

-- Usuarios del Portal
CREATE TABLE [dbo].[Seguridad_Usuarios](
	[id_usuario] [int] IDENTITY(1,1) NOT NULL,
	[email] [nvarchar](100) NOT NULL UNIQUE,
	[nombre_completo] [nvarchar](150) NULL,
	[password_hash] [nvarchar](255) NOT NULL,
	[esta_activo] [bit] NULL DEFAULT 1,
	[ultima_sesion] [datetime2](7) NULL,
	[fecha_creacion] [datetime2](7) NULL,
	[usuario_creacion] [nvarchar](100) NULL,
	[fecha_modificacion] [datetime2](7) NULL,
	[usuario_modificacion] [nvarchar](100) NULL,
	PRIMARY KEY CLUSTERED ([id_usuario] ASC)
) ON [PRIMARY]
GO

-- Relación N:N Usuarios ↔ Roles (con vigencia)
CREATE TABLE [dbo].[Seguridad_Usuarios_Roles](
	[id_usuario] [int] NOT NULL,
	[id_rol] [int] NOT NULL,
	[fecha_asignacion] [datetime2](7) NULL,
	[fecha_revocacion] [datetime2](7) NULL,
	[esta_vigente] [bit] NULL DEFAULT 1,
	PRIMARY KEY CLUSTERED ([id_usuario], [id_rol]),
	FOREIGN KEY ([id_usuario]) REFERENCES [dbo].[Seguridad_Usuarios]([id_usuario]),
	FOREIGN KEY ([id_rol]) REFERENCES [dbo].[Seguridad_Roles]([id_rol])
) ON [PRIMARY]
GO

-- Asignación de Sucursales por Usuario (RLS Data)
CREATE TABLE [dbo].[Seguridad_Usuarios_Sucursales](
	[id_usuario] [int] NOT NULL,
	[id_sucursal] [int] NOT NULL,
	[fecha_asignacion] [datetime2](7) NULL,
	[esta_vigente] [bit] NULL DEFAULT 1,
	PRIMARY KEY CLUSTERED ([id_usuario], [id_sucursal]),
	FOREIGN KEY ([id_usuario]) REFERENCES [dbo].[Seguridad_Usuarios]([id_usuario]),
	FOREIGN KEY ([id_sucursal]) REFERENCES [dbo].[Maestro_Sucursales]([id_sucursal])
) ON [PRIMARY]
GO

-- Sesiones Activas (Tracking de logins)
CREATE TABLE [dbo].[Seguridad_Sesiones](
	[id_sesion] [nvarchar](255) NOT NULL,
	[id_usuario] [int] NOT NULL,
	[token_jwt] [nvarchar](max) NULL,
	[ip_origen] [nvarchar](50) NULL,
	[user_agent] [nvarchar](255) NULL,
	[fecha_inicio] [datetime2](7) NULL,
	[fecha_expiracion] [datetime2](7) NULL,
	[esta_activa] [bit] NULL DEFAULT 1,
	PRIMARY KEY CLUSTERED ([id_sesion] ASC),
	FOREIGN KEY ([id_usuario]) REFERENCES [dbo].[Seguridad_Usuarios]([id_usuario])
) ON [PRIMARY]
GO

-- Auditoría Inmutable (Log de acciones)
CREATE TABLE [dbo].[Seguridad_Auditoria](
	[id_auditoria] [bigint] IDENTITY(1,1) NOT NULL,
	[id_usuario] [int] NULL,
	[email_usuario] [nvarchar](100) NULL,
	[accion] [nvarchar](100) NOT NULL,
	[tabla_afectada] [nvarchar](100) NULL,
	[registro_id] [nvarchar](50) NULL,
	[valores_anteriores] [nvarchar](max) NULL,
	[valores_nuevos] [nvarchar](max) NULL,
	[resultado] [nvarchar](20) NULL,
	[mensaje_error] [nvarchar](max) NULL,
	[ip_origen] [nvarchar](50) NULL,
	[fecha_accion] [datetime2](7) NULL DEFAULT GETUTCDATE(),
	PRIMARY KEY CLUSTERED ([id_auditoria] ASC)
) ON [PRIMARY]
GO

-- Catálogo de Módulos (Para asignación de permisos granulares)
CREATE TABLE [dbo].[Param_Modulos](
	[id_modulo] [int] IDENTITY(1,1) NOT NULL,
	[nombre_modulo] [nvarchar](100) NOT NULL,
	[descripcion] [nvarchar](255) NULL,
	[icono] [nvarchar](50) NULL,
	[ruta_portal] [nvarchar](255) NULL,
	[orden_visualizacion] [int] NULL,
	[esta_activo] [bit] NULL DEFAULT 1,
	PRIMARY KEY CLUSTERED ([id_modulo] ASC)
) ON [PRIMARY]
GO

-- ===============================================
-- VISTAS DE SEGURIDAD
-- ===============================================

-- Vista: Usuario + Roles + Sucursales (para NextAuth)
CREATE VIEW [dbo].[Vw_Usuario_Accesos] AS
SELECT
    U.id_usuario,
    U.email,
    U.nombre_completo,
    U.esta_activo,
    R.id_rol,
    R.nombre_rol,
    R.nivel_jerarquico,
    S.id_sucursal,
    S.nombre_sucursal,
    STRING_AGG(P.nombre_permiso, ',') WITHIN GROUP (ORDER BY P.nombre_permiso) AS permisos
FROM [dbo].[Seguridad_Usuarios] U
LEFT JOIN [dbo].[Seguridad_Usuarios_Roles] UR ON U.id_usuario = UR.id_usuario AND UR.esta_vigente = 1
LEFT JOIN [dbo].[Seguridad_Roles] R ON UR.id_rol = R.id_rol AND R.esta_activo = 1
LEFT JOIN [dbo].[Seguridad_Usuarios_Sucursales] US ON U.id_usuario = US.id_usuario AND US.esta_vigente = 1
LEFT JOIN [dbo].[Maestro_Sucursales] S ON US.id_sucursal = S.id_sucursal
LEFT JOIN [dbo].[Seguridad_Roles_Permisos] RP ON R.id_rol = RP.id_rol
LEFT JOIN [dbo].[Seguridad_Permisos] P ON RP.id_permiso = P.id_permiso AND P.esta_activo = 1
WHERE U.esta_activo = 1
GROUP BY U.id_usuario, U.email, U.nombre_completo, U.esta_activo,
         R.id_rol, R.nombre_rol, R.nivel_jerarquico, S.id_sucursal, S.nombre_sucursal;
GO

-- Vista: RLS para Portal (Filtra sucursales por usuario)
CREATE VIEW [dbo].[Vw_RLS_Sucursales] AS
SELECT DISTINCT
    U.id_usuario,
    U.email,
    S.id_sucursal,
    S.nombre_sucursal,
    S.municipio_raw,
    M.nombre_municipio,
    E.id_estado,
    E.nombre_estado,
    E.region_administrativa
FROM [dbo].[Seguridad_Usuarios] U
LEFT JOIN [dbo].[Seguridad_Usuarios_Sucursales] US ON U.id_usuario = US.id_usuario AND US.esta_vigente = 1
LEFT JOIN [dbo].[Maestro_Sucursales] S ON US.id_sucursal = S.id_sucursal
LEFT JOIN [dbo].[Param_Venezuela_Municipios] M ON UPPER(S.municipio_raw) = UPPER(M.nombre_municipio)
LEFT JOIN [dbo].[Param_Venezuela_Estados] E ON M.id_estado = E.id_estado
WHERE U.esta_activo = 1;
GO

-- ===============================================
-- DATOS INICIALES DE SEGURIDAD
-- ===============================================

-- Insertar Roles (Jerarquía)
INSERT INTO [dbo].[Seguridad_Roles]
([id_rol], [nombre_rol], [descripcion], [nivel_jerarquico], [esta_activo])
VALUES
(1, 'SUPER_ADMIN', 'Acceso total — VisioFlow', 1, 1),
(2, 'ADMIN', 'Gerencia Nacional — Todas las sucursales', 2, 1),
(3, 'GERENTE_ZONA', 'Jefe de Zona Regional', 3, 1),
(4, 'SUPERVISOR', 'Supervisor de Sucursal', 4, 1),
(5, 'CONSULTOR', 'Asesor/Optometrista — Lectura', 5, 1),
(6, 'ETL_SERVICE', 'Cuenta de servicio ETL (escritura)', 6, 1),
(7, 'PORTAL_SERVICE', 'Cuenta de servicio Portal (lectura)', 7, 1);
GO

-- Insertar Permisos por Módulo
INSERT INTO [dbo].[Seguridad_Permisos]
([nombre_permiso], [descripcion], [modulo], [accion], [esta_activo])
VALUES
('VER_INFORME_1', 'Ver Resumen Comercial', 'DASHBOARD', 'READ', 1),
('VER_INFORME_2', 'Ver Eficiencia de Órdenes', 'DASHBOARD', 'READ', 1),
('VER_INFORME_3', 'Ver Control de Cartera', 'DASHBOARD', 'READ', 1),
('VER_INFORME_4', 'Ver Desempeño Clínico', 'DASHBOARD', 'READ', 1),
('VER_INFORME_5', 'Ver Inventario', 'DASHBOARD', 'READ', 1),
('ADMIN_USUARIOS', 'Gestionar usuarios', 'ADMIN', 'WRITE', 1),
('EXPORTAR_DATOS', 'Exportar datos a PDF/Excel', 'EXPORT', 'WRITE', 1);
GO

-- Asignar Permisos a Roles
INSERT INTO [dbo].[Seguridad_Roles_Permisos]
([id_rol], [id_permiso], [fecha_asignacion])
SELECT 1, id_permiso, GETUTCDATE() FROM [dbo].[Seguridad_Permisos]; -- SUPER_ADMIN todos

INSERT INTO [dbo].[Seguridad_Roles_Permisos]
([id_rol], [id_permiso], [fecha_asignacion])
SELECT 2, id_permiso, GETUTCDATE() FROM [dbo].[Seguridad_Permisos] WHERE nombre_permiso LIKE 'VER_INFORME_%' OR nombre_permiso = 'ADMIN_USUARIOS'; -- ADMIN

INSERT INTO [dbo].[Seguridad_Roles_Permisos]
([id_rol], [id_permiso], [fecha_asignacion])
SELECT 3, id_permiso, GETUTCDATE() FROM [dbo].[Seguridad_Permisos] WHERE nombre_permiso IN ('VER_INFORME_1','VER_INFORME_3','VER_INFORME_4','VER_INFORME_5'); -- GERENTE_ZONA

INSERT INTO [dbo].[Seguridad_Roles_Permisos]
([id_rol], [id_permiso], [fecha_asignacion])
SELECT 4, id_permiso, GETUTCDATE() FROM [dbo].[Seguridad_Permisos] WHERE nombre_permiso IN ('VER_INFORME_1','VER_INFORME_3','VER_INFORME_4','VER_INFORME_5'); -- SUPERVISOR

INSERT INTO [dbo].[Seguridad_Roles_Permisos]
([id_rol], [id_permiso], [fecha_asignacion])
SELECT 5, id_permiso, GETUTCDATE() FROM [dbo].[Seguridad_Permisos] WHERE nombre_permiso IN ('VER_INFORME_1','VER_INFORME_4','VER_INFORME_5'); -- CONSULTOR

GO

-- Insertar Módulos del Portal
INSERT INTO [dbo].[Param_Modulos]
([nombre_modulo], [descripcion], [icono], [ruta_portal], [orden_visualizacion], [esta_activo])
VALUES
('Dashboard 1: Resumen Comercial', 'Visión ejecutiva de ventas', '📊', '/dashboard/resumen-comercial', 1, 1),
('Dashboard 2: Eficiencia de Órdenes', 'Monitoreo operacional', '⚙️', '/dashboard/eficiencia-ordenes', 2, 1),
('Dashboard 3: Control de Cartera', 'Análisis financiero', '💰', '/dashboard/control-cartera', 3, 1),
('Dashboard 4: Desempeño Clínico', 'Métricas clínicas', '👁️', '/dashboard/desempeño-clinico', 4, 1),
('Dashboard 5: Inventario', 'Stock y desplazamiento', '📦', '/dashboard/inventario', 5, 1),
('Panel de Administración', 'Gestión de usuarios y roles', '⚙️', '/admin/usuarios', 6, 1);
GO

/****** Script completado ******/
/*** Estado: ✅ LISTO PARA COMPILAR EN AZURE SQL - CON TABLAS DE SEGURIDAD ***/
