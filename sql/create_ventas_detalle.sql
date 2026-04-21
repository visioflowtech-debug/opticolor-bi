-- ============================================================
-- CREAR TABLA VENTAS_DETALLE - Opticolor Venezuela
-- Copiado desde Optilux Panamá (Estructura Completa)
-- Fecha: 2026-04-21
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Ventas_Detalle](
	[id_factura] [int] NOT NULL,
	[id_linea] [int] NOT NULL,
	[id_producto] [int] NULL,
	[cantidad] [decimal](18, 4) NULL,
	[precio_unitario] [decimal](18, 4) NULL,
	[total_linea] [decimal](18, 4) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	CONSTRAINT [PK_Ventas_Detalle] PRIMARY KEY CLUSTERED
	(
		[id_factura] ASC,
		[id_linea] ASC
	) WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

-- Default: timestamp actual en fecha_carga_etl
ALTER TABLE [dbo].[Ventas_Detalle] ADD DEFAULT (getdate()) FOR [fecha_carga_etl]
GO

-- Foreign Key: id_factura → Ventas_Cabecera
ALTER TABLE [dbo].[Ventas_Detalle] WITH CHECK ADD CONSTRAINT [FK_Detalle_Factura] FOREIGN KEY([id_factura])
REFERENCES [dbo].[Ventas_Cabecera] ([id_factura])
GO

ALTER TABLE [dbo].[Ventas_Detalle] CHECK CONSTRAINT [FK_Detalle_Factura]
GO

-- Foreign Key: id_producto → Maestro_Productos
ALTER TABLE [dbo].[Ventas_Detalle] WITH CHECK ADD CONSTRAINT [FK_Detalle_Producto] FOREIGN KEY([id_producto])
REFERENCES [dbo].[Maestro_Productos] ([id_producto])
GO

ALTER TABLE [dbo].[Ventas_Detalle] CHECK CONSTRAINT [FK_Detalle_Producto]
GO

PRINT 'Tabla Ventas_Detalle creada exitosamente con FK a Ventas_Cabecera y Maestro_Productos.'
