/*


notas:
1) corregir las vistas  de venezuela conforme al horario  (tomar de base panama que es -5) pero adaptar a la hora de ve
2) revisar y adecuar vista metodos de pago ya que esta en funcion de panam entonces los tipos no son iguales
3) en dim productos  hay que revisar  la clasificacion estrictas, atributos tecnicos  y datsos  financieros  , es decir si aplican los mismo case  o hay que adecuar a venezuela 
4) revisar   dim_sucursales  para  adecuar  al caso  y escneraio de venezuela 
5)  revisar  y valorar  si aplica y para cual escneario la vista   Dim_Sucursales_Limpia
6) hay que adecuar la vista  Fact_Examenes ya que hace uso de otra visata  de GHL  que no es parte del  alcance de venezuela por lo que hay que valor por cual se debe sustituir 
*/



/****** Object:  View [dbo].[Dim_Categorias]    Script Date: 25/4/2026 09:24:06 ******/
DROP VIEW [dbo].[Dim_Categorias]
GO

/****** Object:  View [dbo].[Dim_Categorias]    Script Date: 25/4/2026 09:24:06 ******/
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


/****** Object:  View [dbo].[Dim_Clientes]    Script Date: 25/4/2026 09:25:09 ******/
DROP VIEW [dbo].[Dim_Clientes]
GO

/****** Object:  View [dbo].[Dim_Clientes]    Script Date: 25/4/2026 09:25:09 ******/
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


/****** Object:  View [dbo].[Dim_Empleados]    Script Date: 25/4/2026 09:25:33 ******/
DROP VIEW [dbo].[Dim_Empleados]
GO

/****** Object:  View [dbo].[Dim_Empleados]    Script Date: 25/4/2026 09:25:33 ******/
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


/****** Object:  View [dbo].[Dim_MetodosPago]    Script Date: 25/4/2026 09:27:04 ******/
DROP VIEW [dbo].[Dim_MetodosPago]
GO

/****** Object:  View [dbo].[Dim_MetodosPago]    Script Date: 25/4/2026 09:27:04 ******/
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


/****** Object:  View [dbo].[Dim_Productos]    Script Date: 25/4/2026 09:30:00 ******/
DROP VIEW [dbo].[Dim_Productos]
GO

/****** Object:  View [dbo].[Dim_Productos]    Script Date: 25/4/2026 09:30:00 ******/
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


/****** Object:  View [dbo].[Dim_Productos]    Script Date: 25/4/2026 09:30:00 ******/
DROP VIEW [dbo].[Dim_Productos]
GO

/****** Object:  View [dbo].[Dim_Productos]    Script Date: 25/4/2026 09:30:00 ******/
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

****** Object:  View [dbo].[Dim_Sucursales]    Script Date: 25/4/2026 09:31:57 ******/
DROP VIEW [dbo].[Dim_Sucursales]
GO

/****** Object:  View [dbo].[Dim_Sucursales]    Script Date: 25/4/2026 09:31:57 ******/
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



/****** Object:  View [dbo].[Dim_Sucursales_Limpia]    Script Date: 25/4/2026 09:33:30 ******/
DROP VIEW [dbo].[Dim_Sucursales_Limpia]
GO

/****** Object:  View [dbo].[Dim_Sucursales_Limpia]    Script Date: 25/4/2026 09:33:30 ******/
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

/****** Object:  View [dbo].[Fact_Citas]    Script Date: 25/4/2026 09:34:34 ******/
DROP VIEW [dbo].[Fact_Citas]
GO

/****** Object:  View [dbo].[Fact_Citas]    Script Date: 25/4/2026 09:34:34 ******/
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


/****** Object:  View [dbo].[Fact_Examenes]    Script Date: 25/4/2026 09:37:22 ******/
DROP VIEW [dbo].[Fact_Examenes]
GO

/****** Object:  View [dbo].[Fact_Examenes]    Script Date: 25/4/2026 09:37:22 ******/
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

/****** Object:  View [dbo].[Fact_Inventario]    Script Date: 25/4/2026 09:38:55 ******/
DROP VIEW [dbo].[Fact_Inventario]
GO

/****** Object:  View [dbo].[Fact_Inventario]    Script Date: 25/4/2026 09:38:55 ******/
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


/****** Object:  View [dbo].[Fact_Operaciones_Maestra]    Script Date: 25/4/2026 09:39:39 ******/
DROP VIEW [dbo].[Fact_Operaciones_Maestra]
GO

/****** Object:  View [dbo].[Fact_Operaciones_Maestra]    Script Date: 25/4/2026 09:39:39 ******/
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


/****** Object:  View [dbo].[Fact_Pedidos]    Script Date: 25/4/2026 09:41:12 ******/
DROP VIEW [dbo].[Fact_Pedidos]
GO

/****** Object:  View [dbo].[Fact_Pedidos]    Script Date: 25/4/2026 09:41:12 ******/
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


/****** Object:  View [dbo].[Fact_Produccion_Lentes]    Script Date: 25/4/2026 09:41:46 ******/
DROP VIEW [dbo].[Fact_Produccion_Lentes]
GO

/****** Object:  View [dbo].[Fact_Produccion_Lentes]    Script Date: 25/4/2026 09:41:46 ******/
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

/****** Object:  View [dbo].[Fact_Recaudo]    Script Date: 25/4/2026 09:42:54 ******/
DROP VIEW [dbo].[Fact_Recaudo]
GO

/****** Object:  View [dbo].[Fact_Recaudo]    Script Date: 25/4/2026 09:42:54 ******/
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


/****** Object:  View [dbo].[Fact_Tesoreria]    Script Date: 25/4/2026 09:43:18 ******/
DROP VIEW [dbo].[Fact_Tesoreria]
GO

/****** Object:  View [dbo].[Fact_Tesoreria]    Script Date: 25/4/2026 09:43:18 ******/
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


/****** Object:  View [dbo].[Fact_Ventas]    Script Date: 25/4/2026 09:43:51 ******/
DROP VIEW [dbo].[Fact_Ventas]
GO

/****** Object:  View [dbo].[Fact_Ventas]    Script Date: 25/4/2026 09:43:51 ******/
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


/****** Object:  View [dbo].[Fact_Ventas_Analitico]    Script Date: 25/4/2026 09:44:29 ******/
DROP VIEW [dbo].[Fact_Ventas_Analitico]
GO

/****** Object:  View [dbo].[Fact_Ventas_Analitico]    Script Date: 25/4/2026 09:44:29 ******/
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


/****** Object:  View [dbo].[Fact_Ventas_Detalle]    Script Date: 25/4/2026 09:44:55 ******/
DROP VIEW [dbo].[Fact_Ventas_Detalle]
GO

/****** Object:  View [dbo].[Fact_Ventas_Detalle]    Script Date: 25/4/2026 09:44:55 ******/
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


/****** Object:  View [dbo].[Fact_Ventas_Por_Motivo]    Script Date: 25/4/2026 09:45:33 ******/
DROP VIEW [dbo].[Fact_Ventas_Por_Motivo]
GO

/****** Object:  View [dbo].[Fact_Ventas_Por_Motivo]    Script Date: 25/4/2026 09:45:33 ******/
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


/****** Object:  View [dbo].[Vista_Notificacion_ETL]    Script Date: 25/4/2026 09:46:01 ******/
DROP VIEW [dbo].[Vista_Notificacion_ETL]
GO

/****** Object:  View [dbo].[Vista_Notificacion_ETL]    Script Date: 25/4/2026 09:46:01 ******/
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


/*
--LISTA DE  DAX CREADOS AN POWER BI 

--DIMENSION DE TIEMPO CALCULADA  EN  POWERBI 
Dim_Tiempo = 
-- 1. Ajustamos la hora UTC a GMT-5 (Panamá) 
VAR FechaHoyGMT5 = UTCNOW() - (5 / 24) 
VAR AnioInicio = 2025
VAR AnioActual = YEAR(FechaHoyGMT5)
VAR AnioAnterior = AnioActual - 1

RETURN
    ADDCOLUMNS (
        CALENDAR(DATE(AnioInicio, 1, 1), FechaHoyGMT5), 
        "Año", YEAR([Date]),
        "Mes Nro", MONTH([Date]),
        "Día", DAY([Date]), 
        "Mes", FORMAT([Date], "mmmm"),
        "Mes Corto", FORMAT([Date], "mmm"),
        "Trimestre", "Q" & FORMAT([Date], "q"),
        "Año-Mes", FORMAT([Date], "YYYY-MM"),
        "Dia Semana", WEEKDAY([Date], 2),
        "Nombre Dia", FORMAT([Date], "dddd"),
        "Es Fin de Semana", IF(WEEKDAY([Date], 2) > 5, "Si", "No"),
        "Fecha_Relativa", IF([Date] = FechaHoyGMT5, "Hoy", IF([Date] < FechaHoyGMT5, "Pasado", "Futuro")),
        
        -- Columna para el Slicer que ya tenías [cite: 34]
        "Slicer Mes Actual", 
        IF(
            MONTH([Date]) = MONTH(FechaHoyGMT5) && YEAR([Date]) = YEAR(FechaHoyGMT5),
            "Mes Actual",
            FORMAT([Date], "mmmm yyyy")
        ),

        -- NUEVA COLUMNA: Filtro para la Matrix (Automático y Dinámico)
        "Filtro Comparativo Dinamico",
        IF (
            YEAR([Date]) = AnioActual || YEAR([Date]) = AnioAnterior,
            1,
            0
        )
    )



--_Medidas_Optilux
  
# Pedidos Año Actual = 
VAR AnioHoy = YEAR(UTCNOW() - (5 / 24))
RETURN
CALCULATE([Total Pedidos], 'Dim_Tiempo'[Año] = AnioHoy)



# Pedidos Año Anterior = 
VAR AnioPasado = YEAR(UTCNOW() - (5 / 24)) - 1
RETURN
CALCULATE([Total Pedidos], 'Dim_Tiempo'[Año] = AnioPasado)

% Asistencia (Show Rate) = 
VAR CitasAsistidas = 
    CALCULATE(
        COUNTROWS('Fact_GHL_Citas'), 
        'Fact_GHL_Citas'[estado_cita_comercial] = "Asistió"
    )
VAR Resultado = DIVIDE(CitasAsistidas, [Total Citas GHL], 0)

RETURN 
COALESCE(Resultado, 0)

% Cierre Año Actual = VAR AnioHoy = YEAR(UTCNOW() - (5/24)) RETURN CALCULATE([% Cierre General], 'Dim_Tiempo'[Año] = AnioHoy)

% Cierre Año Anterior = VAR AnioPasado = YEAR(UTCNOW() - (5/24)) - 1 RETURN CALCULATE([% Cierre General], 'Dim_Tiempo'[Año] = AnioPasado)

% Cierre General = 
VAR PacientesAtendidos = [Total Exámenes]
VAR VentasCerradas = [Total Pedidos] -- Asegúrate de que esta sea tu medida de ventas/tickets

RETURN
DIVIDE(VentasCerradas, PacientesAtendidos, 0)


% Cobro Inmediato = 
VAR TotalPedidos = DISTINCTCOUNT('Fact_Pedidos'[id_pedido]) -- Cambio aquí
VAR PedidosPagadosFull = 
    CALCULATE(
        DISTINCTCOUNT('Fact_Pedidos'[id_pedido]), -- Cambio aquí
        FILTER('Fact_Pedidos', [monto saldo pendiente] = 0)
    ) 
RETURN 
COALESCE(
    DIVIDE(PedidosPagadosFull, TotalPedidos, 0), 
    0
)


% Conversión de Leads GHL = 
VAR Examenes = [Exámenes de Origen GHL]

-- Calculamos las ventas crudas usando TREATAS de forma segura
VAR VentasRaw = 
    CALCULATE(
        DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Receta]),
        KEEPFILTERS(TREATAS(VALUES('Dim_GHL_Contactos'[email]), 'Dim_Clientes'[email]))
    )

VAR ResultadoCalculado = DIVIDE(VentasRaw, Examenes, 0)

RETURN 
-- Usamos ISBLANK para evitar errores si Examenes no trae datos
IF(
    ISBLANK(Examenes) || Examenes = 0, 
    BLANK(), 
    IF(ResultadoCalculado > 1, 1, ResultadoCalculado)
)


% Crecimiento Real = 
VAR FechaHoyGMT5 = UTCNOW() - (5/24) 
VAR MesActual = MONTH(FechaHoyGMT5)
VAR AnioActual = YEAR(FechaHoyGMT5)

-- Detectamos qué mes está mirando el usuario en el gráfico/filtro
VAR MaxFechaContexto = MAX('Dim_Tiempo'[Date])
VAR MesContexto = MONTH(MaxFechaContexto)
VAR AnioContexto = YEAR(MaxFechaContexto)

-- Usamos && que es el operador lógico "AND" correcto en DAX
VAR EsMesEnCurso = (MesActual = MesContexto && AnioActual = AnioContexto)
VAR DiaCorte = IF(EsMesEnCurso, DAY(FechaHoyGMT5), 31)

VAR ExamenesHoy = [Total Exámenes] 

VAR ExamenesMesPasadoIgualPeriodo = 
    CALCULATE(
        [Total Exámenes], 
        DATEADD('Dim_Tiempo'[Date], -1, MONTH),
        KEEPFILTERS(DAY('Dim_Tiempo'[Date]) <= DiaCorte)
    )

VAR ResultadoCrecimiento = DIVIDE(ExamenesHoy - ExamenesMesPasadoIgualPeriodo, ExamenesMesPasadoIgualPeriodo, 0)

RETURN 
-- Si la tabla de tiempo tiene algún filtro activo, muestra el %, si no, lo deja en blanco.
IF(
    ISFILTERED('Dim_Tiempo'), 
    ResultadoCrecimiento, 
    BLANK()
)

% Cumplimiento Meta = 
VAR PedidosEntregados = CALCULATE(
    DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]),
    'Fact_Operaciones_Maestra'[Estado_Operativo_Texto] = "13. ENTREGADO",
    'Fact_Operaciones_Maestra'[Calidad_Analisis] = "Dato Operativo Real",
    -- EL SEGURO: Solo evaluar pedidos con fechas completas
    NOT ISBLANK('Fact_Operaciones_Maestra'[Fecha_Recepcion])
)
VAR EntregadosATiempo = CALCULATE(
    DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]),
    'Fact_Operaciones_Maestra'[Estado_Operativo_Texto] = "13. ENTREGADO",
    'Fact_Operaciones_Maestra'[Semaforo_Meta] = "A Tiempo",
    -- EL SEGURO: Solo evaluar pedidos con fechas completas
    NOT ISBLANK('Fact_Operaciones_Maestra'[Fecha_Recepcion])
)
RETURN
COALESCE(
    DIVIDE(EntregadosATiempo, PedidosEntregados, 0), 
    0
)

% Eficiencia Entrega = 
VAR TotalAuditables = 
    CALCULATE(
        DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]),
        KEEPFILTERS('Fact_Operaciones_Maestra'[Calidad_Analisis] = "Dato Operativo Real"),
        -- EL SEGURO: Ignorar mala captura de datos
        NOT ISBLANK('Fact_Operaciones_Maestra'[Fecha_Recepcion])
    )
VAR CumplenMeta = 
    CALCULATE(
        DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]),
        KEEPFILTERS('Fact_Operaciones_Maestra'[Semaforo_Meta] = "A Tiempo"),
        -- EL SEGURO: Ignorar mala captura de datos
        NOT ISBLANK('Fact_Operaciones_Maestra'[Fecha_Recepcion])
    )
RETURN 
    COALESCE(DIVIDE(CumplenMeta, TotalAuditables), 0)

    % Mix Medios Pago = 
VAR CobroPorCategoria = [Total Cobrado]
VAR CobroTotal = CALCULATE([Total Cobrado], ALL(Fact_Recaudo[metodo_pago]))

RETURN
IF(
    CobroPorCategoria < 0, 
    0, 
    DIVIDE(CobroPorCategoria, CobroTotal)
)

% Nivel de Abono = 
COALESCE(
    DIVIDE([Recaudado en Pedidos], [Monto Pedidos], 0), 
    0
)

% Variación = DIVIDE([% Cierre Año Actual] - [% Cierre Año Anterior], [% Cierre Año Anterior], 0)

% YoY Cierre General = 
VAR FechaHoyGMT5 = UTCNOW() - (5/24) 
VAR CorteAnoPasado = DATE(YEAR(FechaHoyGMT5) - 1, MONTH(FechaHoyGMT5), DAY(FechaHoyGMT5))

-- 1. Cierre Actual (Llamamos a la Medida 1)
VAR CierreActual = [% Cierre General] 

-- 2. Exámenes del año pasado
VAR ExamenesAnoPasado = 
    CALCULATE(
        [Total Exámenes], 
        DATEADD('Dim_Tiempo'[Date], -1, YEAR),
        'Dim_Tiempo'[Date] <= CorteAnoPasado
    )

-- 3. Pedidos del año pasado
VAR PedidosAnoPasado = 
    CALCULATE(
        [Total Pedidos], -- Asegúrate de que esta sea tu medida de ventas/tickets
        DATEADD('Dim_Tiempo'[Date], -1, YEAR),
        'Dim_Tiempo'[Date] <= CorteAnoPasado
    )

-- 4. Tasa de Cierre del año pasado
VAR CierreAnoPasado = DIVIDE(PedidosAnoPasado, ExamenesAnoPasado, 0)

-- 5. Calculamos el crecimiento
RETURN 
    IF(
        ISBLANK(CierreAnoPasado) || CierreAnoPasado = 0, 
        BLANK(), 
        DIVIDE(CierreActual - CierreAnoPasado, CierreAnoPasado, 0)
    )

% YoY Exámenes = 
VAR FechaHoyGMT5 = UTCNOW() - (5/24) 

-- 1. Calculamos la fecha exacta de "Hoy hace un año"
VAR CorteAnoPasado = DATE(YEAR(FechaHoyGMT5) - 1, MONTH(FechaHoyGMT5), DAY(FechaHoyGMT5))

-- 2. Valor actual (tal cual está en el filtro)
VAR ValorActual = [Total Exámenes] 

-- 3. Valor del año pasado, cortado hasta el día exacto equivalente
VAR ValorAnoPasado = 
    CALCULATE(
        [Total Exámenes], 
        DATEADD('Dim_Tiempo'[Date], -1, YEAR),
        'Dim_Tiempo'[Date] <= CorteAnoPasado
    )

-- 4. Protección para no mostrar 0% si no hay datos del año pasado
RETURN 
    IF(
        ISBLANK(ValorAnoPasado), 
        BLANK(), 
        DIVIDE(ValorActual - ValorAnoPasado, ValorAnoPasado, 0)
    )


    % YoY Venta Neta = 
VAR FechaHoyGMT5 = UTCNOW() - (5/24) 

-- 1. Calculamos la fecha exacta de "Hoy hace un año" (Ej. 3 de marzo de 2025)
VAR CorteAnoPasado = DATE(YEAR(FechaHoyGMT5) - 1, MONTH(FechaHoyGMT5), DAY(FechaHoyGMT5))

-- 2. Valor actual (tal cual está en el filtro: un mes, dos meses, o el año)
VAR ValorActual = [Venta Neta] 

-- 3. Valor del año pasado, filtrado para no sumar los días "del futuro"
VAR ValorAnoPasado = 
    CALCULATE(
        [Venta Neta], 
        DATEADD('Dim_Tiempo'[Date], -1, YEAR),
        'Dim_Tiempo'[Date] <= CorteAnoPasado -- El truco de magia está aquí
    )

-- 4. Protección contra división por cero o años sin datos (Ej. 2024)
RETURN 
    IF(
        ISBLANK(ValorAnoPasado), 
        BLANK(), 
        DIVIDE(ValorActual - ValorAnoPasado, ValorAnoPasado, 0)
    )

    Asistencias GHL = 
COALESCE(
    CALCULATE(
        COUNTROWS('Fact_GHL_Citas'),
        'Fact_GHL_Citas'[estado_cita_comercial] = "Asistió"
    ),
    0
)


ASP (Precio Promedio) = 
COALESCE(
    DIVIDE([Venta Neta (Producto)], [Unidades Vendidas], 0), 
    0
)

Cantidad Citas = COUNTROWS(Fact_Citas)

Cantidad Examenes = COUNTROWS(Fact_Examenes)

Cantidad Facturas = 
COALESCE(
    DISTINCTCOUNT(Fact_Ventas[id_factura]), 
    0
)

Cantidad Pedidos = DISTINCTCOUNT(Fact_Pedidos[id_pedido])

Capital Invertido = 
COALESCE(
    SUM(fact_inventario[valor_total_inventario]), 
    0
)

Clientes Nuevos = 
VAR ClientesEnContexto = VALUES(Fact_Pedidos[id_cliente])
RETURN
COUNTROWS(
    FILTER(
        ClientesEnContexto,
        VAR FechaMinimaHistorica = 
            CALCULATE(
                MIN(Fact_Pedidos[fecha_pedido_completa]), 
                ALL(Dim_Tiempo),      -- Ignoramos el mes seleccionado
                ALL(Dim_Sucursales)   -- Ignoramos la sucursal para buscar en toda la empresa
            )
        RETURN
        -- Verificamos si su primer pedido ocurrió en el periodo actual
        FechaMinimaHistorica IN VALUES(Dim_Tiempo[Date])
    )
) + 0

Color Alerta ETL = 
IF(
    SELECTEDVALUE(Vista_Notificacion_ETL[Estado_Salud]) = "OK", 
    "#2C3E50", -- Tu Cian corporativo
    "#AD0024"  -- Tu Rojo granate corporativo
)

Devoluciones = 
COALESCE(
    ABS(
        CALCULATE(
            SUM(Fact_Ventas[monto_total]),
            Fact_Ventas[tipo_transaccion] = "Devolución"
        )
    ), 
    0
)

Días Promedio Entrega (Finalizados) = 
COALESCE(
    CALCULATE(
        AVERAGEX(
            VALUES('Fact_Operaciones_Maestra'[ID_Pedido]),
            CALCULATE(MAX('Fact_Operaciones_Maestra'[Dias_Lab]))
        ), 
        'Fact_Operaciones_Maestra'[id_estado_orden] IN {10, 13}, 
        'Fact_Operaciones_Maestra'[Calidad_Analisis] = "Dato Operativo Real",
        -- EL SEGURO: Solo promediar si el laboratorio realmente registró la fecha de llegada
        NOT ISBLANK('Fact_Operaciones_Maestra'[Fecha_Recepcion]) 
    ), 
    0
)

Exámenes de Origen GHL = 
CALCULATE(
    [Total Exámenes],
    'Fact_Examenes'[es_origen_ghl] = 1,
    -- Aplicamos la lógica de los 30 días
    FILTER(
        'Fact_Examenes',
        VAR FechaExamen = 'Fact_Examenes'[fecha_examen_completa]
        
        -- PASO 1: Guardamos el ID del paciente actual
        VAR ClienteActual = 'Fact_Examenes'[id_cliente] 
        
        -- PASO 2: Buscamos la fecha máxima, pero usando ALL() para romper el filtro del Slicer
        VAR FechaLead = 
            CALCULATE(
                MAX('Fact_Embudo_Marketing'[fecha_entrada_completa]),
                ALL('Fact_Embudo_Marketing'), -- ESTA ES LA CLAVE PARA QUE NO SE VAYA A CERO
                'Fact_Embudo_Marketing'[id_cliente_gesvision] = ClienteActual
            )
            
        RETURN
        -- PASO 3: Validamos que haya fecha y calculamos los días
        IF(
            ISBLANK(FechaLead),
            FALSE(),
            DATEDIFF(FechaLead, FechaExamen, DAY) <= 30 && DATEDIFF(FechaLead, FechaExamen, DAY) >= 0
        )
    )
)

Examenes Mes Anterior KPI = 
VAR FechaHoyGMT5 = UTCNOW() - (5/24)
VAR DiaHoy = DAY(FechaHoyGMT5)
RETURN
CALCULATE(
    [Exámenes de Origen GHL], 
    DATEADD('Dim_Tiempo'[Date], -1, MONTH),
    KEEPFILTERS(
        FILTER(
            ALL('Dim_Tiempo'), 
            DAY('Dim_Tiempo'[Date]) <= DiaHoy
        )
    )
)

Exámenes Orgánicos = 
CALCULATE(
    [Total Exámenes],
    'Fact_Examenes'[es_origen_ghl] = 0
)

Filtro Mes Actual = 
IF(
    MONTH(MAX('Dim_Tiempo'[Date])) = MONTH(TODAY()) && 
    YEAR(MAX('Dim_Tiempo'[Date])) = YEAR(TODAY()), 
    1, 
    0
)

Indicador Retrasado Crítico = 
COALESCE(
    CALCULATE(
        DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]),
        'Fact_Operaciones_Maestra'[Estatus_Logistico] = "Retrasado Crítico"
    ),
    0
)

Monto Pedidos = COALESCE(SUM(Fact_Pedidos[monto_total]), 0)

Monto Saldo Pendiente = COALESCE(SUM(Fact_Pedidos[saldo_pendiente]), 0)

Net Sales = SUM('Fact_Ventas_Analitico'[monto_final_transaccional])

Pedidos En Proceso (Activos) = 
CALCULATE(
    DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]),
    'Fact_Operaciones_Maestra'[Estado_Operativo_Texto] <> "13. ENTREGADO"
)

Pedidos Este Mes = 
CALCULATE(
    DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]),
    NOT ISBLANK('Fact_Operaciones_Maestra'[ID_Pedido])
)

Pedidos Hoy = 
VAR FechaHoyLocal = UTCNOW() - (5 / 24)
VAR FechaFormateada = DATE(YEAR(FechaHoyLocal), MONTH(FechaHoyLocal), DAY(FechaHoyLocal))

RETURN
COALESCE(
    CALCULATE(
        DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]), 
        KEEPFILTERS('Fact_Operaciones_Maestra'[Fecha_Pedido] = FechaFormateada)
    ), 
    0
)

Pedidos por Liquidar = 
COALESCE(
    CALCULATE(
        DISTINCTCOUNT('Fact_Pedidos'[id_pedido]), -- Consistencia con Ticket Promedio
        FILTER('Fact_Pedidos', [monto saldo pendiente] > 0)
    ), 
    0
)

Pendientes de Cierre Real = 
CALCULATE(
    DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido]),
    'Fact_Operaciones_Maestra'[Estado_Operativo_Texto] IN {"6. POR ENVIAR", "7. EN LABORATORIO"}
)

Promedio Días Entrega (Lab) = 
CALCULATE(
    AVERAGEX(
        VALUES('Fact_Operaciones_Maestra'[ID_Pedido]),
        CALCULATE(MAX('Fact_Operaciones_Maestra'[Dias_Lab]))
    ),
    'Fact_Operaciones_Maestra'[Estado_Operativo_Texto] IN {"13. ENTREGADO", "10. POR ENTREGAR"},
    -- EL SEGURO: Ignorar los pedidos que no tienen fecha real de recepción
    NOT ISBLANK('Fact_Operaciones_Maestra'[Fecha_Recepcion])
)

Proyección Venta Neta = 
-- 1. Configuración de Tiempo GMT-5 (Limpia y sin horas)
VAR FechaHoraGMT5 = UTCNOW() - (5/24)
VAR FechaHoyGMT5 = DATE(YEAR(FechaHoraGMT5), MONTH(FechaHoraGMT5), DAY(FechaHoraGMT5))

VAR MesHoy = MONTH(FechaHoyGMT5)
VAR AnioHoy = YEAR(FechaHoyGMT5)
VAR DiaHoy = DAY(FechaHoyGMT5)

-- 2. Variables de cálculo de ritmo
VAR DiasTranscurridos = IF(DiaHoy = 1, 1, DiaHoy - 1) 
VAR UltimoDiaMes = DAY(EOMONTH(FechaHoyGMT5, 0))

-- 3. Captura del contexto del Slicer usando tus nombres reales de columna
VAR MesSeleccionado = SELECTEDVALUE('Dim_Tiempo'[Mes Nro])
VAR AnioSeleccionado = SELECTEDVALUE('Dim_Tiempo'[Año])

-- 4. El "Motor" de proyección
VAR VentaActual = [Venta Neta]
VAR CalculoProyeccion = DIVIDE(VentaActual, DiasTranscurridos, 0) * UltimoDiaMes

RETURN
IF(
    ISFILTERED('Dim_Tiempo'[Mes]) || ISFILTERED('Dim_Tiempo'[Date]), 
    -- LÓGICA PARA EL GRÁFICO:
    IF(
        AnioSeleccionado < AnioHoy || (AnioSeleccionado = AnioHoy && MesSeleccionado < MesHoy),
        [Venta Neta], -- SI ES ENERO (PASADO): Las barras se igualan
        CalculoProyeccion -- SI ES FEBRERO (ACTUAL): Proyecta hacia el futuro
    ),
    -- LÓGICA PARA LA CARD (Forzamos siempre Febrero 2026):
    CALCULATE(
        DIVIDE([Venta Neta], DiasTranscurridos, 0) * UltimoDiaMes,
        'Dim_Tiempo'[Mes Nro] = MesHoy,
        'Dim_Tiempo'[Año] = AnioHoy
    )
)

Recaudado en Pedidos = COALESCE(SUM(Fact_Pedidos[monto_pagado]), 0)

Stock Fisico (Unds) = 
SUMX(
    GENERATE(
        VALUES('Dim_Productos'[SK_Producto]),
        CALCULATETABLE(Fact_Inventario)
    ),
    Fact_Inventario[cantidad_disponible]
)

Ticket Promedio = 
COALESCE(
    DIVIDE([Venta Neta], [Cantidad Pedidos], 0), 
    0
)

Titulo Detalle Atrasos = 
"Detalle de Órdenes - Sucursal: " & SELECTEDVALUE('Dim_Sucursales'[nombre_comercial], "Múltiples")

Total Citas Gesvision = 
COALESCE(
    COUNTROWS('Fact_Citas'), 
    0
)

Total Citas GHL = 
COALESCE(
    COUNTROWS('Fact_GHL_Citas'), 
    0
)

Total Cobrado = 
COALESCE(
    SUM(Fact_Recaudo[importe_neto]), 
    0
)

Total Exámenes = 
COALESCE(COUNTROWS('Fact_Examenes'), 0)

Total Gastos Zoho = SUM('Fact_Zoho_Gastos'[monto_total]) + 0

Total Pedidos = DISTINCTCOUNT('Fact_Operaciones_Maestra'[ID_Pedido])

Total Recaudado Efectivo = 
CALCULATE(
    [Total Cobrado],
    Fact_Recaudo[metodo_pago] = "EFECTIVO"
)

Unidades por Ticket (UPT) = 
COALESCE(
    DIVIDE([Unidades Vendidas], [Cantidad Facturas], 0), 
    0
)

Unidades Vendidas = 
COALESCE(
    SUM(Fact_Ventas_Detalle[cantidad]), 
    0
)

Venta Bruta = 
CALCULATE(
    SUM(Fact_Ventas[monto_total]),
    Fact_Ventas[tipo_transaccion] <> "Devolución"
)

Venta Neta = 
    COALESCE(
        [Venta Bruta] - [Devoluciones], 
        0
    )

    Venta Neta (Producto) = SUM('Fact_Ventas_Detalle'[monto_final_transaccional])

    Venta Teorica Lista = SUMX(Fact_Ventas_Detalle, Fact_Ventas_Detalle[cantidad] * Fact_Ventas_Detalle[precio_lista_unitario])

    Volumen Unidades = SUM(Fact_Ventas_Analitico[cantidad])

    


*/





