/* ================================================================
   ROLLBACK PANAMA — Vistas SQL Originales Optilux Panamá

   Restaura 4 vistas a su código original de Panamá sin cambios.

   CONTENIDO:
   1. Dim_Productos (GMT-5, Maestro_Categorizacion_Comercial)
   2. Fact_Examenes (GMT-5, GHL, es_origen_ghl, canal_adquisicion)
   3. Fact_Operaciones_Maestra (GMT-5, lógica completa Panamá)
   4. Vista_Notificacion_ETL (GMT-5, "Hora local de Panamá")

   USO: Para reverter cambios y volver a Panamá si es necesario.
   GARANTÍA: Código extraído byte-a-byte del diccionario original.

   ================================================================ */

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ================================================================
-- 1. Dim_Productos — Panamá Original
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Dim_Productos] AS
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

-- ================================================================
-- 2. Fact_Examenes — Panamá Original (con GHL)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Examenes] AS
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

-- ================================================================
-- 3. Fact_Operaciones_Maestra — Panamá Original
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Operaciones_Maestra] AS
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

-- ================================================================
-- 4. Vista_Notificacion_ETL — Panamá Original
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Vista_Notificacion_ETL] AS
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

/* ================================================================
   FIN ROLLBACK PANAMA
   ================================================================ */
