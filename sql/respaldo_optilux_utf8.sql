/****** Object:  Database [db-optilux-dw]    Script Date: 6/4/2026 12:16:23 ******/
CREATE DATABASE [db-optilux-dw]  (EDITION = 'Basic', SERVICE_OBJECTIVE = 'Basic', MAXSIZE = 2 GB) WITH CATALOG_COLLATION = SQL_Latin1_General_CP1_CI_AS, LEDGER = OFF;
GO
ALTER DATABASE [db-optilux-dw] SET COMPATIBILITY_LEVEL = 170
GO
ALTER DATABASE [db-optilux-dw] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [db-optilux-dw] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [db-optilux-dw] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [db-optilux-dw] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [db-optilux-dw] SET ARITHABORT OFF 
GO
ALTER DATABASE [db-optilux-dw] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [db-optilux-dw] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [db-optilux-dw] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [db-optilux-dw] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [db-optilux-dw] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [db-optilux-dw] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [db-optilux-dw] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [db-optilux-dw] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [db-optilux-dw] SET ALLOW_SNAPSHOT_ISOLATION ON 
GO
ALTER DATABASE [db-optilux-dw] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [db-optilux-dw] SET READ_COMMITTED_SNAPSHOT ON 
GO
ALTER DATABASE [db-optilux-dw] SET  MULTI_USER 
GO
ALTER DATABASE [db-optilux-dw] SET ENCRYPTION ON
GO
ALTER DATABASE [db-optilux-dw] SET QUERY_STORE = ON
GO
ALTER DATABASE [db-optilux-dw] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 7), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 10, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, WAIT_STATS_CAPTURE_MODE = ON)
GO
/*** Los scripts de las configuraciones con ámbito de base de datos en Azure deben ejecutarse dentro de la conexión de base de datos de destino. ***/
GO
-- ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 8;
GO
/****** Object:  Table [dbo].[Zoho_Gastos]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Zoho_Gastos](
	[id_gasto_zoho] [varchar](100) NOT NULL,
	[fecha_gasto] [date] NULL,
	[monto] [decimal](18, 2) NULL,
	[descripcion] [nvarchar](max) NULL,
	[proveedor] [nvarchar](500) NULL,
	[cuenta_contable] [nvarchar](500) NULL,
	[estatus_pago] [varchar](50) NULL,
	[fecha_carga_etl] [datetime] NULL,
	[last_modified_time] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_gasto_zoho] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Zoho_Gastos]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   VIEW [dbo].[Fact_Zoho_Gastos] AS
SELECT 
    id_gasto_zoho,
    CAST(fecha_gasto AS DATE) AS fecha_gasto,
    
    -- Dimensiones descriptivas (Normalizadas para evitar nulos en Power BI)
    ISNULL(proveedor, 'Sin Proveedor') AS proveedor,
    ISNULL(cuenta_contable, 'Sin Clasificar') AS cuenta_contable,
    ISNULL(descripcion, '') AS descripcion,
    ISNULL(estatus_pago, 'Desconocido') AS estatus_pago,
    
    -- Medidas Numéricas
    monto AS monto_total,
    -- Cálculo de base imponible (ITBMS 7% estándar Panamá)
    CAST(monto / 1.07 AS DECIMAL(18,4)) AS monto_sin_itbms,
    CAST(monto - (monto / 1.07) AS DECIMAL(18,4)) AS monto_itbms_estimado,

    -- INTELIGENCIA DE FECHAS (Estandarizada según tus otras tablas de Hechos)
    YEAR(fecha_gasto) AS anio_gasto,
    MONTH(fecha_gasto) AS mes_gasto_nro,
    CHOOSE(MONTH(fecha_gasto), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_gasto_nombre,
    CONCAT(YEAR(fecha_gasto), '-', RIGHT('0' + CAST(MONTH(fecha_gasto) AS VARCHAR(2)), 2)) AS periodo_gasto,

    -- Auditoría
    fecha_carga_etl,
    last_modified_time
FROM Zoho_Gastos
WHERE fecha_gasto >= '2025-01-01';
GO
/****** Object:  View [dbo].[Dim_Zoho_Cuentas]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

  CREATE   VIEW [dbo].[Dim_Zoho_Cuentas] AS
SELECT 
    DISTINCT cuenta_contable AS [Cuenta_Nombre],
    -- Lógica de categorización preliminar (puedes ajustarla según tu catálogo)
    CASE 
        WHEN cuenta_contable LIKE '%Publicidad%' OR cuenta_contable LIKE '%Marketing%' OR cuenta_contable LIKE '%Redes%' THEN 'Marketing'
        WHEN cuenta_contable LIKE '%Salario%' OR cuenta_contable LIKE '%Honorario%' THEN 'Personal'
        WHEN cuenta_contable LIKE '%Alquiler%' OR cuenta_contable LIKE '%Luz%' OR cuenta_contable LIKE '%Agua%' THEN 'Operativos'
        ELSE 'Otros Gastos'
    END AS [Categoria_Gasto]
FROM [dbo].[Zoho_Gastos]
WHERE cuenta_contable IS NOT NULL;
GO
/****** Object:  View [dbo].[Dim_Zoho_Proveedores]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   VIEW [dbo].[Dim_Zoho_Proveedores] AS
SELECT 
    DISTINCT ISNULL(NULLIF(proveedor, ''), 'Sin Proveedor') AS [Proveedor_Nombre],
    COUNT(*) as [Frecuencia_Gastos] -- Atributo útil para saber qué tan recurrente es el proveedor
FROM [dbo].[Zoho_Gastos]
GROUP BY proveedor;
GO
/****** Object:  Table [dbo].[GHL_Citas]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GHL_Citas](
	[id_cita_ghl] [varchar](100) NOT NULL,
	[id_contacto_ghl] [varchar](100) NULL,
	[id_calendario] [varchar](100) NULL,
	[titulo_cita] [nvarchar](max) NULL,
	[estado_cita] [varchar](50) NULL,
	[fecha_inicio] [datetime] NULL,
	[fecha_fin] [datetime] NULL,
	[id_usuario_asignado] [varchar](100) NULL,
	[fecha_creacion] [datetime] NULL,
	[fecha_carga_etl] [datetime] NULL,
	[id_grupo_calendario] [varchar](100) NULL,
	[notas_cita] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_cita_ghl] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[GHL_Calendarios]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GHL_Calendarios](
	[id_calendario] [varchar](100) NOT NULL,
	[nombre_calendario] [nvarchar](255) NULL,
	[descripcion] [nvarchar](max) NULL,
	[fecha_carga_etl] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_calendario] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_GHL_Citas]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Fact_GHL_Citas] AS
SELECT 
    id_cita_ghl,
    id_contacto_ghl,
    id_calendario,
    
    -- Traducción comercial de estados
    CASE 
        WHEN estado_cita = 'showed' THEN 'Asistió'
        WHEN estado_cita = 'noshow' THEN 'Faltó'
        WHEN estado_cita = 'confirmed' THEN 'Confirmada'
        WHEN estado_cita = 'cancelled' THEN 'Cancelada'
        ELSE 'Pendiente'
    END AS estado_cita_comercial,
    
    ISNULL(titulo_cita, '') AS titulo_cita,
    
    -- Ajuste a GMT-5 Panamá
    CAST(DATEADD(HOUR, -5, fecha_inicio) AS DATE) AS fecha_cita,
    
    -- Inteligencia de Tiempo
    YEAR(DATEADD(HOUR, -5, fecha_inicio)) AS anio_cita,
    MONTH(DATEADD(HOUR, -5, fecha_inicio)) AS mes_cita_nro,
    -- ... (Aquí mantén el CHOOSE de mes y periodo que tenías en tu vista original) ...
    
    id_usuario_asignado,
    fecha_creacion AS fecha_creacion_sistema

FROM GHL_Citas

WHERE fecha_inicio >= '2025-01-01'
  AND estado_cita <> 'invalid'
  AND id_calendario IS NOT NULL 
  AND id_calendario <> ''
  
  -- EL FILTRO DEFINITIVO MEJORADO: 
  -- Dejamos pasar todas las sucursales Optilux Y la Unidad Empresarial
  AND id_calendario IN (
      SELECT id_calendario 
      FROM GHL_Calendarios 
      WHERE nombre_calendario LIKE 'Optilux%' 
         OR nombre_calendario = 'Unidad Empresarial'
  );
GO
/****** Object:  Table [dbo].[GHL_Oportunidades]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GHL_Oportunidades](
	[id_oportunidad_ghl] [varchar](50) NOT NULL,
	[nombre_oportunidad] [nvarchar](255) NULL,
	[id_contacto_ghl] [varchar](50) NULL,
	[monto_valor] [decimal](18, 2) NULL,
	[estado_oportunidad] [varchar](50) NULL,
	[status_open_won_lost] [varchar](50) NULL,
	[id_pipeline] [varchar](100) NULL,
	[id_etapa_pipeline] [varchar](100) NULL,
	[origen_oportunidad] [nvarchar](255) NULL,
	[fecha_creacion] [datetime] NULL,
	[fecha_actualizacion] [datetime] NULL,
	[fecha_ultimo_cambio_estado] [datetime] NULL,
	[fecha_ultimo_cambio_etapa] [datetime] NULL,
	[fecha_carga_etl] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_oportunidad_ghl] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_GHL_Oportunidades]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Fact_GHL_Oportunidades] AS
WITH CitasRanking AS (
    SELECT 
        id_contacto_ghl,
        UPPER(notas_cita) AS nota_up,
        CASE 
            WHEN notas_cita LIKE '%REDES%' OR notas_cita LIKE '%FACE%' OR notas_cita LIKE '%INSTA%' 
                 OR notas_cita LIKE '%TIK%' OR notas_cita LIKE '%GOOGLE%' OR notas_cita LIKE '%REDS%' THEN 'REDES SOCIALES'
            WHEN notas_cita LIKE '%WHATS%' OR notas_cita LIKE '%WATS%' THEN 'WHATSAPP'
            WHEN notas_cita LIKE '%KREDI%' THEN 'KREDIYA'
            WHEN notas_cita LIKE '%LETRE%' OR notas_cita LIKE '%VALLA%' OR notas_cita LIKE '%PLAZA%' THEN 'LETRERO'
            WHEN notas_cita LIKE '%REFER%' OR notas_cita LIKE '%AMIG%' OR notas_cita LIKE '%FAMILI%' THEN 'AMIGO O FAMILIAR'
            ELSE 'OTROS'
        END AS motivo_cita,
        ROW_NUMBER() OVER(PARTITION BY id_contacto_ghl ORDER BY fecha_inicio DESC) as rnk
    FROM GHL_Citas
    WHERE notas_cita IS NOT NULL
)
SELECT 
    O.id_oportunidad_ghl,
    O.id_contacto_ghl,
    O.nombre_oportunidad,
    ISNULL(O.monto_valor, 0) AS monto_valor,
    ISNULL(O.estado_oportunidad, 'open') AS estado_oportunidad,
    CAST(DATEADD(HOUR, -5, O.fecha_creacion) AS DATE) AS fecha_oportunidad,
    YEAR(DATEADD(HOUR, -5, O.fecha_creacion)) AS anio_oportunidad,
    CHOOSE(MONTH(DATEADD(HOUR, -5, O.fecha_creacion)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_oportunidad_nombre,

    -- LÓGICA DE CATEGORIZACIÓN MAESTRA (EL FILTRO DEFINITIVO)
    UPPER(CASE 
        -- 1. Prioridad: Lo que diga la cita (si existe)
        WHEN C.motivo_cita IS NOT NULL AND C.motivo_cita <> 'OTROS' THEN C.motivo_cita

        -- 2. Mapeo de Asesoras -> REDES SOCIALES
        WHEN O.origen_oportunidad LIKE '%daisy%' OR O.origen_oportunidad LIKE '%carmen%' 
             OR O.origen_oportunidad LIKE '%glendy%' OR O.origen_oportunidad LIKE '%joelys%' 
             OR O.origen_oportunidad LIKE '%dayana%' OR O.origen_oportunidad LIKE '%yoany%'
             OR O.origen_oportunidad LIKE '%karudas%' OR O.origen_oportunidad LIKE '%genesis%'
             OR O.origen_oportunidad LIKE '%gabi%' OR O.origen_oportunidad LIKE '%yanelis%'
             OR O.origen_oportunidad LIKE '%zugeily%' OR O.origen_oportunidad LIKE '%_asesora%' 
             OR O.origen_oportunidad LIKE '%y_cortes%' THEN 'REDES SOCIALES'
        
        -- 3. Mapeo de Sucursales -> LETRERO
        WHEN O.origen_oportunidad LIKE '%Optilux%' OR O.origen_oportunidad LIKE '%Plaza%' 
             OR O.origen_oportunidad LIKE '%Villa%' OR O.origen_oportunidad LIKE '%Chorrera%' 
             OR O.origen_oportunidad LIKE '%Westland%' OR O.origen_oportunidad LIKE '%Pueblos%'
             OR O.origen_oportunidad LIKE '%Verde%' THEN 'LETRERO'

        -- 4. Lo demás es sistema o desconocido
        WHEN O.origen_oportunidad LIKE '%IMPORTA%' THEN 'OTROS / DESCONOCIDO'
        
        ELSE 'OTROS / DESCONOCIDO'
    END) AS origen_oportunidad

FROM GHL_Oportunidades O
LEFT JOIN CitasRanking C ON O.id_contacto_ghl = C.id_contacto_ghl AND C.rnk = 1
WHERE O.fecha_creacion >= '2025-01-01';
GO
/****** Object:  View [dbo].[Dim_GHL_Calendarios]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   VIEW [dbo].[Dim_GHL_Calendarios] AS
SELECT 
    id_calendario,
    nombre_calendario,
    ISNULL(descripcion, '') AS descripcion
FROM GHL_Calendarios;
GO
/****** Object:  Table [dbo].[GHL_Contactos]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GHL_Contactos](
	[id_contacto_ghl] [varchar](50) NOT NULL,
	[location_id] [varchar](50) NULL,
	[nombre] [nvarchar](255) NULL,
	[apellido] [nvarchar](255) NULL,
	[email] [nvarchar](255) NULL,
	[telefono] [varchar](50) NULL,
	[fecha_nacimiento] [datetime] NULL,
	[genero] [varchar](20) NULL,
	[profesion] [nvarchar](255) NULL,
	[tipo_contacto] [varchar](50) NULL,
	[ciudad] [nvarchar](255) NULL,
	[estado] [nvarchar](255) NULL,
	[pais] [varchar](10) NULL,
	[origen_source] [nvarchar](255) NULL,
	[utm_source] [nvarchar](255) NULL,
	[utm_medium] [nvarchar](255) NULL,
	[sucursal_nombre] [nvarchar](255) NULL,
	[doctor_asignado] [nvarchar](255) NULL,
	[estatus_paciente] [varchar](50) NULL,
	[tags_concatenados] [nvarchar](max) NULL,
	[fecha_creacion_ghl] [datetime] NULL,
	[fecha_actualizacion_ghl] [datetime] NULL,
	[fecha_carga_etl] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_contacto_ghl] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[Dim_GHL_Contactos]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Dim_GHL_Contactos] AS
SELECT 
    id_contacto_ghl,
    ISNULL(nombre, '') AS nombre,
    ISNULL(apellido, '') AS apellido,
    
    -- CORRECCIÓN: Forzamos mayúsculas y cortamos cualquier espacio sobrante en los extremos
    LTRIM(RTRIM(UPPER(CONCAT(ISNULL(nombre, ''), ' ', ISNULL(apellido, ''))))) AS nombre_completo,
    
    email,
    telefono,
    ISNULL(origen_source, 'Directo') AS origen_lead,
    ISNULL(utm_source, 'Organic') AS utm_source,
    ISNULL(utm_medium, 'None') AS utm_medium,
    genero,
    profesion,
    estatus_paciente,
    tags_concatenados
FROM GHL_Contactos;
GO
/****** Object:  Table [dbo].[Maestro_Sucursales]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Sucursales](
	[id_sucursal] [int] NOT NULL,
	[nombre_sucursal] [nvarchar](100) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	[municipio_raw] [nvarchar](100) NULL,
	[localidad_raw] [nvarchar](100) NULL,
	[direccion_raw] [nvarchar](max) NULL,
	[alias_sucursal] [nvarchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_sucursal] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Param_Panama_Geografia]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Param_Panama_Geografia](
	[id_geo] [int] IDENTITY(1,1) NOT NULL,
	[provincia] [nvarchar](100) NOT NULL,
	[distrito_municipio] [nvarchar](100) NOT NULL,
	[fecha_creacion] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_geo] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Dim_Sucursales]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Dim_Sucursales] AS
SELECT 
    S.id_sucursal,
    UPPER(S.nombre_sucursal) AS nombre_sucursal,
    UPPER(ISNULL(S.alias_sucursal, S.nombre_sucursal)) AS nombre_comercial,
    
    -- 1. Geografía estandarizada para filtros (Slicers)
    CASE 
        WHEN S.id_sucursal = 2 THEN 'PANAMA OESTE' 
        ELSE ISNULL(G.provincia, 'POR CLASIFICAR') 
    END AS provincia, 

    CASE 
        WHEN S.id_sucursal = 2 THEN 'LA CHORRERA' 
        ELSE ISNULL(G.distrito_municipio, 'POR CLASIFICAR') 
    END AS municipio,
    
    -- 2. LATITUD (Coordenadas de precisión)
    CASE 
        WHEN S.id_sucursal = 1 THEN 9.07192450004371   -- Los Pueblos
        WHEN S.id_sucursal = 2 THEN 8.88939647514824   -- La Chorrera
        WHEN S.id_sucursal = 3 THEN 8.901522636635596  -- Costa Verde
        WHEN S.id_sucursal = 4 THEN 9.127181830971045  -- Plaza Nuevo Tocumen
        WHEN S.id_sucursal = 5 THEN 9.012782012925616  -- Empresarial
        WHEN S.id_sucursal = 6 THEN 9.034290398574049  -- Santa Elena
        WHEN S.id_sucursal = 7 THEN 9.091587595193339  -- Villa Zaita
        WHEN S.id_sucursal = 8 THEN 8.926282498677525  -- Westland Mall
        WHEN S.id_sucursal = 9 THEN 9.012782012925616  -- Oficina
        WHEN S.id_sucursal = 10 THEN 8.451317989742805 -- David
        ELSE NULL 
    END AS latitud,

    -- 3. LONGITUD (Coordenadas de precisión)
    CASE 
        WHEN S.id_sucursal = 1 THEN -79.44900514599878
        WHEN S.id_sucursal = 2 THEN -79.78014988594377
        WHEN S.id_sucursal = 3 THEN -79.75087166196295
        WHEN S.id_sucursal = 4 THEN -79.35974123996317
        WHEN S.id_sucursal = 5 THEN -79.49777088583029
        WHEN S.id_sucursal = 6 THEN -79.50621032960797
        WHEN S.id_sucursal = 7 THEN -79.52223968644076
        WHEN S.id_sucursal = 8 THEN -79.70529557003863
        WHEN S.id_sucursal = 9 THEN -79.49777088583029
        WHEN S.id_sucursal = 10 THEN -82.44144610131612
        ELSE NULL 
    END AS longitud,

    S.direccion_raw AS direccion_exacta,
    
    CASE 
        WHEN S.nombre_sucursal LIKE '%Mall%' OR S.nombre_sucursal LIKE '%Multi%' THEN 'Centro Comercial'
        WHEN S.id_sucursal IN (5, 9) THEN 'Oficina/Corporativo'
        ELSE 'Sucursal Calle'
    END AS tipo_punto_venta

FROM Maestro_Sucursales S
LEFT JOIN Param_Panama_Geografia G 
    ON UPPER(
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(S.municipio_raw, 'Á', 'A'), 'É', 'E'), 'Í', 'I'), 'Ó', 'O'), 'Ú', 'U')
    ) = G.distrito_municipio;
GO
/****** Object:  View [dbo].[Dim_GHL_Sucursales_Link]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   VIEW [dbo].[Dim_GHL_Sucursales_Link] AS
SELECT 
    C.id_calendario,
    C.nombre_calendario,
    S.id_sucursal,
    S.nombre_sucursal,
    S.nombre_comercial
FROM [dbo].[GHL_Calendarios] C
INNER JOIN [dbo].[Dim_Sucursales] S 
    -- Buscamos el nombre comercial (ej: 'DAVID') dentro del nombre del calendario (ej: 'Optilux - David')
    -- Eliminamos espacios y pasamos a Mayúsculas para un match perfecto
    ON UPPER(C.nombre_calendario) LIKE '%' + UPPER(REPLACE(S.nombre_comercial, ' ', '%')) + '%'
    OR UPPER(S.nombre_comercial) LIKE '%' + UPPER(REPLACE(C.nombre_calendario, 'Optilux - ', '')) + '%'
GO
/****** Object:  Table [dbo].[Ventas_Cabecera]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Ventas_Cabecera](
	[id_factura] [int] NOT NULL,
	[id_sucursal] [int] NULL,
	[id_cliente] [int] NULL,
	[fecha_factura] [datetime2](7) NULL,
	[monto_total] [decimal](18, 4) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	[id_empleado] [int] NULL,
	[id_optometrista] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_factura] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Ventas]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE    VIEW [dbo].[Fact_Ventas] AS
SELECT 
    id_factura,
    -- Ajuste a GMT-5 para la fecha de la factura
    CAST(DATEADD(HOUR, -5, fecha_factura) AS DATE) AS fecha_factura,
    id_sucursal,
    id_cliente,
    -- Blindaje de Atribución
    ISNULL(id_empleado, 0) AS id_vendedor,     
    ISNULL(id_optometrista, -1) AS id_optometrista,
    monto_total,
    -- Clasificación para análisis de rentabilidad vs productividad
    CASE 
        WHEN monto_total < 0 THEN 'Devolución' 
        ELSE 'Venta' 
    END AS tipo_transaccion,
    -- Base imponible estimada (Cálculo para Panamá 7%)
    CAST(monto_total / 1.07 AS DECIMAL(18,4)) AS monto_sin_itbms,

    -- SEGMENTACIÓN DE FECHAS (Ajustada a GMT-5 Panamá)
    YEAR(DATEADD(HOUR, -5, fecha_factura)) AS anio_factura,
    MONTH(DATEADD(HOUR, -5, fecha_factura)) AS mes_factura_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, fecha_factura)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_factura_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -5, fecha_factura)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_factura
FROM Ventas_Cabecera
WHERE fecha_factura >= '2025-01-01';
GO
/****** Object:  Table [dbo].[Maestro_Empleados]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Empleados](
	[id_empleado] [int] NOT NULL,
	[nombre_empleado] [nvarchar](200) NULL,
	[id_sucursal] [int] NULL,
	[tipo_empleado] [varchar](10) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_empleado] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Dim_Empleados]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[Dim_Empleados] AS
SELECT 
    id_empleado,
    CASE 
        WHEN id_empleado = 0 THEN 'SISTEMA / DEVOLUCIONES'
        ELSE UPPER(nombre_empleado)
    END AS nombre_completo,
    tipo_empleado,
    id_sucursal
FROM Maestro_Empleados
UNION ALL
-- Registro para ventas retail o institucionales sin examen clínico
SELECT -1, 'VENTA RETAIL (SIN OPTOMETRISTA)', 'SISTEMA', 1;
GO
/****** Object:  Table [dbo].[Etl_Control_Ejecucion]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Etl_Control_Ejecucion](
	[modulo_nombre] [varchar](50) NOT NULL,
	[ultimo_estatus] [varchar](20) NOT NULL,
	[fecha_inicio] [datetime2](7) NULL,
	[fecha_fin] [datetime2](7) NULL,
	[mensaje_error] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[modulo_nombre] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[Vista_Notificacion_ETL]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[Vista_Notificacion_ETL] AS
SELECT 
    -- 1. Hora local de Panamá (UTC-5) basada en el último movimiento
    DATEADD(HOUR, -5, MAX(fecha_fin)) AS Fecha_Hora_Panama,
    
    -- 2. Texto amigable para el Card de Power BI
    'Sincronización: ' + FORMAT(DATEADD(HOUR, -5, MAX(fecha_fin)), 'dd/MM/yyyy hh:mm tt') AS Notificacion_Texto,
    
    -- 3. Lógica de Salud: Si hay algún módulo que no diga 'COMPLETADO', marca Error
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM [dbo].[Etl_Control_Ejecucion] 
            WHERE ultimo_estatus <> 'COMPLETADO' 
            AND modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO')
        ) THEN 'ERROR'
        ELSE 'OK'
    END AS Estado_Salud
FROM [dbo].[Etl_Control_Ejecucion]
WHERE modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO');
GO
/****** Object:  Table [dbo].[Maestro_Productos]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Productos](
	[id_producto] [int] NOT NULL,
	[nombre_producto] [nvarchar](255) NULL,
	[referencia] [varchar](255) NULL,
	[codigo_barras] [varchar](100) NULL,
	[costo_compra] [decimal](18, 4) NULL,
	[precio_venta] [decimal](18, 4) NULL,
	[id_marca] [int] NULL,
	[id_categoria] [int] NULL,
	[es_inventariable] [bit] NULL,
	[fecha_creacion] [datetime] NULL,
	[fecha_ultima_actualizacion] [datetime] NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	[nombre_modelo_padre] [varchar](255) NULL,
	[genero_objetivo] [varchar](50) NULL,
	[material_marco] [varchar](100) NULL,
	[color_comercial] [varchar](100) NULL,
	[tipo_montura] [varchar](100) NULL,
	[id_grupo] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_producto] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Ventas_Detalle]    Script Date: 6/4/2026 12:16:24 ******/
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
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Maestro_Categorias]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Categorias](
	[id_categoria] [int] NOT NULL,
	[nombre_categoria] [nvarchar](100) NULL,
	[id_categoria_padre] [int] NULL,
	[esta_activo] [bit] NULL,
	[fecha_actualizacion] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_categoria] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Ventas_Analitico]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Fact_Ventas_Analitico] AS
SELECT 
    -- 1. Identificadores y Datos de Transacción
    D.id_factura,
    D.id_linea,
    D.id_producto,
    D.cantidad,
    V.id_sucursal,
    
    -- 2. Datos Financieros
    D.precio_unitario AS precio_lista_unitario, 
    D.total_linea AS monto_final_transaccional, 
    CAST(D.total_linea - (D.cantidad * D.precio_unitario) AS DECIMAL(18,4)) AS ajuste_comercial_neto,

    -- 3. Atributos del Producto (Maestro_Productos)
    P.nombre_producto,
    P.nombre_modelo_padre,
    P.material_marco,
    P.tipo_montura,
    P.genero_objetivo,

    -- 4. Atributos de Categoría (Maestro_Categorias)
    C.nombre_categoria,
    C.id_categoria_padre,

    -- [NUEVO] Subclasificación de tecnología ESTANDARIZADA (Ajuste Colormatic)
    CASE 
        -- Transitions
        WHEN UPPER(P.nombre_producto) LIKE '%TRANSITION%' 
          OR UPPER(P.nombre_producto) LIKE '%TGENS%' THEN 'FOTOCROMATICO (TRANSITIONS)'
        
        -- Photomax
        WHEN UPPER(P.nombre_producto) LIKE '%PHOTOMAX%' 
          OR UPPER(P.nombre_producto) LIKE '%PHOTO MAX%' 
          OR UPPER(P.nombre_producto) LIKE '% PHOTO %' THEN 'FOTOCROMATICO (PHOTOMAX)'
          
        -- Colormatic (Rodenstock)
        WHEN UPPER(P.nombre_producto) LIKE '%COLORMATIC%' THEN 'FOTOCROMATICO (COLORMATIC)'
          
        -- Genéricos (Por si en el futuro escriben solo "fotocromático")
        WHEN UPPER(P.nombre_producto) LIKE '%FOTOCROMATICO%' 
          OR UPPER(P.nombre_producto) LIKE '%FOTOCROMÁTICO%' THEN 'FOTOCROMATICO (GENERICO)'
          
        -- Lentes Normales Blancos
        WHEN C.id_categoria IN (41, 45, 28) THEN 'NORMAL (BLANCO)'
        
        -- Truco de visualización: Aros y demás mantienen su categoría
        ELSE UPPER(C.nombre_categoria) 
    END AS subcategoria_lente,

    -- 5. INTELIGENCIA DE TIEMPO (Ajustada a GMT-5 Panamá)
    CAST(DATEADD(HOUR, -5, V.fecha_factura) AS DATE) AS fecha_factura,
    YEAR(DATEADD(HOUR, -5, V.fecha_factura)) AS anio_venta,
    MONTH(DATEADD(HOUR, -5, V.fecha_factura)) AS mes_venta_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, V.fecha_factura)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_venta_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -5, V.fecha_factura)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, V.fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_venta

FROM Ventas_Detalle D
INNER JOIN Ventas_Cabecera V ON D.id_factura = V.id_factura
INNER JOIN Maestro_Productos P ON D.id_producto = P.id_producto
INNER JOIN Maestro_Categorias C ON P.id_categoria = C.id_categoria;
GO
/****** Object:  Table [dbo].[Marketing_Citas]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Marketing_Citas](
	[id_cita_correlativo] [int] IDENTITY(1,1) NOT NULL,
	[id_cliente] [int] NULL,
	[nombre_cliente] [nvarchar](200) NULL,
	[fecha_cita_inicio] [datetime2](7) NULL,
	[fecha_cita_fin] [datetime2](7) NULL,
	[tipo_cita_id] [int] NULL,
	[tipo_cita_nombre] [nvarchar](100) NULL,
	[detalles_cita] [nvarchar](max) NULL,
	[fecha_creacion_cita] [datetime2](7) NULL,
	[fecha_actualizacion_api] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_cita_correlativo] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Ventas_Pedidos]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Ventas_Pedidos](
	[id_pedido] [int] NOT NULL,
	[numero_pedido] [varchar](50) NULL,
	[id_sucursal] [int] NULL,
	[id_cliente] [int] NULL,
	[id_empleado] [int] NULL,
	[fecha_pedido] [datetime2](7) NULL,
	[monto_total] [decimal](18, 4) NULL,
	[monto_pagado] [decimal](18, 4) NULL,
	[saldo_pendiente] [decimal](18, 4) NULL,
	[estado_pedido] [varchar](50) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	[id_estado_orden] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_pedido] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Pedidos]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Fact_Pedidos] AS
SELECT 
    id_pedido,
    numero_pedido,
    id_sucursal,
    id_cliente,
    id_empleado AS id_asesor,
    
    -- Métricas Financieras
    monto_total,
    monto_pagado,
    saldo_pendiente,
    estado_pedido AS [estado_pago_interno], -- Lo renombramos para no confundir pago con logística

    -- =========================================================
    -- NUEVA INTELIGENCIA LOGÍSTICA (Sincronizada con Gesvision)
    -- =========================================================
    id_estado_orden, 
    CASE ISNULL(id_estado_orden, -1)
        WHEN 6  THEN '6. POR ENVIAR'
        WHEN 7  THEN '7. EN LABORATORIO'
        WHEN 10 THEN '10. POR ENTREGAR'
        WHEN 13 THEN '13. ENTREGADO'
        WHEN 14 THEN '14. LC EN TRANSITO'
        WHEN 15 THEN '15. LC SOLICITADO'
        WHEN 17 THEN '17. POCO ABONO'
        ELSE '0. OTROS / SIN ESTADO'
    END AS [Estado_Orden_Detalle],

    -- INTELIGENCIA DE TIEMPO (Ajustada a GMT-5 Panamá)
    CAST(DATEADD(HOUR, -5, fecha_pedido) AS DATE) AS fecha_pedido_completa,
    YEAR(DATEADD(HOUR, -5, fecha_pedido)) AS anio_pedido,
    MONTH(DATEADD(HOUR, -5, fecha_pedido)) AS mes_pedido_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, fecha_pedido)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_pedido_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -5, fecha_pedido)), 
        '-', 
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, fecha_pedido)) AS VARCHAR(2)), 2)
    ) AS periodo_pedido
FROM Ventas_Pedidos
WHERE fecha_pedido >= '2025-01-01';
GO
/****** Object:  View [dbo].[Fact_Ventas_Por_Motivo]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Cambiamos ALTER por CREATE porque es la primera vez que la generas
CREATE VIEW [dbo].[Fact_Ventas_Por_Motivo] AS
WITH AgendaLimpia AS (
    SELECT 
        id_cliente,
        UPPER(detalles_cita) AS nota_raw,
        CASE 
            -- 1. REDES SOCIALES
            WHEN detalles_cita LIKE '%REDES%' OR detalles_cita LIKE '%INSTA%' OR detalles_cita LIKE '%FACE%' 
                 OR detalles_cita LIKE '%TIK%' OR detalles_cita LIKE '%GOOGLE%' THEN 'REDES SOCIALES'
            
            -- 2. LETRERO (Incluye la dirección de alta frecuencia y plazas)
            WHEN detalles_cita LIKE '%LETRE%' OR detalles_cita LIKE '%VALLA%' OR detalles_cita LIKE '%PLAZA%' 
                 OR detalles_cita LIKE '%AVENIDA 3 B SUR%' THEN 'LETRERO'
            
            -- 3. REFERIDOS (Amigos, Familiares y menciones a Jimenez/Quintero)
            WHEN detalles_cita LIKE '%REFER%' OR detalles_cita LIKE '%AMIG%' OR detalles_cita LIKE '%FAMILI%' 
                 OR detalles_cita LIKE '%RECOMEN%' OR detalles_cita LIKE '%JIMENEZ%' OR detalles_cita LIKE '%QUINTERO%' THEN 'REFERIDOS'
            
            -- 4. VOLANTEO
            WHEN detalles_cita LIKE '%VOLANT%' THEN 'VOLANTEO'
            
            -- 5. KREDIYA
            WHEN detalles_cita LIKE '%KREDI%' THEN 'KREDIYA'
            
            -- 6. CONVENIOS / EMPRESAS
            WHEN detalles_cita LIKE '%EMPRES%' OR detalles_cita LIKE '%CONVEN%' OR detalles_cita LIKE '%BANCO%' 
                 OR detalles_cita LIKE '%LICITA%' THEN 'CONVENIOS'
            
            ELSE 'OTROS / LLEGADA DIRECTA'
        END AS motivo_real,
        -- Obtenemos solo la última cita de cada cliente para no duplicar ventas
        ROW_NUMBER() OVER(PARTITION BY id_cliente ORDER BY fecha_creacion_cita DESC) as rnk
    FROM [dbo].[Marketing_Citas]
    WHERE detalles_cita IS NOT NULL AND detalles_cita <> ''
)
SELECT 
    P.id_pedido,
    P.id_cliente,
    P.monto_total,
    P.fecha_pedido_completa AS fecha,
    -- Cruzamos el dinero con el motivo de la agenda clínica
    ISNULL(A.motivo_real, 'OTROS / LLEGADA DIRECTA') AS motivo_visita,
    ISNULL(A.nota_raw, 'SIN NOTA EN AGENDA') AS nota_auditoria
FROM [dbo].[Fact_Pedidos] P
LEFT JOIN AgendaLimpia A ON P.id_cliente = A.id_cliente AND A.rnk = 1
WHERE P.anio_pedido = 2026;
GO
/****** Object:  View [dbo].[Dim_Categorias]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [dbo].[Dim_Categorias] AS
SELECT 
    id_categoria,
    UPPER(nombre_categoria) AS nombre_categoria,
    -- Identificamos si es una categoría principal o una subcategoría
    CASE 
        WHEN id_categoria_padre = 1 OR id_categoria_padre IS NULL THEN 'CATEGORIA PRINCIPAL'
        ELSE 'SUBCATEGORIA'
    END AS nivel_jerarquia,
    -- Agrupación Estratégica para el KPI 1 (Ventas por Tipo de Negocio)
    CASE 
        WHEN nombre_categoria LIKE '%LENTE%' THEN 'LENTICULAR'
        WHEN nombre_categoria LIKE '%ARO%' THEN 'MONTURAS'
        WHEN nombre_categoria LIKE '%SOLUCIONES%' OR nombre_categoria LIKE '%ACCESORIOS%' THEN 'SUMINISTROS'
        ELSE 'OTROS'
    END AS linea_negocio
FROM Maestro_Categorias
WHERE esta_activo = 1; -- Filtro de consistencia: solo lo vigente
GO
/****** Object:  Table [dbo].[Maestro_Clientes]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Clientes](
	[id_cliente] [int] NOT NULL,
	[nombre] [nvarchar](100) NULL,
	[apellido] [nvarchar](100) NULL,
	[telefono_principal] [nvarchar](50) NULL,
	[email] [nvarchar](150) NULL,
	[codigo_postal] [varchar](20) NULL,
	[ciudad] [nvarchar](100) NULL,
	[fecha_nacimiento] [date] NULL,
	[fecha_creacion_cliente] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
	[genero] [varchar](20) NULL,
	[cedula] [varchar](50) NULL,
	[telefono_limpio]  AS (CONVERT([varchar](100),ltrim(rtrim(replace(replace([telefono_principal],'-',''),' ',''))))) PERSISTED,
	[email_limpio]  AS (CONVERT([varchar](150),lower(ltrim(rtrim([email]))))) PERSISTED,
PRIMARY KEY CLUSTERED 
(
	[id_cliente] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Embudo_Marketing]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[Fact_Embudo_Marketing] AS
WITH ClientesDict AS (
    -- Creamos un diccionario único de clientes para evitar duplicar filas
    SELECT 
        id_cliente, 
        cedula, 
        telefono_limpio, 
        email_limpio,
        ROW_NUMBER() OVER(PARTITION BY telefono_limpio ORDER BY id_cliente DESC) as rn_tel,
        ROW_NUMBER() OVER(PARTITION BY email_limpio ORDER BY id_cliente DESC) as rn_email
    FROM Maestro_Clientes
)
SELECT 
    g.id_contacto_ghl,
    g.location_id AS id_sucursal_ghl,  
    UPPER(TRIM(g.sucursal_nombre)) AS nombre_sucursal_ghl,
    g.nombre AS nombre_lead,
    g.apellido AS apellido_lead,
    g.telefono AS telefono_lead,
    g.email AS email_lead,
    g.origen_source AS fuente_marketing,
    g.tags_concatenados AS etiquetas_ghl,

    CAST(DATEADD(HOUR, -5, g.fecha_creacion_ghl) AS DATE) AS fecha_entrada_completa,
    YEAR(DATEADD(HOUR, -5, g.fecha_creacion_ghl)) AS anio_entrada,
    MONTH(DATEADD(HOUR, -5, g.fecha_creacion_ghl)) AS mes_entrada_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, g.fecha_creacion_ghl)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_entrada_nombre,
    
    -- Usamos COALESCE para traer el ID ya sea por teléfono o por email
    COALESCE(ct.id_cliente, ce.id_cliente) AS id_cliente_gesvision,
    COALESCE(ct.cedula, ce.cedula) AS cedula_clinica,
    
    CASE 
        WHEN ct.id_cliente IS NOT NULL THEN 'Match Exacto (Teléfono)'
        WHEN ce.id_cliente IS NOT NULL THEN 'Match Exacto (Email)'
        ELSE 'Solo Lead (Sin Match)'
    END AS tipo_match,
    
    CASE WHEN COALESCE(ct.id_cliente, ce.id_cliente) IS NOT NULL THEN 1 ELSE 0 END AS flag_convertido

FROM [dbo].[GHL_Contactos] g
-- Unión por Teléfono (Mucho más rápida que OUTER APPLY)
LEFT JOIN ClientesDict ct ON g.telefono = ct.telefono_limpio AND ct.rn_tel = 1 AND g.telefono <> ''
-- Unión por Email
LEFT JOIN ClientesDict ce ON LOWER(TRIM(g.email)) = ce.email_limpio AND ce.rn_email = 1 AND g.email <> '' AND ct.id_cliente IS NULL;
GO
/****** Object:  Table [dbo].[Maestro_Metodos_Pago]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Metodos_Pago](
	[id_metodo_pago] [int] NOT NULL,
	[nombre_metodo] [nvarchar](100) NULL,
	[descripcion] [nvarchar](max) NULL,
	[codigo_interno] [bigint] NULL,
	[usa_en_ingresos] [bit] NULL,
	[usa_en_gastos] [bit] NULL,
	[es_activo] [bit] NULL,
	[tipo_pago_codigo] [char](1) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_metodo_pago] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[Dim_MetodosPago]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   VIEW [dbo].[Dim_MetodosPago] AS
SELECT 
    id_metodo_pago,
    UPPER(nombre_metodo) AS metodo_pago,
    -- Agrupación Estratégica para Dashboard
    CASE 
        WHEN nombre_metodo LIKE '%EFECTIVO%' THEN 'EFECTIVO'
        WHEN nombre_metodo LIKE '%VISA%' OR nombre_metodo LIKE '%CLAVE%' THEN 'TARJETA'
        WHEN nombre_metodo LIKE '%YAPPY%' OR nombre_metodo LIKE '%TRANSFERENCIA%' OR nombre_metodo LIKE '%ACH%' THEN 'ELECTRONICO/ACH'
        WHEN nombre_metodo LIKE '%CUPON%' OR nombre_metodo LIKE '%VALE%' OR nombre_metodo LIKE '%CERTIFICADO%' THEN 'CUPONES/PROMOS'
        WHEN nombre_metodo LIKE '%Kredi%' OR nombre_metodo LIKE '%CrediV%' THEN 'FINANCIAMIENTO EXT.'
        WHEN nombre_metodo LIKE '%CREDITO%' THEN 'CREDITO OPTILUX'
        ELSE 'OTROS'
    END AS categoria_recaudo,
    tipo_pago_codigo AS codigo_contable
FROM Maestro_Metodos_Pago
WHERE es_activo = 1; -- Solo métodos vigentes
GO
/****** Object:  Table [dbo].[Maestro_Categorizacion_Comercial]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Categorizacion_Comercial](
	[id_grupo] [int] NOT NULL,
	[Nombre_Dashboard] [varchar](100) NULL,
	[Tipo_Producto_Macro] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_grupo] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Maestro_Marcas]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Marcas](
	[id_marca] [int] NOT NULL,
	[nombre_marca] [varchar](150) NULL,
	[codigo_marca] [varchar](50) NULL,
	[fecha_creacion_origen] [datetime] NULL,
	[fecha_carga_etl] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_marca] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Dim_Productos]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Dim_Productos] AS
SELECT 
    P.id_producto AS SK_Producto,
    P.nombre_producto,
    P.codigo_barras,
    P.referencia,
    
    -- CLASIFICACIÓN COMERCIAL ESTRICTA
    -- Solo mostramos nombres comerciales si el producto es inventariable
    CASE 
        WHEN MCC.Nombre_Dashboard IS NOT NULL THEN MCC.Nombre_Dashboard
        WHEN C.nombre_categoria = 'AROS' THEN 'AROS (OTRAS MARCAS)'
        ELSE 'OTROS PRODUCTOS' 
    END AS Segmento_Comercial,
    
    ISNULL(MCC.Tipo_Producto_Macro, 'OTROS') AS Tipo_Producto_Macro,

    ISNULL(M.nombre_marca, 'SIN MARCA') AS Marca,
    
    -- ATRIBUTOS TÉCNICOS
    ISNULL(P.material_marco, 'NO APLICA') AS Material, 
    ISNULL(P.genero_objetivo, 'UNISEX') AS Genero,      
    ISNULL(P.color_comercial, 'S/D') AS Color,
    ISNULL(P.tipo_montura, 'S/D') AS Tipo_Montura,
    
    -- DATOS FINANCIEROS
    ISNULL(P.costo_compra, 0) AS Costo_Unitario_Referencia,
    ISNULL(P.precio_venta, 0) AS Precio_Venta_Publico,
    
    -- AUDITORÍA
    P.fecha_ultima_actualizacion AS Fecha_Dato,
    P.id_grupo

FROM Maestro_Productos P
LEFT JOIN Maestro_Marcas M ON P.id_marca = M.id_marca
LEFT JOIN Maestro_Categorias C ON P.id_categoria = C.id_categoria
LEFT JOIN Maestro_Categorizacion_Comercial MCC ON P.id_grupo = MCC.id_grupo

-- FILTRO MAESTRO: Solo productos físicos que existen en sucursales
WHERE P.es_inventariable = 1 
  -- Opcional: Filtramos categorías que sabemos que son solo laboratorio
  --AND C.nombre_categoria NOT IN ('BIFOCAL', 'PROGRESIVO', 'OCUPACIONAL', 'VISION SENCILLA', 'TRATAMIENTO');
GO
/****** Object:  View [dbo].[Dim_Clientes]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Dim_Clientes] AS
SELECT 
    id_cliente,
    
    -- CORRECCIÓN: Usamos la misma lógica exacta (LTRIM, RTRIM, UPPER) para garantizar el "Match"
    LTRIM(RTRIM(UPPER(ISNULL(nombre, '') + ' ' + ISNULL(apellido, '')))) AS nombre_completo,        
    
    -- Normalización de Género (Traducción comercial)
    CASE 
        WHEN genero = 'H' THEN 'MASCULINO'
        WHEN genero = 'M' THEN 'FEMENINO'
        ELSE 'NO DEFINIDO (PENDIENTE)'
    END AS genero_label, 
    
    -- Inteligencia de Edad
    ISNULL(DATEDIFF(YEAR, fecha_nacimiento, GETDATE()), 0) AS edad, 
    
    -- Segmentación Etaria
    CASE 
        WHEN fecha_nacimiento IS NULL OR DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) <= 0 THEN 'No Indicado'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 1 AND 18 THEN '01 a 18'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 19 AND 30 THEN '19 a 30'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 31 AND 40 THEN '31 a 40'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 41 AND 50 THEN '41 a 50'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 51 AND 100 THEN '51 a 100'
        ELSE 'Mayor de 100'
    END AS rango_edad_descripcion, 
    
    -- Ubicación Geográfica
    UPPER(ISNULL(ciudad, 'DESCONOCIDO')) AS distrito_residencia,
    email,
    
    -- INTELIGENCIA DE TIEMPO
    CAST(DATEADD(HOUR, -5, fecha_creacion_cliente) AS DATE) AS fecha_registro_completa,
    YEAR(DATEADD(HOUR, -5, fecha_creacion_cliente)) AS anio_registro,
    MONTH(DATEADD(HOUR, -5, fecha_creacion_cliente)) AS mes_registro_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, fecha_creacion_cliente)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_registro_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -5, fecha_creacion_cliente)), 
        '-', 
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, fecha_creacion_cliente)) AS VARCHAR(2)), 2)
    ) AS periodo_registro

FROM Maestro_Clientes;
GO
/****** Object:  View [dbo].[Fact_Citas]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Fact_Citas] AS
SELECT 
    id_cliente,
    UPPER(nombre_cliente) AS nombre_cliente,
    
    -- Clasificación unificada
    CASE 
        WHEN tipo_cita_nombre IS NULL OR tipo_cita_nombre = '' THEN 'CONSULTA/CITA GENERAL'
        ELSE UPPER(tipo_cita_nombre) 
    END AS categoria_cita,
    
    -- Limpieza de detalles
    CASE 
        WHEN detalles_cita LIKE '%Avenida%' OR detalles_cita LIKE '%Provincia%' THEN 'DATOS DE CONTACTO'
        WHEN detalles_cita IS NULL OR detalles_cita = '' THEN 'SIN NOTAS'
        ELSE UPPER(detalles_cita)
    END AS notas_intencion,

    -- FECHA DE LA CITA (Ajustada a GMT-5 Panamá)
    CAST(DATEADD(HOUR, -5, fecha_cita_inicio) AS DATE) AS fecha_cita_inicio,
    YEAR(DATEADD(HOUR, -5, fecha_cita_inicio)) AS anio_cita,
    MONTH(DATEADD(HOUR, -5, fecha_cita_inicio)) AS mes_cita_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, fecha_cita_inicio)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_cita_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -5, fecha_cita_inicio)), 
        '-', 
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, fecha_cita_inicio)) AS VARCHAR(2)), 2)
    ) AS periodo_cita
FROM Marketing_Citas;
GO
/****** Object:  Table [dbo].[Clinica_Examenes]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Clinica_Examenes](
	[id_examen] [int] NOT NULL,
	[id_cliente] [int] NULL,
	[id_sucursal] [int] NULL,
	[id_empleado] [int] NULL,
	[fecha_examen] [datetime2](7) NULL,
	[examType] [varchar](10) NULL,
	[observaciones] [nvarchar](max) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_examen] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Examenes]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Fact_Examenes] AS
SELECT 
    e.id_examen,
    e.id_cliente,
    e.id_sucursal,
    e.id_empleado AS id_optometrista,
    
    -- Normalización del tipo de examen
    UPPER(ISNULL(e.examType, 'GENERAL')) AS tipo_examen,
    
    -- Limpieza de observaciones
    UPPER(ISNULL(e.observaciones, 'SIN OBSERVACIONES')) AS notas_clinicas,

    -- INTELIGENCIA DE TIEMPO (Ajustada a GMT-5 Panamá)
    CAST(DATEADD(HOUR, -5, e.fecha_examen) AS DATE) AS fecha_examen_completa,
    YEAR(DATEADD(HOUR, -5, e.fecha_examen)) AS anio_examen,
    MONTH(DATEADD(HOUR, -5, e.fecha_examen)) AS mes_examen_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, e.fecha_examen)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_examen_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -5, e.fecha_examen)), 
        '-', 
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, e.fecha_examen)) AS VARCHAR(2)), 2)
    ) AS periodo_examen,

    -- =========================================================
    -- NUEVA INTELIGENCIA: ATRIBUCIÓN DE MARKETING
    -- =========================================================
    -- Si el cliente existe en el embudo, le ponemos 1, si no, 0.
    CASE 
        WHEN m.id_cliente_gesvision IS NOT NULL THEN 1 
        ELSE 0 
    END AS es_origen_ghl,
    
    -- Etiqueta de texto por si quieres hacer un gráfico de pastel (Pie Chart)
    CASE 
        WHEN m.id_cliente_gesvision IS NOT NULL THEN 'Marketing (GHL)' 
        ELSE 'Orgánico' 
    END AS canal_adquisicion

FROM Clinica_Examenes e
LEFT JOIN (
    -- Buscamos el diccionario de todos los clientes que llegaron por GHL
    SELECT DISTINCT id_cliente_gesvision 
    FROM Fact_Embudo_Marketing 
    WHERE id_cliente_gesvision IS NOT NULL
) m ON e.id_cliente = m.id_cliente_gesvision;
GO
/****** Object:  View [dbo].[Fact_Ventas_Detalle]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[Fact_Ventas_Detalle] AS
SELECT 
    D.id_factura,
    D.id_linea,
    D.id_producto,
    D.cantidad,
    V.id_sucursal,
    -- Precio original del catálogo (PVP)
    D.precio_unitario AS precio_lista_unitario, 
    -- Monto final cobrado (Precio con Descuento + ITBMS)
    D.total_linea AS monto_final_transaccional, 
    
    -- Ajuste Comercial Neto
    CAST(D.total_linea - (D.cantidad * D.precio_unitario) AS DECIMAL(18,4)) AS ajuste_comercial_neto,

    -- INTELIGENCIA DE TIEMPO (Ajustada a GMT-5 Panamá)
    CAST(DATEADD(HOUR, -5, V.fecha_factura) AS DATE) AS fecha_factura,
    YEAR(DATEADD(HOUR, -5, V.fecha_factura)) AS anio_venta,
    MONTH(DATEADD(HOUR, -5, V.fecha_factura)) AS mes_venta_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, V.fecha_factura)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_venta_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -5, V.fecha_factura)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, V.fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_venta
FROM Ventas_Detalle D
INNER JOIN Ventas_Cabecera V ON D.id_factura = V.id_factura;
GO
/****** Object:  Table [dbo].[Finanzas_Tesoreria]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Finanzas_Tesoreria](
	[id_pago_tesoreria] [int] NOT NULL,
	[id_sucursal] [int] NULL,
	[fecha_movimiento] [datetime2](7) NULL,
	[monto] [decimal](18, 4) NULL,
	[descripcion] [nvarchar](255) NULL,
	[tipo_movimiento] [varchar](10) NULL,
	[metodo_pago_nombre] [nvarchar](100) NULL,
	[id_cuenta_contable] [int] NULL,
	[usuario_creacion] [nvarchar](100) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_pago_tesoreria] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Tesoreria]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE    VIEW [dbo].[Fact_Tesoreria] AS
SELECT 
    id_pago_tesoreria,
    id_sucursal,
    -- Normalizamos la descripción para visualización
    UPPER(TRIM(descripcion)) AS concepto_movimiento,
    UPPER(TRIM(metodo_pago_nombre)) AS metodo_pago,
    monto AS monto_movimiento,
    
    -- Lógica de Categorización con Blindaje UPPER/TRIM
    CASE 
        WHEN UPPER(TRIM(descripcion)) LIKE '%DEPOSITO%' 
          OR UPPER(TRIM(descripcion)) LIKE '%BANCO%' 
          OR UPPER(TRIM(descripcion)) LIKE '%CAJA%' 
          OR UPPER(TRIM(descripcion)) LIKE '%REMESA%' 
          THEN 'CIERRE_CAJA'
        WHEN monto < 0 THEN 'GASTO_MANUAL'
        ELSE 'INGRESO_MANUAL_OTRO'
    END AS categoria_tesoreria,

    usuario_creacion AS responsable,
    
    -- Fecha ajustada a GMT-5 (Panamá)
    CAST(DATEADD(HOUR, -5, fecha_movimiento) AS DATE) AS fecha_completa,
    
    -- Inteligencia de Tiempo Estándar con ajuste GMT-5
    YEAR(DATEADD(HOUR, -5, fecha_movimiento)) AS anio_tesoreria,
    MONTH(DATEADD(HOUR, -5, fecha_movimiento)) AS mes_tesoreria_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, fecha_movimiento)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_tesoreria_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -5, fecha_movimiento)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, fecha_movimiento)) AS VARCHAR(2)), 2)) AS periodo_tesoreria
FROM Finanzas_Tesoreria
WHERE fecha_movimiento >= '2025-01-01'
  -- Aseguramos que solo procesamos Movimientos de Caja manuales
  AND UPPER(TRIM(tipo_movimiento)) = 'MC' 
  AND monto <> 0;
GO
/****** Object:  Table [dbo].[Operaciones_Ordenes_Cristales]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Operaciones_Ordenes_Cristales](
	[id_orden_cristal] [bigint] NOT NULL,
	[codigo_orden] [varchar](50) NULL,
	[numero_orden] [int] NULL,
	[id_cliente] [bigint] NULL,
	[id_sucursal] [int] NULL,
	[id_pedido_venta] [bigint] NULL,
	[id_pedido_compra] [bigint] NULL,
	[fecha_creacion] [datetime] NULL,
	[od_esfera] [decimal](10, 2) NULL,
	[od_cilindro] [decimal](10, 2) NULL,
	[od_eje] [int] NULL,
	[od_adicion] [decimal](10, 2) NULL,
	[od_altura] [int] NULL,
	[od_material] [varchar](20) NULL,
	[od_tipo_lente] [varchar](20) NULL,
	[oi_esfera] [decimal](10, 2) NULL,
	[oi_cilindro] [decimal](10, 2) NULL,
	[oi_eje] [int] NULL,
	[oi_adicion] [decimal](10, 2) NULL,
	[oi_altura] [int] NULL,
	[oi_material] [varchar](20) NULL,
	[oi_tipo_lente] [varchar](20) NULL,
	[fecha_carga_etl] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_orden_cristal] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Produccion_Lentes]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE    VIEW [dbo].[Fact_Produccion_Lentes] AS
SELECT 
    id_orden_cristal AS [ID_Orden],
    codigo_orden AS [Codigo_Sobre],
    id_pedido_venta AS [ID_Pedido],
    id_sucursal AS [ID_Sucursal],
    id_cliente AS [ID_Cliente],
    -- Ajuste a GMT-5 para la fecha de creación/promesa
    DATEADD(HOUR, -5, fecha_creacion) AS [Fecha_Promesa],
    
    -- Datos Ojo Derecho
    od_esfera, od_cilindro, od_adicion,
    od_tipo_lente, od_material,
    
    -- Datos Ojo Izquierdo
    oi_esfera, oi_cilindro, oi_adicion,
    oi_tipo_lente, oi_material,

    -- Lógica de Diagnóstico para Power BI
    CASE 
        WHEN od_esfera < 0 THEN 'Miopía'
        WHEN od_esfera > 0 THEN 'Hipermetropía'
        ELSE 'Neutro'
    END AS [Diagnostico_Derecho],
    
    -- Ajuste a GMT-5 para la auditoría de carga
    DATEADD(HOUR, -5, fecha_carga_etl) AS fecha_carga_etl
FROM [dbo].[Operaciones_Ordenes_Cristales];
GO
/****** Object:  Table [dbo].[Finanzas_Cobros]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
PRIMARY KEY CLUSTERED 
(
	[id_cobro] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Recaudo]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE    VIEW [dbo].[Fact_Recaudo] AS
SELECT 
    -- 1. IDENTIFICADORES
    C.id_cobro,
    ISNULL(C.id_factura, 0) AS id_factura,
    C.id_pedido,
    C.id_sucursal,
    C.id_cliente,
    -- 2. NORMALIZACIÓN DE MÉTODOS DE PAGO
    UPPER(TRIM(C.metodo_pago_nombre)) AS metodo_pago,
    
    -- 3. CLASIFICACIÓN DE INGRESO
    CASE 
        WHEN C.id_factura = 0 OR C.id_factura IS NULL THEN 'ANTICIPO (PENDIENTE ENTREGA)'
        ELSE 'LIQUIDACIÓN (FACTURADO)'
    END AS tipo_recaudo,

    -- 4. VALORES MONETARIOS
    ISNULL(C.monto_cobrado, 0) AS importe_neto,

    -- 5. INTELIGENCIA DE TIEMPO ESTÁNDAR (Ajustada a GMT-5 Panamá)
    CAST(DATEADD(HOUR, -5, C.fecha_cobro) AS DATE) AS fecha_completa,
    YEAR(DATEADD(HOUR, -5, C.fecha_cobro)) AS anio_cobro,
    MONTH(DATEADD(HOUR, -5, C.fecha_cobro)) AS mes_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -5, C.fecha_cobro)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_nombre, -- Se asegura la coma al final
    CONCAT(YEAR(DATEADD(HOUR, -5, C.fecha_cobro)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, C.fecha_cobro)) AS VARCHAR(2)), 2)) AS periodo
FROM Finanzas_Cobros C
WHERE C.fecha_cobro >= '2025-01-01';
GO
/****** Object:  Table [dbo].[Operaciones_Inventario]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Operaciones_Inventario](
	[id_producto] [int] NOT NULL,
	[id_sucursal] [int] NOT NULL,
	[cantidad_disponible] [decimal](18, 4) NULL,
	[cantidad_reservada] [decimal](18, 4) NULL,
	[stock_minimo] [decimal](18, 4) NULL,
	[costo_promedio] [decimal](18, 4) NULL,
	[fecha_actualizacion] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
 CONSTRAINT [PK_Inventario] PRIMARY KEY CLUSTERED 
(
	[id_producto] ASC,
	[id_sucursal] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Inventario]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Fact_Inventario] AS
SELECT 
    -- 1. LLAVES
    I.id_producto,
    I.id_sucursal,
    
    -- 2. MÉTRICAS BASE
    I.cantidad_disponible,
    
    -- 3. DATOS DE CONTROL (Ajustados a GMT-5 Panamá)
    -- Cuándo se movió el producto en bodega (Data Gesvision)
    CAST(DATEADD(HOUR, -5, I.fecha_actualizacion) AS DATE) AS fecha_movimiento_stock,
    
    -- Cuándo corrió tu Python (Para que coincida con la hora del reporte local)
    DATEADD(HOUR, -5, I.fecha_carga_etl) AS fecha_foto_sistema,         
    
    -- 4. VALORIZACIÓN FINANCIERA
    P.costo_compra AS costo_unitario,
    (I.cantidad_disponible * ISNULL(P.costo_compra, 0)) AS valor_total_inventario,
    
    -- 5. SEMÁFORO DE STOCK
    CASE 
        WHEN I.cantidad_disponible <= 0 THEN 'AGOTADO (0)'
        WHEN I.cantidad_disponible <= 2 THEN 'CRÍTICO (1-2)'
        WHEN I.cantidad_disponible <= 5 THEN 'BAJO (3-5)'
        ELSE 'SALUDABLE (>5)' 
    END AS estado_stock,

    -- 6. AUDITORÍA DE CALIDAD
    CASE 
        WHEN P.costo_compra IS NULL OR P.costo_compra = 0 THEN 'ALERTA: COSTO CERO'
        ELSE 'OK' 
    END AS calidad_costo

FROM Operaciones_Inventario I
INNER JOIN Maestro_Productos P ON I.id_producto = P.id_producto
WHERE P.es_inventariable = 1;
GO
/****** Object:  Table [dbo].[Operaciones_Recepciones_Lab]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Operaciones_Recepciones_Lab](
	[id_recepcion_linea] [bigint] NOT NULL,
	[id_albaran] [bigint] NULL,
	[numero_albaran] [int] NULL,
	[id_proveedor] [bigint] NULL,
	[id_pedido_origen] [bigint] NULL,
	[fecha_recepcion] [datetime] NULL,
	[costo_linea_recepcion] [decimal](18, 4) NULL,
	[fecha_carga_etl] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id_recepcion_linea] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[Fact_Operaciones_Maestra]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Fact_Operaciones_Maestra] AS
WITH BaseData AS (
    SELECT 
        V.id_pedido AS [ID_Pedido],
        CAST(DATEADD(HOUR, -5, V.fecha_pedido) AS DATE) AS [Fecha_Pedido],
        V.id_sucursal AS [id_sucursal],
        
        -- --> NUEVO: Traemos el ID del Cliente desde Ventas_Pedidos
        V.id_cliente AS [ID_Cliente],
        
        -- --> NUEVO: Formateamos el nombre del paciente exactamente igual que en Dim_Clientes
        LTRIM(RTRIM(UPPER(ISNULL(C.nombre, '') + ' ' + ISNULL(C.apellido, '')))) AS [Paciente],
        
        -- ID que viene de Gesvision
        V.id_estado_orden, 
        
        O.id_orden_cristal AS [ID_Receta],
        O.codigo_orden AS [Codigo_Sobre],
        ISNULL(O.od_material, 'No Definido') AS [Material],
        ISNULL(O.od_tipo_lente, 'No Definido') AS [Tipo_Lente],
        CAST(ISNULL(O.od_esfera, 0) AS DECIMAL(10,2)) AS [Esfera_OD],
        CAST(ISNULL(O.oi_esfera, 0) AS DECIMAL(10,2)) AS [Esfera_OI],
        
        CASE 
            WHEN R.fecha_recepcion IS NULL THEN NULL
            WHEN CAST(DATEADD(HOUR, -5, R.fecha_recepcion) AS DATE) < CAST(DATEADD(HOUR, -5, V.fecha_pedido) AS DATE) THEN 
                CASE 
                    WHEN DAY(DATEADD(HOUR, -5, R.fecha_recepcion)) <= 12 THEN
                        CAST(CAST(YEAR(DATEADD(HOUR, -5, R.fecha_recepcion)) AS VARCHAR(4)) + RIGHT('0' + CAST(DAY(DATEADD(HOUR, -5, R.fecha_recepcion)) AS VARCHAR(2)), 2) + RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -5, R.fecha_recepcion)) AS VARCHAR(2)), 2) AS DATE)
                    ELSE NULL 
                END
            ELSE CAST(DATEADD(HOUR, -5, R.fecha_recepcion) AS DATE)
        END AS [Fecha_Recepcion]

    FROM [dbo].[Ventas_Pedidos] V
    INNER JOIN [dbo].[Operaciones_Ordenes_Cristales] O ON V.id_pedido = O.id_pedido_venta
    LEFT JOIN [dbo].[Operaciones_Recepciones_Lab] R ON O.id_orden_cristal = R.id_pedido_origen
    -- --> NUEVO: Unimos con el Maestro de Clientes para traer el nombre
    LEFT JOIN [dbo].[Maestro_Clientes] C ON V.id_cliente = C.id_cliente
    WHERE V.fecha_pedido >= '2025-01-01'
)

SELECT 
    *,
    
    -- CAMBIO 2 CORREGIDO: El número coincide con el ID real
    CASE ISNULL(id_estado_orden, -1)
        WHEN 6  THEN '6. POR ENVIAR'
        WHEN 7  THEN '7. EN LABORATORIO'
        WHEN 10 THEN '10. POR ENTREGAR'
        WHEN 13 THEN '13. ENTREGADO'
        WHEN 14 THEN '14. LC EN TRANSITO'
        WHEN 15 THEN '15. LC SOLICITADO'
        WHEN 17 THEN '17. POCO ABONO'
        ELSE '0. OTROS / SIN ESTADO'
    END AS [Estado_Operativo_Texto],

    -- CAMBIO 3: Días de Laboratorio
    CASE 
        WHEN id_estado_orden IN (10, 13) AND [Fecha_Recepcion] IS NOT NULL 
             THEN DATEDIFF(DAY, [Fecha_Pedido], [Fecha_Recepcion])
        WHEN id_estado_orden IN (6, 7, 14, 15) 
             THEN DATEDIFF(DAY, [Fecha_Pedido], CAST(DATEADD(HOUR, -5, GETUTCDATE()) AS DATE))
        ELSE DATEDIFF(DAY, [Fecha_Pedido], ISNULL([Fecha_Recepcion], CAST(DATEADD(HOUR, -5, GETUTCDATE()) AS DATE)))
    END AS [Dias_Lab],

    -- CAMBIO 4 CORREGIDO: Estatus Logístico usando los nombres oficiales
    CASE 
        WHEN id_estado_orden = 13 THEN 'Entregado'
        WHEN id_estado_orden = 10 THEN 'Listo en Tienda'
        WHEN id_estado_orden = 7  THEN 'En Laboratorio'
        WHEN id_estado_orden = 17 THEN 'Poco Abono'
        WHEN [Fecha_Recepcion] IS NULL AND DATEDIFF(DAY, [Fecha_Pedido], CAST(DATEADD(HOUR, -5, GETUTCDATE()) AS DATE)) > 15 THEN 'Retrasado Crítico'
        ELSE 'En Proceso'
    END AS [Estatus_Logistico],

    -- CAMPOS DE CALENDARIO, SEMÁFORO Y CALIDAD (Se mantienen)
    YEAR([Fecha_Pedido]) AS [Anio],
    MONTH([Fecha_Pedido]) AS [Mes_Nro],
    CASE MONTH([Fecha_Pedido])
        WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
    END AS [Mes_Nombre],
    CAST(YEAR([Fecha_Pedido]) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH([Fecha_Pedido]) AS VARCHAR(2)), 2) AS [Periodo],

    CASE 
        WHEN [Fecha_Recepcion] IS NOT NULL THEN 
            CASE WHEN DATEDIFF(DAY, [Fecha_Pedido], [Fecha_Recepcion]) <= 7 THEN 'A Tiempo' ELSE 'Fuera de Meta' END
        WHEN [Fecha_Recepcion] IS NULL AND DATEDIFF(DAY, [Fecha_Pedido], CAST(DATEADD(HOUR, -5, GETUTCDATE()) AS DATE)) <= 10 THEN 'En Proceso (Lab)'
        ELSE 'Fuera de Meta' 
    END AS [Semaforo_Meta],

    CASE 
        WHEN [Fecha_Recepcion] IS NOT NULL AND DATEDIFF(DAY, [Fecha_Pedido], [Fecha_Recepcion]) BETWEEN 0 AND 30 THEN 'Dato Operativo Real'
        WHEN [Fecha_Recepcion] IS NOT NULL AND DATEDIFF(DAY, [Fecha_Pedido], [Fecha_Recepcion]) > 30 THEN 'Histórico Atípico'
        WHEN [Fecha_Recepcion] IS NULL AND DATEDIFF(DAY, [Fecha_Pedido], CAST(DATEADD(HOUR, -5, GETUTCDATE()) AS DATE)) > 10 THEN 'Dato Operativo Real'
        ELSE 'Faltante' 
    END AS [Calidad_Analisis]

FROM BaseData;
GO
/****** Object:  View [dbo].[Dim_Sucursales_Limpia]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   VIEW [dbo].[Dim_Sucursales_Limpia] AS
SELECT 
    id_sucursal,
    nombre_comercial AS [Nombre_Sucursal],
    -- Aplicamos el parche solo aquí, en la dimensión
    CASE 
        WHEN id_sucursal = 2 THEN 'PANAMA OESTE'
        ELSE ISNULL(NULLIF(provincia, 'POR CLASIFICAR'), 'SIN PROVINCIA')
    END AS [Provincia],
    CASE 
        WHEN id_sucursal = 2 THEN 'LA CHORRERA'
        ELSE ISNULL(NULLIF(municipio, 'POR CLASIFICAR'), 'SIN DISTRITO')
    END AS [Distrito],
    ubicacion_mapa
FROM [dbo].[Dim_Sucursales];
GO
/****** Object:  Table [dbo].[Control_Sincronizacion_Examenes]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Control_Sincronizacion_Examenes](
	[id_cliente] [int] NOT NULL,
	[estatus_sincronizacion] [varchar](20) NULL,
	[ultima_fecha_intento] [datetime2](7) NULL,
	[fecha_ultima_sincronizacion] [datetime2](7) NULL,
	[mensaje_error] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_cliente] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Etl_Checkpoints]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Etl_Checkpoints](
	[KeyName] [varchar](50) NOT NULL,
	[LastValue] [varchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[KeyName] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Etl_GHL_Auth]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Etl_GHL_Auth](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[app_name] [varchar](100) NULL,
	[client_id] [varchar](max) NULL,
	[client_secret] [varchar](max) NULL,
	[refresh_token] [varchar](max) NULL,
	[location_id] [varchar](100) NULL,
	[last_update] [datetime] NULL,
	[access_token] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Etl_Zoho_Auth]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Etl_Zoho_Auth](
	[Id] [int] NOT NULL,
	[refresh_token] [varchar](max) NOT NULL,
	[access_token] [varchar](max) NULL,
	[organization_id] [varchar](50) NULL,
	[expires_in_sec] [int] NULL,
	[last_update] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Maestro_Proveedores]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Maestro_Proveedores](
	[id_proveedor] [int] NOT NULL,
	[nombre_proveedor] [nvarchar](255) NULL,
	[ruc_proveedor] [nvarchar](50) NULL,
	[codigo_interno] [nvarchar](50) NULL,
	[email_contacto] [nvarchar](255) NULL,
	[telefono_contacto] [nvarchar](50) NULL,
	[pais] [nvarchar](50) NULL,
	[fecha_creacion_origen] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_proveedor] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Operaciones_Facturas_Lab]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Operaciones_Facturas_Lab](
	[id_factura_linea] [int] NOT NULL,
	[id_factura] [int] NULL,
	[numero_factura] [nvarchar](50) NULL,
	[id_proveedor] [int] NULL,
	[id_pedido_origen] [int] NULL,
	[costo_unitario] [decimal](18, 4) NULL,
	[cantidad] [int] NULL,
	[costo_total_linea] [decimal](18, 4) NULL,
	[fecha_factura] [datetime2](7) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_factura_linea] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Operaciones_Pedidos_Laboratorio]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Operaciones_Pedidos_Laboratorio](
	[id_pedido_lab] [int] NOT NULL,
	[id_pedido_origen] [int] NULL,
	[proveedor_nombre] [nvarchar](100) NULL,
	[id_sucursal] [int] NULL,
	[fecha_solicitud] [datetime2](7) NULL,
	[monto_costo] [decimal](18, 4) NULL,
	[estatus_proceso] [nvarchar](100) NULL,
	[fecha_fabricacion] [datetime2](7) NULL,
	[usuario_creacion] [nvarchar](100) NULL,
	[fecha_carga_etl] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[id_pedido_lab] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Seguridad_RLS]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Seguridad_RLS](
	[Usuario_Email] [nvarchar](100) NOT NULL,
	[Sucursal_Asignada] [nvarchar](100) NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[VentasDiarias]    Script Date: 6/4/2026 12:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[VentasDiarias](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Fecha] [date] NULL,
	[Sucursal] [nvarchar](100) NULL,
	[MontoTotal] [decimal](10, 2) NULL,
	[CantidadVentas] [int] NULL,
	[FechaCarga] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_GHL_Citas_ID_GHL]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_GHL_Citas_ID_GHL] ON [dbo].[GHL_Citas]
(
	[id_cita_ghl] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_GHL_Citas_IdCita]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_GHL_Citas_IdCita] ON [dbo].[GHL_Citas]
(
	[id_cita_ghl] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_GHL_Email]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_GHL_Email] ON [dbo].[GHL_Contactos]
(
	[email] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_GHL_Fecha_Orden]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_GHL_Fecha_Orden] ON [dbo].[GHL_Contactos]
(
	[fecha_creacion_ghl] DESC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_GHL_Telefono]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_GHL_Telefono] ON [dbo].[GHL_Contactos]
(
	[telefono] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_GHL_Oportunidades_ID]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_GHL_Oportunidades_ID] ON [dbo].[GHL_Oportunidades]
(
	[id_oportunidad_ghl] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_GHL_Oportunidades_ID_GHL]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_GHL_Oportunidades_ID_GHL] ON [dbo].[GHL_Oportunidades]
(
	[id_oportunidad_ghl] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_GHL_Opps_IdOpp]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_GHL_Opps_IdOpp] ON [dbo].[GHL_Oportunidades]
(
	[id_oportunidad_ghl] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_Maestro_EmailLimpio]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_Maestro_EmailLimpio] ON [dbo].[Maestro_Clientes]
(
	[email_limpio] ASC
)
INCLUDE([id_cliente],[cedula]) WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_Maestro_TelLimpio]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_Maestro_TelLimpio] ON [dbo].[Maestro_Clientes]
(
	[telefono_limpio] ASC
)
INCLUDE([id_cliente],[cedula]) WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Geografia_Municipio]    Script Date: 6/4/2026 12:16:24 ******/
CREATE NONCLUSTERED INDEX [IX_Geografia_Municipio] ON [dbo].[Param_Panama_Geografia]
(
	[distrito_municipio] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Clinica_Examenes] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Control_Sincronizacion_Examenes] ADD  DEFAULT ('PENDIENTE') FOR [estatus_sincronizacion]
GO
ALTER TABLE [dbo].[Control_Sincronizacion_Examenes] ADD  DEFAULT (getdate()) FOR [ultima_fecha_intento]
GO
ALTER TABLE [dbo].[Control_Sincronizacion_Examenes] ADD  DEFAULT (getdate()) FOR [fecha_ultima_sincronizacion]
GO
ALTER TABLE [dbo].[Etl_GHL_Auth] ADD  DEFAULT (getdate()) FOR [last_update]
GO
ALTER TABLE [dbo].[Etl_Zoho_Auth] ADD  DEFAULT ((1)) FOR [Id]
GO
ALTER TABLE [dbo].[Etl_Zoho_Auth] ADD  DEFAULT ((3600)) FOR [expires_in_sec]
GO
ALTER TABLE [dbo].[Etl_Zoho_Auth] ADD  DEFAULT (getdate()) FOR [last_update]
GO
ALTER TABLE [dbo].[Finanzas_Cobros] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Finanzas_Tesoreria] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[GHL_Calendarios] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[GHL_Citas] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[GHL_Contactos] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[GHL_Oportunidades] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Maestro_Categorias] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Maestro_Clientes] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Maestro_Empleados] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Maestro_Marcas] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Maestro_Metodos_Pago] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Maestro_Productos] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Maestro_Proveedores] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Maestro_Sucursales] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Marketing_Citas] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Operaciones_Facturas_Lab] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Operaciones_Inventario] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Operaciones_Ordenes_Cristales] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Operaciones_Pedidos_Laboratorio] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Operaciones_Recepciones_Lab] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Param_Panama_Geografia] ADD  DEFAULT (getdate()) FOR [fecha_creacion]
GO
ALTER TABLE [dbo].[Ventas_Cabecera] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Ventas_Detalle] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Ventas_Pedidos] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[VentasDiarias] ADD  DEFAULT (getdate()) FOR [FechaCarga]
GO
ALTER TABLE [dbo].[Zoho_Gastos] ADD  DEFAULT (getdate()) FOR [fecha_carga_etl]
GO
ALTER TABLE [dbo].[Clinica_Examenes]  WITH NOCHECK ADD  CONSTRAINT [FK_Examenes_Cliente] FOREIGN KEY([id_cliente])
REFERENCES [dbo].[Maestro_Clientes] ([id_cliente])
GO
ALTER TABLE [dbo].[Clinica_Examenes] NOCHECK CONSTRAINT [FK_Examenes_Cliente]
GO
ALTER TABLE [dbo].[Clinica_Examenes]  WITH CHECK ADD  CONSTRAINT [FK_Examenes_Empleado] FOREIGN KEY([id_empleado])
REFERENCES [dbo].[Maestro_Empleados] ([id_empleado])
GO
ALTER TABLE [dbo].[Clinica_Examenes] CHECK CONSTRAINT [FK_Examenes_Empleado]
GO
ALTER TABLE [dbo].[Clinica_Examenes]  WITH CHECK ADD  CONSTRAINT [FK_Examenes_Sucursal] FOREIGN KEY([id_sucursal])
REFERENCES [dbo].[Maestro_Sucursales] ([id_sucursal])
GO
ALTER TABLE [dbo].[Clinica_Examenes] CHECK CONSTRAINT [FK_Examenes_Sucursal]
GO
ALTER TABLE [dbo].[Control_Sincronizacion_Examenes]  WITH CHECK ADD  CONSTRAINT [FK_Control_Cliente] FOREIGN KEY([id_cliente])
REFERENCES [dbo].[Maestro_Clientes] ([id_cliente])
GO
ALTER TABLE [dbo].[Control_Sincronizacion_Examenes] CHECK CONSTRAINT [FK_Control_Cliente]
GO
ALTER TABLE [dbo].[Finanzas_Cobros]  WITH CHECK ADD  CONSTRAINT [FK_Cobros_Cliente] FOREIGN KEY([id_cliente])
REFERENCES [dbo].[Maestro_Clientes] ([id_cliente])
GO
ALTER TABLE [dbo].[Finanzas_Cobros] CHECK CONSTRAINT [FK_Cobros_Cliente]
GO
ALTER TABLE [dbo].[Finanzas_Cobros]  WITH CHECK ADD  CONSTRAINT [FK_Cobros_Sucursal] FOREIGN KEY([id_sucursal])
REFERENCES [dbo].[Maestro_Sucursales] ([id_sucursal])
GO
ALTER TABLE [dbo].[Finanzas_Cobros] CHECK CONSTRAINT [FK_Cobros_Sucursal]
GO
ALTER TABLE [dbo].[Finanzas_Tesoreria]  WITH CHECK ADD  CONSTRAINT [FK_Tesoreria_Sucursal] FOREIGN KEY([id_sucursal])
REFERENCES [dbo].[Maestro_Sucursales] ([id_sucursal])
GO
ALTER TABLE [dbo].[Finanzas_Tesoreria] CHECK CONSTRAINT [FK_Tesoreria_Sucursal]
GO
ALTER TABLE [dbo].[Maestro_Categorias]  WITH CHECK ADD  CONSTRAINT [FK_Categoria_Padre] FOREIGN KEY([id_categoria_padre])
REFERENCES [dbo].[Maestro_Categorias] ([id_categoria])
GO
ALTER TABLE [dbo].[Maestro_Categorias] CHECK CONSTRAINT [FK_Categoria_Padre]
GO
ALTER TABLE [dbo].[Maestro_Empleados]  WITH CHECK ADD  CONSTRAINT [FK_Empleado_Sucursal] FOREIGN KEY([id_sucursal])
REFERENCES [dbo].[Maestro_Sucursales] ([id_sucursal])
GO
ALTER TABLE [dbo].[Maestro_Empleados] CHECK CONSTRAINT [FK_Empleado_Sucursal]
GO
ALTER TABLE [dbo].[Marketing_Citas]  WITH CHECK ADD  CONSTRAINT [FK_Citas_Cliente] FOREIGN KEY([id_cliente])
REFERENCES [dbo].[Maestro_Clientes] ([id_cliente])
GO
ALTER TABLE [dbo].[Marketing_Citas] CHECK CONSTRAINT [FK_Citas_Cliente]
GO
ALTER TABLE [dbo].[Operaciones_Inventario]  WITH CHECK ADD  CONSTRAINT [FK_Inv_Producto] FOREIGN KEY([id_producto])
REFERENCES [dbo].[Maestro_Productos] ([id_producto])
GO
ALTER TABLE [dbo].[Operaciones_Inventario] CHECK CONSTRAINT [FK_Inv_Producto]
GO
ALTER TABLE [dbo].[Operaciones_Inventario]  WITH CHECK ADD  CONSTRAINT [FK_Inv_Sucursal] FOREIGN KEY([id_sucursal])
REFERENCES [dbo].[Maestro_Sucursales] ([id_sucursal])
GO
ALTER TABLE [dbo].[Operaciones_Inventario] CHECK CONSTRAINT [FK_Inv_Sucursal]
GO
ALTER TABLE [dbo].[Operaciones_Pedidos_Laboratorio]  WITH CHECK ADD  CONSTRAINT [FK_Lab_Sucursal] FOREIGN KEY([id_sucursal])
REFERENCES [dbo].[Maestro_Sucursales] ([id_sucursal])
GO
ALTER TABLE [dbo].[Operaciones_Pedidos_Laboratorio] CHECK CONSTRAINT [FK_Lab_Sucursal]
GO
ALTER TABLE [dbo].[Ventas_Cabecera]  WITH NOCHECK ADD  CONSTRAINT [FK_Ventas_Empleado] FOREIGN KEY([id_empleado])
REFERENCES [dbo].[Maestro_Empleados] ([id_empleado])
GO
ALTER TABLE [dbo].[Ventas_Cabecera] CHECK CONSTRAINT [FK_Ventas_Empleado]
GO
ALTER TABLE [dbo].[Ventas_Cabecera]  WITH NOCHECK ADD  CONSTRAINT [FK_Ventas_Optometrista] FOREIGN KEY([id_optometrista])
REFERENCES [dbo].[Maestro_Empleados] ([id_empleado])
GO
ALTER TABLE [dbo].[Ventas_Cabecera] CHECK CONSTRAINT [FK_Ventas_Optometrista]
GO
ALTER TABLE [dbo].[Ventas_Cabecera]  WITH CHECK ADD  CONSTRAINT [FK_Ventas_Sucursal] FOREIGN KEY([id_sucursal])
REFERENCES [dbo].[Maestro_Sucursales] ([id_sucursal])
GO
ALTER TABLE [dbo].[Ventas_Cabecera] CHECK CONSTRAINT [FK_Ventas_Sucursal]
GO
ALTER TABLE [dbo].[Ventas_Detalle]  WITH CHECK ADD  CONSTRAINT [FK_Detalle_Factura] FOREIGN KEY([id_factura])
REFERENCES [dbo].[Ventas_Cabecera] ([id_factura])
GO
ALTER TABLE [dbo].[Ventas_Detalle] CHECK CONSTRAINT [FK_Detalle_Factura]
GO
ALTER TABLE [dbo].[Ventas_Detalle]  WITH CHECK ADD  CONSTRAINT [FK_Detalle_Producto] FOREIGN KEY([id_producto])
REFERENCES [dbo].[Maestro_Productos] ([id_producto])
GO
ALTER TABLE [dbo].[Ventas_Detalle] CHECK CONSTRAINT [FK_Detalle_Producto]
GO
ALTER TABLE [dbo].[Ventas_Pedidos]  WITH CHECK ADD  CONSTRAINT [FK_Pedidos_Cliente] FOREIGN KEY([id_cliente])
REFERENCES [dbo].[Maestro_Clientes] ([id_cliente])
GO
ALTER TABLE [dbo].[Ventas_Pedidos] CHECK CONSTRAINT [FK_Pedidos_Cliente]
GO
ALTER TABLE [dbo].[Ventas_Pedidos]  WITH CHECK ADD  CONSTRAINT [FK_Pedidos_Empleado] FOREIGN KEY([id_empleado])
REFERENCES [dbo].[Maestro_Empleados] ([id_empleado])
GO
ALTER TABLE [dbo].[Ventas_Pedidos] CHECK CONSTRAINT [FK_Pedidos_Empleado]
GO
ALTER TABLE [dbo].[Ventas_Pedidos]  WITH CHECK ADD  CONSTRAINT [FK_Pedidos_Sucursal] FOREIGN KEY([id_sucursal])
REFERENCES [dbo].[Maestro_Sucursales] ([id_sucursal])
GO
ALTER TABLE [dbo].[Ventas_Pedidos] CHECK CONSTRAINT [FK_Pedidos_Sucursal]
GO
ALTER TABLE [dbo].[Etl_Zoho_Auth]  WITH CHECK ADD  CONSTRAINT [CHK_SingleRow] CHECK  (([Id]=(1)))
GO
ALTER TABLE [dbo].[Etl_Zoho_Auth] CHECK CONSTRAINT [CHK_SingleRow]
GO
ALTER DATABASE [db-optilux-dw] SET  READ_WRITE 
GO
