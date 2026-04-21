-- ============================================================
-- CREAR TABLA VENTAS_DETALLE - Opticolor Venezuela
-- Copiado desde Optilux Panamá
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
	PRIMARY KEY CLUSTERED
	(
		[id_factura] ASC,
		[id_linea] ASC
	) WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

PRINT 'Tabla Ventas_Detalle creada exitosamente.'
