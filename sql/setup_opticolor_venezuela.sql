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
-- 4. TABLAS PARAMETRIZADAS (VENEZUELA)
-- ===============================================

-- Geografía de Venezuela (Estados y Municipios)
CREATE TABLE [dbo].[Param_Venezuela_Geografia](
	[id_geo] [int] IDENTITY(1,1) NOT NULL,
	[estado] [nvarchar](100) NOT NULL,
	[municipio] [nvarchar](100) NOT NULL,
	[ciudad_principal] [nvarchar](100) NULL,
	[latitud] [decimal](10, 8) NULL,
	[longitud] [decimal](11, 8) NULL,
	[fecha_creacion] [datetime2](7) NULL,
	PRIMARY KEY CLUSTERED ([id_geo] ASC)
) ON [PRIMARY]
GO

-- Insertar datos de geografía de Venezuela
INSERT INTO [dbo].[Param_Venezuela_Geografia]
([estado], [municipio], [ciudad_principal], [latitud], [longitud])
VALUES
('Distrito Capital', 'Libertador', 'Caracas', 10.4806, -66.9036),
('Miranda', 'Chacao', 'Chacao', 10.4909, -66.8427),
('Miranda', 'Baruta', 'Baruta', 10.3850, -66.8294),
('Carabobo', 'Valencia', 'Valencia', 10.1926, -68.0065),
('Aragua', 'Maracay', 'Maracay', 10.2343, -67.5917),
('Zulia', 'Maracaibo', 'Maracaibo', 10.6561, -71.6122),
('Lara', 'Barquisimeto', 'Barquisimeto', 10.0664, -69.3227),
('Táchira', 'San Cristóbal', 'San Cristóbal', 7.7692, -72.2254),
('Mérida', 'Mérida', 'Mérida', 8.5890, -71.1560),
('Anzoátegui', 'Barcelona', 'Barcelona', 10.1274, -64.6801);
GO

-- ===============================================
-- 5. VISTAS DE ANÁLISIS
-- ===============================================

-- Vista de Sucursales con información consolidada
CREATE VIEW [dbo].[Dim_Sucursales] AS
SELECT
    S.id_sucursal,
    UPPER(S.nombre_sucursal) AS nombre_sucursal,
    UPPER(ISNULL(S.alias_sucursal, S.nombre_sucursal)) AS nombre_comercial,
    S.municipio_raw AS municipio,
    S.localidad_raw AS localidad,
    S.direccion_raw AS direccion_exacta,
    ISNULL(G.estado, 'POR CLASIFICAR') AS estado,
    ISNULL(G.ciudad_principal, 'POR CLASIFICAR') AS ciudad_principal,
    ISNULL(G.latitud, 0) AS latitud,
    ISNULL(G.longitud, 0) AS longitud
FROM [dbo].[Maestro_Sucursales] S
LEFT JOIN [dbo].[Param_Venezuela_Geografia] G
    ON UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(S.municipio_raw, 'Á', 'A'), 'É', 'E'), 'Í', 'I'), 'Ó', 'O'), 'Ú', 'U'))
       = UPPER(G.municipio);
GO

/****** Script completado ******/
/*** Estado: ✅ LISTO PARA COMPILAR EN AZURE SQL ***/
