-- ============================================================
-- FASE 2 — DOLARIZACIÓN: VISTAS SQL
-- 52 vistas auditadas. 28 modificadas (columnas USD). 5 bugs corregidos.
-- Aplicado a producción el 20/07/2026. Este script es el REGISTRO de lo ya aplicado.
-- ============================================================


-- ============================================================
-- CAPA 1: CORRECCIÓN DE BUGS INDEPENDIENTES (4)
-- ============================================================

-- Fix 1: Dim_Sucursales_Limpia (columnas municipio/localidad inexistentes en la fuente)
DROP VIEW IF EXISTS [dbo].[Dim_Sucursales_Limpia];
GO

CREATE VIEW [dbo].[Dim_Sucursales_Limpia] AS
SELECT
    DS.id_sucursal,
    DS.nombre_comercial AS [Nombre_Sucursal],
    MS.municipio_raw    AS [Municipio],
    MS.localidad_raw    AS [Localidad]
FROM [dbo].[Dim_Sucursales] DS
INNER JOIN [dbo].[Maestro_Sucursales] MS ON MS.id_sucursal = DS.id_sucursal;
GO

-- Fix 2: KPI_Inf1_Net_Sales (columna subcategoria_lente inexistente en Fact_Ventas_Analitico)
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Net_Sales];
GO

CREATE VIEW [dbo].[KPI_Inf1_Net_Sales] AS
SELECT
    id_factura,
    id_linea,
    id_producto,
    id_sucursal,
    nombre_producto,
    nombre_categoria,
    cantidad,
    fecha_factura,
    anio_venta,
    mes_venta_nro,
    mes_venta_nombre,
    periodo_venta,
    ROUND(monto_final_transaccional, 2)    AS monto_final_transaccional,
    ROUND(precio_lista_unitario, 2)        AS precio_lista_unitario,
    ROUND(ajuste_comercial_neto, 2)        AS ajuste_comercial_neto,
    -- NUEVO: USD
    total_linea_usd,
    precio_lista_unitario_usd
FROM Fact_Ventas_Analitico;
GO

-- Fix 3: Vista_Notificacion_ETL (nombres de módulo desactualizados)
-- FACTURAS_LAB/PEDIDOS_LABORATORIO (ya no existen) -> RECEPCIONES_LAB/PEDIDOS_LAB (actuales)
DROP VIEW IF EXISTS [dbo].[Vista_Notificacion_ETL];
GO

CREATE VIEW [dbo].[Vista_Notificacion_ETL] AS
SELECT
    DATEADD(HOUR, -4, MAX(fecha_fin))   AS Fecha_Hora_Venezuela,
    'Sincronización: ' + FORMAT(
        DATEADD(HOUR, -4, MAX(fecha_fin)),
        'dd/MM/yyyy hh:mm tt'
    )                                    AS Notificacion_Texto,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM Etl_Control_Ejecucion
            WHERE ultimo_estatus = 'PROCESANDO'
            AND modulo_nombre NOT IN ('RECEPCIONES_LAB','PEDIDOS_LAB')
            AND DATEDIFF(MINUTE, fecha_inicio, GETDATE()) < 15
        ) THEN 'EN PROCESO'
        WHEN EXISTS (
            SELECT 1 FROM Etl_Control_Ejecucion
            WHERE ultimo_estatus = 'PROCESANDO'
            AND modulo_nombre NOT IN ('RECEPCIONES_LAB','PEDIDOS_LAB')
            AND DATEDIFF(MINUTE, fecha_inicio, GETDATE()) >= 15
        ) THEN 'ERROR'
        WHEN EXISTS (
            SELECT 1 FROM Etl_Control_Ejecucion
            WHERE ultimo_estatus NOT IN ('COMPLETADO','PROCESANDO')
            AND modulo_nombre NOT IN ('RECEPCIONES_LAB','PEDIDOS_LAB')
        ) THEN 'ERROR'
        ELSE 'OK'
    END                                  AS Estado_Salud,
    (
        SELECT COUNT(*) FROM Etl_Control_Ejecucion
        WHERE ultimo_estatus = 'COMPLETADO'
        AND modulo_nombre NOT IN ('RECEPCIONES_LAB','PEDIDOS_LAB')
    )                                    AS modulos_completados,
    (
        SELECT COUNT(*) FROM Etl_Control_Ejecucion
        WHERE ultimo_estatus = 'PROCESANDO'
        AND modulo_nombre NOT IN ('RECEPCIONES_LAB','PEDIDOS_LAB')
    )                                    AS modulos_en_proceso,
    (
        SELECT COUNT(*) FROM Etl_Control_Ejecucion
        WHERE ultimo_estatus NOT IN ('COMPLETADO','PROCESANDO')
        AND modulo_nombre NOT IN ('RECEPCIONES_LAB','PEDIDOS_LAB')
    )                                    AS modulos_con_error
FROM Etl_Control_Ejecucion
WHERE modulo_nombre NOT IN ('RECEPCIONES_LAB','PEDIDOS_LAB');
GO

-- Fix 4: Fact_Ventas_por_Tipo_Lente (doble ajuste GMT-4: fp.fecha_pedido_completa YA viene ajustada
-- desde Fact_Pedidos; aplicarle DATEADD(HOUR,-4,...) de nuevo retrocedía la fecha 1 día)
DROP VIEW IF EXISTS [dbo].[Fact_Ventas_por_Tipo_Lente];
GO

CREATE VIEW [dbo].[Fact_Ventas_por_Tipo_Lente] AS
SELECT 
    oc.id_orden_cristal,
    oc.id_pedido_venta,
    fp.id_sucursal,
    CASE 
        WHEN oc.od_tipo_lente = 'P' THEN 'PROGRESIVO'
        WHEN oc.od_tipo_lente = 'L' THEN 'LEJOS'
        WHEN oc.od_tipo_lente = 'B' THEN 'BIFOCAL'
        WHEN oc.od_tipo_lente = 'C' THEN 'CERCA'
        ELSE 'OTROS'
    END AS tipo_lente,
    ROUND(fp.monto_total, 2) AS venta_neta,
    ROUND(fp.monto_pagado, 2) AS monto_pagado,
    ROUND(fp.saldo_pendiente, 2) AS saldo_pendiente,
    fp.fecha_pedido_completa AS fecha_venta,
    YEAR(fp.fecha_pedido_completa) AS anio_venta,
    MONTH(fp.fecha_pedido_completa) AS mes_venta_nro,
    CHOOSE(MONTH(fp.fecha_pedido_completa), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_venta_nombre,
    CONCAT(YEAR(fp.fecha_pedido_completa), '-', 
        RIGHT('0' + CAST(MONTH(fp.fecha_pedido_completa) AS VARCHAR(2)), 2)) AS periodo_venta
FROM Operaciones_Ordenes_Cristales oc
INNER JOIN Fact_Pedidos fp ON oc.id_pedido_venta = fp.id_pedido
WHERE oc.od_tipo_lente IS NOT NULL;
GO


-- ============================================================
-- CAPA 2: Dim_Productos (+ Precio_Venta_USD)
-- ============================================================

DROP VIEW IF EXISTS [dbo].[Dim_Productos];
GO

CREATE VIEW [dbo].[Dim_Productos] AS
SELECT
    P.id_producto                                       AS SK_Producto,
    P.nombre_producto,
    P.codigo_barras,
    P.referencia,
    P.id_grupo,
    P.id_marca,
    ISNULL(M.nombre_marca, 'SIN MARCA')                 AS Marca,
    P.id_categoria,
    ISNULL(C.nombre_categoria, 'SIN CATEGORÍA')         AS Categoria,
    ISNULL(CP.nombre_categoria,
        ISNULL(C.nombre_categoria, 'SIN CATEGORÍA'))    AS Categoria_Padre,
    CASE
        WHEN P.id_categoria IN (134, 140, 126, 139) THEN 'MONTURAS'
        WHEN P.id_categoria = 133 THEN 'LENTES DE SOL'
        WHEN C.id_categoria_padre = 65 OR P.id_categoria = 65 THEN 'LENTES'
        WHEN P.id_categoria IN (124, 136, 137) THEN 'LENTES DE CONTACTO'
        WHEN P.id_categoria IN (125, 127, 129, 123) THEN 'ACCESORIOS'
        WHEN P.id_categoria IN (130, 120, 122, 128) THEN 'TRATAMIENTOS'
        ELSE 'OTROS'
    END                                                 AS Segmento_Comercial,
    ISNULL(P.material_marco, 'NO APLICA')               AS Material,
    ISNULL(P.genero_objetivo, 'UNISEX')                 AS Genero,
    ISNULL(P.color_comercial, 'S/D')                    AS Color,
    ISNULL(P.tipo_montura, 'S/D')                       AS Tipo_Montura,
    ISNULL(P.costo_compra, 0)                           AS Costo_Unitario,
    ISNULL(P.precio_venta, 0)                           AS Precio_Venta,
    -- NUEVO: precio de venta de catálogo en USD, tasa oficial más reciente disponible
    ROUND(ISNULL(P.precio_venta, 0) / NULLIF(T.tasa, 0), 2) AS Precio_Venta_USD,
    P.fecha_ultima_actualizacion                        AS Fecha_Dato
FROM Maestro_Productos P
LEFT JOIN Maestro_Marcas M ON P.id_marca = M.id_marca
LEFT JOIN Maestro_Categorias C ON P.id_categoria = C.id_categoria
LEFT JOIN Maestro_Categorias CP ON C.id_categoria_padre = CP.id_categoria
OUTER APPLY (
    SELECT TOP 1 tasa FROM Param_Tasas_Cambio ORDER BY fecha DESC
) T
WHERE P.es_inventariable = 1;
GO


-- ============================================================
-- CAPA 3: 13 VISTAS Fact_* (Fact_Produccion_Lentes sin cambios, no incluida aquí)
-- ============================================================

-- Fact_Eficiencia_Ordenes (base Informe 2)
DROP VIEW IF EXISTS [dbo].[Fact_Eficiencia_Ordenes];
GO

CREATE VIEW [dbo].[Fact_Eficiencia_Ordenes] AS
SELECT 
  OC.id_orden_cristal,
  OC.id_pedido_venta AS id_pedido,
  VP.id_sucursal,
  VP.id_cliente,
  CAST(DATEADD(HOUR, -4, VP.fecha_pedido) AS DATE) AS fecha_pedido,
  YEAR(DATEADD(HOUR, -4, VP.fecha_pedido)) AS anio,
  MONTH(DATEADD(HOUR, -4, VP.fecha_pedido)) AS mes_nro,
  CHOOSE(MONTH(DATEADD(HOUR, -4, VP.fecha_pedido)),
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_nombre,
  CONCAT(YEAR(DATEADD(HOUR, -4, VP.fecha_pedido)), '-',
    RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, VP.fecha_pedido)) AS VARCHAR(2)), 2)) AS periodo,
  OC.od_tipo_lente,
  CASE OC.od_tipo_lente
    WHEN 'L' THEN 'LEJOS'
    WHEN 'P' THEN 'PROGRESIVO'
    WHEN 'B' THEN 'BIFOCAL'
    WHEN 'C' THEN 'CERCA'
    ELSE 'N/A'
  END AS tipo_lente_descripcion,
  OC.oi_tipo_lente,
  OC.od_material,
  OC.oi_material,
  VP.estado_pedido,
  -- NUEVO: el dato real de v2 que repara el Informe 2 (v1 siempre daba 0/vacío)
  VP.estado_entrega_api,
  VP.codigo_documento_api,
  VP.monto_total,
  VP.monto_pagado,
  -- NUEVO: USD
  VP.monto_total_usd,
  VP.monto_pagado_usd,
  VP.saldo_pendiente_usd
FROM Operaciones_Ordenes_Cristales OC
INNER JOIN Ventas_Pedidos VP ON OC.id_pedido_venta = VP.id_pedido
WHERE VP.fecha_pedido >= '2025-01-01';
GO

-- Fact_Examenes (base Informe 4)
DROP VIEW IF EXISTS [dbo].[Fact_Examenes];
GO

CREATE VIEW [dbo].[Fact_Examenes] AS
SELECT
    e.id_examen,
    e.id_cliente,
    e.id_sucursal,
    ms.nombre_sucursal,
    ISNULL(e.id_empleado, 0) AS id_optometrista,
    CAST(DATEADD(HOUR, -4, e.fecha_examen) AS DATE) AS fecha_examen_completa,
    YEAR(DATEADD(HOUR, -4, e.fecha_examen)) AS anio_examen,
    MONTH(DATEADD(HOUR, -4, e.fecha_examen)) AS mes_examen_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, e.fecha_examen)),
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre')
        AS mes_examen_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -4, e.fecha_examen)), '-',
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, e.fecha_examen)) AS VARCHAR(2)), 2)
    ) AS periodo_examen,
    CASE WHEN e.id_empleado = 0 THEN 'SIN REGISTRAR' ELSE 'REGISTRADO' END AS calidad_registro,
    CASE WHEN vp.id_pedido IS NOT NULL THEN 'CONVERTIDO' ELSE 'NO CONVERTIDO' END AS estado_conversion,
    vp.id_pedido,
    DATEDIFF(DAY, e.fecha_examen, vp.fecha_pedido) AS dias_a_conversion,
    vp.monto_total,
    -- NUEVO: USD
    vp.monto_total_usd
FROM Clinica_Examenes e
LEFT JOIN Maestro_Sucursales ms ON e.id_sucursal = ms.id_sucursal
LEFT JOIN Ventas_Pedidos vp 
    ON e.id_cliente = vp.id_cliente
    AND vp.fecha_pedido BETWEEN e.fecha_examen AND DATEADD(DAY, 30, e.fecha_examen)
WHERE e.fecha_examen >= '2025-01-01';
GO

-- Fact_Recaudo (base Informe 1)
DROP VIEW IF EXISTS [dbo].[Fact_Recaudo];
GO

CREATE VIEW [dbo].[Fact_Recaudo] AS
SELECT
    C.id_cobro,
    ISNULL(C.id_factura, 0) AS id_factura,
    C.id_pedido,
    C.id_sucursal,
    C.id_cliente,
    UPPER(TRIM(C.metodo_pago_nombre)) AS metodo_pago,
    CASE
        WHEN C.id_factura = 0 OR C.id_factura IS NULL THEN 'ANTICIPO (PENDIENTE ENTREGA)'
        ELSE 'LIQUIDACIÓN (FACTURADO)'
    END AS tipo_recaudo,
    ISNULL(C.monto_cobrado, 0) AS importe_neto,
    -- NUEVO: USD
    C.monto_cobrado_usd AS importe_neto_usd,
    CAST(DATEADD(HOUR, -4, C.fecha_cobro) AS DATE) AS fecha_completa,
    YEAR(DATEADD(HOUR, -4, C.fecha_cobro)) AS anio_cobro,
    MONTH(DATEADD(HOUR, -4, C.fecha_cobro)) AS mes_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, C.fecha_cobro)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, C.fecha_cobro)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, C.fecha_cobro)) AS VARCHAR(2)), 2)) AS periodo
FROM Finanzas_Cobros C
WHERE C.fecha_cobro >= '2025-01-01';
GO

-- Fact_Inventario (base Informe 5) — usa I.costo_promedio_usd (ETL), NO recalcula desde catálogo
DROP VIEW IF EXISTS [dbo].[Fact_Inventario];
GO

CREATE VIEW [dbo].[Fact_Inventario] AS
SELECT
    I.id_producto,
    I.id_sucursal,
    I.cantidad_disponible,
    CAST(DATEADD(HOUR, -4, I.fecha_actualizacion) AS DATE) AS fecha_movimiento_stock,
    DATEADD(HOUR, -4, I.fecha_carga_etl)                   AS fecha_foto_sistema,
    CAST(DATEADD(HOUR, -4, I.fecha_carga_etl) AS DATE)     AS fecha_foto_date,
    P.costo_compra                                          AS costo_unitario,
    (I.cantidad_disponible * ISNULL(P.costo_compra, 0))    AS valor_total_inventario,
    -- NUEVO: USD, tomado del ETL ya dolarizado (no recalculado desde catálogo)
    I.costo_promedio_usd                                    AS costo_unitario_usd,
    I.valor_total_usd                                       AS valor_total_inventario_usd,
    I.tasa_cambio_aplicada,
    CASE
        WHEN I.cantidad_disponible <= 0 THEN 'AGOTADO (0)'
        WHEN I.cantidad_disponible <= 2 THEN 'CRÍTICO (1-2)'
        WHEN I.cantidad_disponible <= 5 THEN 'BAJO (3-5)'
        ELSE 'SALUDABLE (>5)'
    END AS estado_stock,
    CASE
        WHEN P.costo_compra IS NULL OR P.costo_compra = 0 THEN 'ALERTA: COSTO CERO'
        ELSE 'OK'
    END AS calidad_costo,
    ISNULL(M.nombre_marca, 'SIN MARCA') AS Marca,
    CASE
        WHEN P.id_categoria IN (134, 140, 126, 139) THEN 'MONTURAS'
        WHEN P.id_categoria = 133                   THEN 'LENTES DE SOL'
        WHEN C.id_categoria_padre = 65
          OR P.id_categoria = 65                    THEN 'LENTES'
        WHEN P.id_categoria IN (124, 136, 137)      THEN 'LENTES DE CONTACTO'
        WHEN P.id_categoria IN (125, 127, 129, 123) THEN 'ACCESORIOS'
        WHEN P.id_categoria IN (130, 120, 122, 128) THEN 'TRATAMIENTOS'
        ELSE 'OTROS'
    END AS Segmento_Comercial
FROM Operaciones_Inventario I
INNER JOIN Maestro_Productos P
    ON I.id_producto = P.id_producto
    AND P.es_inventariable = 1
    AND P.id_categoria NOT IN (65, 124, 130, 136, 137, 120, 122, 128)
LEFT JOIN Maestro_Marcas M ON P.id_marca = M.id_marca
LEFT JOIN Maestro_Categorias C ON P.id_categoria = C.id_categoria;
GO

-- Fact_Operaciones_Maestra (base Informe 3)
-- NOTA: INNER JOIN a Operaciones_Ordenes_Cristales excluye ~1,649 pedidos sin orden de cristal
-- ($905.40 USD de saldo pendiente no reportado en Cartera). Documentado, no corregido en este script.
DROP VIEW IF EXISTS [dbo].[Fact_Operaciones_Maestra];
GO

CREATE VIEW [dbo].[Fact_Operaciones_Maestra] AS
SELECT
    V.id_pedido                                           AS [ID_Pedido],
    CAST(DATEADD(HOUR, -4, V.fecha_pedido) AS DATE)      AS [Fecha_Pedido],
    V.id_sucursal                                         AS [id_sucursal],
    V.id_cliente                                          AS [ID_Cliente],
    LTRIM(RTRIM(UPPER(
        ISNULL(C.nombre, '') + ' ' + ISNULL(C.apellido, '')
    )))                                                   AS [Paciente],
    O.id_orden_cristal                                    AS [ID_Receta],
    O.codigo_orden                                        AS [Codigo_Sobre],
    ISNULL(O.od_material, 'No Definido')                  AS [Material],
    ISNULL(O.od_tipo_lente, 'No Definido')                AS [Tipo_Lente],
    CAST(ISNULL(O.od_esfera, 0) AS DECIMAL(10,2))         AS [Esfera_OD],
    CAST(ISNULL(O.oi_esfera, 0) AS DECIMAL(10,2))         AS [Esfera_OI],
    V.monto_total                                         AS [Monto_Total],
    V.monto_pagado                                        AS [Monto_Pagado],
    V.saldo_pendiente                                     AS [Saldo_Pendiente],
    -- NUEVO: USD
    V.monto_total_usd                                     AS [Monto_Total_USD],
    V.monto_pagado_usd                                    AS [Monto_Pagado_USD],
    V.saldo_pendiente_usd                                 AS [Saldo_Pendiente_USD],
    V.estado_pedido                                       AS [Estado_Pago],
    CASE V.estado_pedido
        WHEN 'PAGADO' THEN 'Cobrado'
        WHEN 'PENDIENTE' THEN 'Pendiente de Cobro'
        ELSE 'Desconocido'
    END                                                   AS [Estatus_Cobro],
    NULL                                                  AS [Fecha_Recepcion],
    NULL                                                  AS [Dias_Lab],
    YEAR(CAST(DATEADD(HOUR, -4, V.fecha_pedido) AS DATE)) AS [Anio],
    MONTH(CAST(DATEADD(HOUR, -4, V.fecha_pedido) AS DATE)) AS [Mes_Nro],
    CASE MONTH(CAST(DATEADD(HOUR, -4, V.fecha_pedido) AS DATE))
        WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
    END                                                   AS [Mes_Nombre],
    CAST(YEAR(CAST(DATEADD(HOUR, -4, V.fecha_pedido) AS DATE)) AS VARCHAR(4))
        + '-'
        + RIGHT('0' + CAST(MONTH(CAST(DATEADD(HOUR, -4, V.fecha_pedido) AS DATE)) AS VARCHAR(2)), 2)
                                                          AS [Periodo],
    CASE
        WHEN V.estado_pedido = 'PAGADO' THEN 'Cobrado'
        ELSE 'Pendiente de Cobro'
    END                                                   AS [Semaforo_Meta],
    'Dato Operativo Real'                                 AS [Calidad_Analisis]
FROM [dbo].[Ventas_Pedidos] V
INNER JOIN [dbo].[Operaciones_Ordenes_Cristales] O ON V.id_pedido = O.id_pedido_venta
LEFT JOIN [dbo].[Maestro_Clientes] C ON V.id_cliente = C.id_cliente
WHERE V.fecha_pedido >= '2025-01-01';
GO

-- Fact_Pedidos — repara Estado_Orden_Detalle con estado_entrega_api (v2). Conserva el campo v1.
DROP VIEW IF EXISTS [dbo].[Fact_Pedidos];
GO

CREATE VIEW [dbo].[Fact_Pedidos] AS
SELECT
    id_pedido,
    numero_pedido,
    id_sucursal,
    id_cliente,
    id_empleado AS id_asesor,
    monto_total,
    monto_pagado,
    saldo_pendiente,
    estado_pedido AS [estado_pago_interno],
    -- NUEVO: USD
    monto_total_usd,
    monto_pagado_usd,
    saldo_pendiente_usd,
    codigo_documento_api,
    id_estado_orden,
    -- Estado_Orden_Detalle: mapeo VIEJO (v1), conservado para no romper consumidores existentes
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
    -- NUEVO: el dato real de v2 (repara la inteligencia logística que nunca funcionó)
    estado_entrega_api,
    CASE estado_entrega_api
        WHEN 'A' THEN 'ACTIVO'
        WHEN 'P' THEN 'PENDIENTE'
        WHEN 'CA' THEN 'CANCELADO'
        ELSE 'SIN DATO'
    END AS [Estado_Entrega_Detalle],
    CAST(DATEADD(HOUR, -4, fecha_pedido) AS DATE) AS fecha_pedido_completa,
    YEAR(DATEADD(HOUR, -4, fecha_pedido)) AS anio_pedido,
    MONTH(DATEADD(HOUR, -4, fecha_pedido)) AS mes_pedido_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_pedido)),
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_pedido_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -4, fecha_pedido)),
        '-',
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_pedido)) AS VARCHAR(2)), 2)
    ) AS periodo_pedido
FROM Ventas_Pedidos
WHERE fecha_pedido >= '2025-01-01'
  AND saldo_pendiente >= 0;
GO

-- Fact_Ventas — usa monto_neto_usd real (Gesvision), NO recalcula /1.16 (evita mezclar IGTF con IVA)
DROP VIEW IF EXISTS [dbo].[Fact_Ventas];
GO

CREATE VIEW [dbo].[Fact_Ventas] AS
SELECT
    id_factura,
    id_sucursal,
    id_cliente,
    ISNULL(id_empleado, 0) AS id_vendedor,
    monto_total,
    CASE
        WHEN monto_total < 0 THEN 'Devolución'
        ELSE 'Venta'
    END AS tipo_transaccion,
    CAST(monto_total / 1.16 AS DECIMAL(18,4)) AS monto_sin_iva,
    -- NUEVO: USD (monto_neto_usd real de Gesvision, no recalculado — descuenta correctamente el IGTF)
    monto_total_usd,
    monto_neto_usd AS monto_sin_iva_usd,
    igtf_ves,
    estado_entrega_api,
    codigo_documento_api,
    CAST(DATEADD(HOUR, -4, fecha_factura) AS DATE) AS fecha_factura,
    YEAR(DATEADD(HOUR, -4, fecha_factura)) AS anio_factura,
    MONTH(DATEADD(HOUR, -4, fecha_factura)) AS mes_factura_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_factura)),
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_factura_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, fecha_factura)), '-',
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_factura
FROM Ventas_Cabecera
WHERE fecha_factura >= '2025-01-01';
GO

-- Fact_Ventas_Analitico — con precio_lista_unitario_usd derivado por tasa de la factura
DROP VIEW IF EXISTS [dbo].[Fact_Ventas_Analitico];
GO

CREATE VIEW [dbo].[Fact_Ventas_Analitico] AS
SELECT
    D.id_factura,
    D.id_linea,
    D.id_producto,
    V.id_sucursal,
    P.nombre_producto,
    P.nombre_modelo_padre,
    P.material_marco,
    P.tipo_montura,
    P.genero_objetivo,
    P.id_categoria,
    C.nombre_categoria,
    C.id_categoria_padre,
    D.cantidad,
    ROUND(D.precio_unitario, 2)                        AS precio_lista_unitario,
    ROUND(D.total_linea, 2)                            AS monto_final_transaccional,
    ROUND(D.total_linea - (D.cantidad * D.precio_unitario), 2) AS ajuste_comercial_neto,
    -- NUEVO: USD
    D.total_linea_usd,
    ROUND(D.precio_unitario / NULLIF(V.tasa_cambio, 0), 4) AS precio_lista_unitario_usd,
    CAST(DATEADD(HOUR, -4, V.fecha_factura) AS DATE)  AS fecha_factura,
    YEAR(DATEADD(HOUR, -4, V.fecha_factura))           AS anio_venta,
    MONTH(DATEADD(HOUR, -4, V.fecha_factura))          AS mes_venta_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, V.fecha_factura)),
        'Enero','Febrero','Marzo','Abril','Mayo','Junio',
        'Julio','Agosto','Septiembre','Octubre',
        'Noviembre','Diciembre')                       AS mes_venta_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, V.fecha_factura)),
        '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4,
        V.fecha_factura)) AS VARCHAR(2)), 2))          AS periodo_venta
FROM Ventas_Detalle D
INNER JOIN Ventas_Cabecera V ON D.id_factura = V.id_factura
INNER JOIN Maestro_Productos P ON D.id_producto = P.id_producto
INNER JOIN Maestro_Categorias C ON P.id_categoria = C.id_categoria;
GO

-- Fact_Ventas_Detalle — versión sin JOIN a catálogo (robusta, sin exclusión silenciosa)
DROP VIEW IF EXISTS [dbo].[Fact_Ventas_Detalle];
GO

CREATE VIEW [dbo].[Fact_Ventas_Detalle] AS
SELECT
    D.id_factura,
    D.id_linea,
    D.id_producto,
    D.cantidad,
    V.id_sucursal,
    D.precio_unitario AS precio_lista_unitario,
    D.total_linea AS monto_final_transaccional,
    CAST(D.total_linea - (D.cantidad * D.precio_unitario) AS DECIMAL(18,4)) AS ajuste_comercial_neto,
    -- NUEVO: USD
    D.total_linea_usd,
    ROUND(D.precio_unitario / NULLIF(V.tasa_cambio, 0), 4) AS precio_lista_unitario_usd,
    CAST(DATEADD(HOUR, -4, V.fecha_factura) AS DATE) AS fecha_factura,
    YEAR(DATEADD(HOUR, -4, V.fecha_factura)) AS anio_venta,
    MONTH(DATEADD(HOUR, -4, V.fecha_factura)) AS mes_venta_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, V.fecha_factura)),
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_venta_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, V.fecha_factura)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, V.fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_venta
FROM Ventas_Detalle D
INNER JOIN Ventas_Cabecera V ON D.id_factura = V.id_factura;
GO

-- Fact_Ventas_por_Categoria (construida sobre Fact_Ventas_Analitico)
DROP VIEW IF EXISTS [dbo].[Fact_Ventas_por_Categoria];
GO

CREATE VIEW [dbo].[Fact_Ventas_por_Categoria] AS
SELECT 
    fv.id_factura,
    fv.id_sucursal,
    nombre_categoria as categoria_agrupada,
    fv.nombre_categoria AS categoria_original,
    ROUND(fv.monto_final_transaccional, 2) AS venta_neta,
    -- NUEVO: USD
    fv.total_linea_usd AS venta_neta_usd,
    fv.fecha_factura,
    fv.anio_venta,
    fv.mes_venta_nro
FROM Fact_Ventas_Analitico fv
WHERE fv.nombre_categoria IS NOT NULL;
GO

-- Fact_Tesoreria — fix del filtro tipo_movimiento ('MC' no existe en los datos; el código real es 'CP')
DROP VIEW IF EXISTS [dbo].[Fact_Tesoreria];
GO

CREATE VIEW [dbo].[Fact_Tesoreria] AS
SELECT 
    id_pago_tesoreria,
    id_sucursal,
    UPPER(TRIM(descripcion)) AS concepto_movimiento,
    UPPER(TRIM(metodo_pago_nombre)) AS metodo_pago,
    monto AS monto_movimiento,
    -- NUEVO: USD
    monto_usd AS monto_movimiento_usd,
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
    CAST(DATEADD(HOUR, -4, fecha_movimiento) AS DATE) AS fecha_completa,
    YEAR(DATEADD(HOUR, -4, fecha_movimiento)) AS anio_tesoreria,
    MONTH(DATEADD(HOUR, -4, fecha_movimiento)) AS mes_tesoreria_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_movimiento)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_tesoreria_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, fecha_movimiento)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_movimiento)) AS VARCHAR(2)), 2)) AS periodo_tesoreria
FROM [dbo].[Finanzas_Tesoreria]
WHERE fecha_movimiento >= '2025-01-01'
  AND UPPER(TRIM(tipo_movimiento)) = 'CP'   -- corregido: 'MC' no existe en los datos actuales
  AND monto <> 0;
GO


-- ============================================================
-- CAPA 4: 20 VISTAS KPI_Inf1_*, KPI_Inf3_*, KPI_Inf5_* MODIFICADAS
-- (KPI_Inf1_Cantidad_Facturas, KPI_Inf3_Pct_Cobro_Inmediato, KPI_Inf4_* completo, KPI_Inf5_UPT
--  no requirieron cambios — no incluidas aquí)
-- ============================================================

-- KPI_Inf1_Devoluciones
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Devoluciones];
GO

CREATE VIEW [dbo].[KPI_Inf1_Devoluciones] AS
SELECT
    id_factura,
    id_sucursal,
    id_cliente,
    id_vendedor,
    fecha_factura,
    anio_factura,
    mes_factura_nro,
    mes_factura_nombre,
    periodo_factura,
    ROUND(ABS(monto_total), 2)      AS devolucion,
    ROUND(ABS(monto_sin_iva), 2)    AS devolucion_sin_iva,
    -- NUEVO: USD
    ROUND(ABS(monto_total_usd), 2)      AS devolucion_usd,
    ROUND(ABS(monto_sin_iva_usd), 2)    AS devolucion_sin_iva_usd
FROM Fact_Ventas
WHERE tipo_transaccion = 'Devolución';
GO

-- KPI_Inf1_Mix_Medios_Pago
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Mix_Medios_Pago];
GO

CREATE VIEW [dbo].[KPI_Inf1_Mix_Medios_Pago] AS
SELECT
    id_cobro,
    id_sucursal,
    id_cliente,
    id_pedido,
    id_factura,
    metodo_pago,
    tipo_recaudo,
    fecha_completa,
    anio_cobro,
    mes_nro,
    mes_nombre,
    periodo,
    ROUND(importe_neto, 2)    AS importe_neto,
    -- NUEVO: USD
    ROUND(importe_neto_usd, 2) AS importe_neto_usd
FROM Fact_Recaudo
WHERE importe_neto > 0;
GO

-- KPI_Inf1_Proyeccion_Venta_Neta
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Proyeccion_Venta_Neta];
GO

CREATE VIEW [dbo].[KPI_Inf1_Proyeccion_Venta_Neta] AS
SELECT
    id_factura,
    id_sucursal,
    id_cliente,
    id_vendedor,
    fecha_factura,
    anio_factura,
    mes_factura_nro,
    mes_factura_nombre,
    periodo_factura,
    tipo_transaccion,
    ROUND(monto_total, 2)                                    AS monto_neto,
    -- NUEVO: USD
    ROUND(monto_total_usd, 2)                                AS monto_neto_usd,
    DAY(EOMONTH(fecha_factura))                              AS dias_del_mes,
    DAY(CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE))      AS dia_hoy_gmt4,
    MONTH(DATEADD(HOUR, -4, GETUTCDATE()))                   AS mes_actual_gmt4,
    YEAR(DATEADD(HOUR, -4, GETUTCDATE()))                    AS anio_actual_gmt4,
    CASE
        WHEN mes_factura_nro = MONTH(DATEADD(HOUR, -4, GETUTCDATE()))
         AND anio_factura    = YEAR(DATEADD(HOUR, -4, GETUTCDATE()))
            THEN 1
        ELSE 0
    END                                                      AS es_mes_actual
FROM Fact_Ventas;
GO

-- KPI_Inf1_Ticket_Promedio — recalculado con SUM(monto_total_usd)/cantidad_pedidos, no reconvertido
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Ticket_Promedio];
GO

CREATE VIEW [dbo].[KPI_Inf1_Ticket_Promedio] AS
WITH Ventas AS (
    SELECT
        periodo_factura                  AS periodo,
        anio_factura                     AS anio,
        mes_factura_nro                  AS mes_nro,
        mes_factura_nombre               AS mes_nombre,
        id_sucursal,
        ROUND(SUM(monto_total), 2)       AS venta_neta,
        -- NUEVO: USD, sumado a nivel de factura ANTES de dividir
        ROUND(SUM(monto_total_usd), 2)   AS venta_neta_usd
    FROM Fact_Ventas
    GROUP BY periodo_factura, anio_factura,
             mes_factura_nro, mes_factura_nombre,
             id_sucursal
),
Pedidos AS (
    SELECT
        periodo_pedido                   AS periodo,
        id_sucursal,
        COUNT(DISTINCT id_pedido)        AS cantidad_pedidos
    FROM Fact_Pedidos
    GROUP BY periodo_pedido, id_sucursal
)
SELECT
    V.periodo,
    V.anio,
    V.mes_nro,
    V.mes_nombre,
    V.id_sucursal,
    V.venta_neta,
    V.venta_neta_usd,
    ISNULL(P.cantidad_pedidos, 0)        AS cantidad_pedidos,
    ROUND(
        CASE
            WHEN ISNULL(P.cantidad_pedidos, 0) = 0 THEN 0
            ELSE V.venta_neta / P.cantidad_pedidos
        END, 2)                          AS ticket_promedio,
    -- NUEVO: USD, sobre el agregado ya sumado, no reconvertido
    ROUND(
        CASE
            WHEN ISNULL(P.cantidad_pedidos, 0) = 0 THEN 0
            ELSE V.venta_neta_usd / P.cantidad_pedidos
        END, 2)                          AS ticket_promedio_usd
FROM Ventas V
LEFT JOIN Pedidos P
    ON V.periodo    = P.periodo
    AND V.id_sucursal = P.id_sucursal;
GO

-- KPI_Inf1_Total_Cobrado
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Total_Cobrado];
GO

CREATE VIEW [dbo].[KPI_Inf1_Total_Cobrado] AS
SELECT
    id_cobro,
    id_sucursal,
    id_cliente,
    id_pedido,
    id_factura,
    metodo_pago,
    tipo_recaudo,
    fecha_completa,
    anio_cobro,
    mes_nro,
    mes_nombre,
    periodo,
    ROUND(importe_neto, 2)    AS importe_neto,
    -- NUEVO: USD
    ROUND(importe_neto_usd, 2) AS importe_neto_usd
FROM Fact_Recaudo;
GO

-- KPI_Inf1_Venta_Bruta
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Venta_Bruta];
GO

CREATE VIEW [dbo].[KPI_Inf1_Venta_Bruta] AS
SELECT
    id_factura,
    id_sucursal,
    id_cliente,
    id_vendedor,
    fecha_factura,
    anio_factura,
    mes_factura_nro,
    mes_factura_nombre,
    periodo_factura,
    ROUND(monto_total, 2)      AS venta_bruta,
    ROUND(monto_sin_iva, 2)    AS venta_bruta_sin_iva,
    -- NUEVO: USD
    ROUND(monto_total_usd, 2)      AS venta_bruta_usd,
    ROUND(monto_sin_iva_usd, 2)    AS venta_bruta_sin_iva_usd
FROM Fact_Ventas
WHERE tipo_transaccion = 'Venta';
GO

-- KPI_Inf1_Venta_Neta — KPI probablemente más visible del portal; el signo se preserva automáticamente
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Venta_Neta];
GO

CREATE VIEW [dbo].[KPI_Inf1_Venta_Neta] AS
SELECT
    id_factura,
    id_sucursal,
    id_cliente,
    id_vendedor,
    fecha_factura,
    anio_factura,
    mes_factura_nro,
    mes_factura_nombre,
    periodo_factura,
    tipo_transaccion,
    ROUND(monto_total, 2)      AS monto_neto,
    ROUND(monto_sin_iva, 2)    AS monto_neto_sin_iva,
    -- NUEVO: USD (el signo se preserva automáticamente: ventas +, devoluciones -)
    ROUND(monto_total_usd, 2)      AS monto_neto_usd,
    ROUND(monto_sin_iva_usd, 2)    AS monto_neto_sin_iva_usd
FROM Fact_Ventas;
GO

-- KPI_Inf1_Venta_Neta_Producto (sobre Fact_Ventas_Detalle — sin problema de JOIN)
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Venta_Neta_Producto];
GO

CREATE VIEW [dbo].[KPI_Inf1_Venta_Neta_Producto] AS
SELECT
    id_factura,
    id_linea,
    id_producto,
    id_sucursal,
    cantidad,
    fecha_factura,
    anio_venta,
    mes_venta_nro,
    mes_venta_nombre,
    periodo_venta,
    ROUND(monto_final_transaccional, 2)    AS monto_final_transaccional,
    ROUND(precio_lista_unitario, 2)        AS precio_lista_unitario,
    ROUND(ajuste_comercial_neto, 2)        AS ajuste_comercial_neto,
    -- NUEVO: USD
    total_linea_usd,
    precio_lista_unitario_usd
FROM Fact_Ventas_Detalle;
GO

-- KPI_Inf1_Venta_Teorica_Lista
DROP VIEW IF EXISTS [dbo].[KPI_Inf1_Venta_Teorica_Lista];
GO

CREATE VIEW [dbo].[KPI_Inf1_Venta_Teorica_Lista] AS
SELECT
    id_factura,
    id_linea,
    id_producto,
    id_sucursal,
    cantidad,
    fecha_factura,
    anio_venta,
    mes_venta_nro,
    mes_venta_nombre,
    periodo_venta,
    ROUND(precio_lista_unitario, 2)                        AS precio_lista_unitario,
    ROUND(monto_final_transaccional, 2)                    AS monto_final_transaccional,
    ROUND(cantidad * precio_lista_unitario, 2)             AS venta_teorica_lista,
    ROUND(monto_final_transaccional -
          (cantidad * precio_lista_unitario), 2)           AS descuento_aplicado,
    -- NUEVO: USD
    ROUND(cantidad * precio_lista_unitario_usd, 2)         AS venta_teorica_lista_usd,
    ROUND(total_linea_usd - (cantidad * precio_lista_unitario_usd), 2) AS descuento_aplicado_usd
FROM Fact_Ventas_Detalle;
GO

-- KPI_Inf3_Monto_Pedidos
DROP VIEW IF EXISTS [dbo].[KPI_Inf3_Monto_Pedidos];
GO

CREATE VIEW [dbo].[KPI_Inf3_Monto_Pedidos] AS
SELECT
    id_pedido,
    numero_pedido,
    id_sucursal,
    id_cliente,
    id_asesor,
    estado_pago_interno,
    id_estado_orden,
    Estado_Orden_Detalle,
    estado_entrega_api,
    Estado_Entrega_Detalle,
    fecha_pedido_completa,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    periodo_pedido,
    ROUND(monto_total, 2)        AS monto_total,
    ROUND(monto_pagado, 2)       AS monto_pagado,
    ROUND(saldo_pendiente, 2)    AS saldo_pendiente,
    -- NUEVO: USD
    ROUND(monto_total_usd, 2)      AS monto_total_usd,
    ROUND(monto_pagado_usd, 2)     AS monto_pagado_usd,
    ROUND(saldo_pendiente_usd, 2)  AS saldo_pendiente_usd
FROM Fact_Pedidos;
GO

-- KPI_Inf3_Pct_Nivel_Abono
DROP VIEW IF EXISTS [dbo].[KPI_Inf3_Pct_Nivel_Abono];
GO

CREATE VIEW [dbo].[KPI_Inf3_Pct_Nivel_Abono] AS
SELECT
    periodo_pedido,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    id_sucursal,
    ROUND(SUM(monto_total), 2)                              AS monto_total,
    ROUND(SUM(monto_pagado), 2)                             AS monto_pagado,
    ROUND(SUM(saldo_pendiente), 2)                          AS saldo_pendiente,
    -- NUEVO: USD
    ROUND(SUM(monto_total_usd), 2)                          AS monto_total_usd,
    ROUND(SUM(monto_pagado_usd), 2)                         AS monto_pagado_usd,
    ROUND(SUM(saldo_pendiente_usd), 2)                      AS saldo_pendiente_usd,
    ROUND(
        SUM(monto_pagado) * 100.0 /
        NULLIF(SUM(monto_total), 0)
    , 2)                                                    AS pct_nivel_abono
FROM Fact_Pedidos
GROUP BY periodo_pedido, anio_pedido,
         mes_pedido_nro, mes_pedido_nombre,
         id_sucursal;
GO

-- KPI_Inf3_Pedidos_Liquidar
-- NOTA: 36 pedidos con saldo_pendiente(VES)>0 pero saldo_pendiente_usd=0 (truncamiento de sobrepago).
-- Pendiente decisión de presentación (ver docs/claude.md).
DROP VIEW IF EXISTS [dbo].[KPI_Inf3_Pedidos_Liquidar];
GO

CREATE VIEW [dbo].[KPI_Inf3_Pedidos_Liquidar] AS
SELECT
    id_pedido,
    numero_pedido,
    id_sucursal,
    id_cliente,
    id_asesor,
    estado_pago_interno,
    fecha_pedido_completa,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    periodo_pedido,
    ROUND(monto_total, 2)        AS monto_total,
    ROUND(monto_pagado, 2)       AS monto_pagado,
    ROUND(saldo_pendiente, 2)    AS saldo_pendiente,
    -- NUEVO: USD
    ROUND(monto_total_usd, 2)      AS monto_total_usd,
    ROUND(monto_pagado_usd, 2)     AS monto_pagado_usd,
    ROUND(saldo_pendiente_usd, 2)  AS saldo_pendiente_usd
FROM Fact_Pedidos
WHERE saldo_pendiente > 0;
GO

-- KPI_Inf3_Recaudado_Pedidos
DROP VIEW IF EXISTS [dbo].[KPI_Inf3_Recaudado_Pedidos];
GO

CREATE VIEW [dbo].[KPI_Inf3_Recaudado_Pedidos] AS
SELECT
    id_pedido,
    numero_pedido,
    id_sucursal,
    id_cliente,
    id_asesor,
    estado_pago_interno,
    fecha_pedido_completa,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    periodo_pedido,
    ROUND(monto_total, 2)        AS monto_total,
    ROUND(monto_pagado, 2)       AS monto_pagado,
    ROUND(saldo_pendiente, 2)    AS saldo_pendiente,
    -- NUEVO: USD
    ROUND(monto_total_usd, 2)      AS monto_total_usd,
    ROUND(monto_pagado_usd, 2)     AS monto_pagado_usd,
    ROUND(saldo_pendiente_usd, 2)  AS saldo_pendiente_usd
FROM Fact_Pedidos
WHERE monto_pagado > 0;
GO

-- KPI_Inf3_Saldo_Pendiente — duplicado EXACTO e intencional de KPI_Inf3_Pedidos_Liquidar
-- (decisión: NO fusionar, mantener ambas vistas independientes por falta de visibilidad de consumidores)
DROP VIEW IF EXISTS [dbo].[KPI_Inf3_Saldo_Pendiente];
GO

CREATE VIEW [dbo].[KPI_Inf3_Saldo_Pendiente] AS
SELECT
    id_pedido,
    numero_pedido,
    id_sucursal,
    id_cliente,
    id_asesor,
    estado_pago_interno,
    fecha_pedido_completa,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    periodo_pedido,
    ROUND(monto_total, 2)        AS monto_total,
    ROUND(monto_pagado, 2)       AS monto_pagado,
    ROUND(saldo_pendiente, 2)    AS saldo_pendiente,
    -- NUEVO: USD
    ROUND(monto_total_usd, 2)      AS monto_total_usd,
    ROUND(monto_pagado_usd, 2)     AS monto_pagado_usd,
    ROUND(saldo_pendiente_usd, 2)  AS saldo_pendiente_usd
FROM Fact_Pedidos
WHERE saldo_pendiente > 0;
GO

-- KPI_Inf5_ASP — recalculado con SUM(total_linea_usd)/SUM(cantidad)
DROP VIEW IF EXISTS [dbo].[KPI_Inf5_ASP];
GO

CREATE VIEW [dbo].[KPI_Inf5_ASP] AS
WITH VentaNeta AS (
    SELECT
        periodo_venta, anio_venta, mes_venta_nro, mes_venta_nombre, id_sucursal,
        ROUND(SUM(monto_final_transaccional), 2)  AS venta_neta_producto,
        -- NUEVO: USD sumado a nivel de línea
        ROUND(SUM(total_linea_usd), 2)            AS venta_neta_producto_usd
    FROM Fact_Ventas_Detalle
    GROUP BY periodo_venta, anio_venta, mes_venta_nro, mes_venta_nombre, id_sucursal
),
Unidades AS (
    SELECT periodo_venta, id_sucursal, SUM(cantidad) AS unidades_vendidas
    FROM Fact_Ventas_Detalle
    GROUP BY periodo_venta, id_sucursal
)
SELECT
    V.periodo_venta, V.anio_venta, V.mes_venta_nro, V.mes_venta_nombre, V.id_sucursal,
    V.venta_neta_producto, V.venta_neta_producto_usd,
    ISNULL(U.unidades_vendidas, 0) AS unidades_vendidas,
    ROUND(V.venta_neta_producto / NULLIF(ISNULL(U.unidades_vendidas, 0), 0), 2) AS asp,
    -- NUEVO: USD, sobre el agregado ya sumado
    ROUND(V.venta_neta_producto_usd / NULLIF(ISNULL(U.unidades_vendidas, 0), 0), 2) AS asp_usd
FROM VentaNeta V
LEFT JOIN Unidades U ON V.periodo_venta = U.periodo_venta AND V.id_sucursal = U.id_sucursal;
GO

-- KPI_Inf5_Capital_Invertido — el KPI de negocio verificado: $5,798,359.05 (excluye LENTES,
-- TRATAMIENTOS, LENTES DE CONTACTO — heredado de Fact_Inventario)
DROP VIEW IF EXISTS [dbo].[KPI_Inf5_Capital_Invertido];
GO

CREATE VIEW [dbo].[KPI_Inf5_Capital_Invertido] AS
SELECT
    id_producto,
    id_sucursal,
    cantidad_disponible,
    estado_stock,
    calidad_costo,
    fecha_movimiento_stock,
    ROUND(costo_unitario, 2)           AS costo_unitario,
    ROUND(valor_total_inventario, 2)   AS valor_total_inventario,
    -- NUEVO: USD
    costo_unitario_usd,
    valor_total_inventario_usd
FROM Fact_Inventario
WHERE id_producto NOT IN (
    SELECT SK_Producto FROM Dim_Productos
    WHERE Segmento_Comercial IN ('LENTES', 'TRATAMIENTOS')
);
GO

-- KPI_Inf5_Stock_Fisico (+ precio_venta_usd de Dim_Productos)
DROP VIEW IF EXISTS [dbo].[KPI_Inf5_Stock_Fisico];
GO

CREATE VIEW [dbo].[KPI_Inf5_Stock_Fisico] AS
SELECT
    I.id_producto,
    I.id_sucursal,
    I.cantidad_disponible,
    I.estado_stock,
    I.calidad_costo,
    I.fecha_movimiento_stock,
    ROUND(I.costo_unitario, 2)           AS costo_unitario,
    ROUND(I.valor_total_inventario, 2)   AS valor_total_inventario,
    -- NUEVO: USD
    I.costo_unitario_usd,
    I.valor_total_inventario_usd,
    P.nombre_producto,
    P.Marca,
    P.Categoria,
    P.Categoria_Padre,
    P.Segmento_Comercial,
    P.Genero,
    P.Material,
    P.Tipo_Montura,
    ROUND(P.Precio_Venta, 2)             AS precio_venta,
    -- NUEVO: USD
    P.Precio_Venta_USD                   AS precio_venta_usd
FROM Fact_Inventario I
LEFT JOIN Dim_Productos P ON I.id_producto = P.SK_Producto;
GO

-- KPI_Inf5_Unidades_Vendidas
DROP VIEW IF EXISTS [dbo].[KPI_Inf5_Unidades_Vendidas];
GO

CREATE VIEW [dbo].[KPI_Inf5_Unidades_Vendidas] AS
SELECT
    id_factura, id_linea, id_producto, id_sucursal, fecha_factura,
    anio_venta, mes_venta_nro, mes_venta_nombre, periodo_venta, cantidad,
    ROUND(precio_lista_unitario, 2)      AS precio_lista_unitario,
    ROUND(monto_final_transaccional, 2)  AS monto_final_transaccional,
    -- NUEVO: USD
    precio_lista_unitario_usd,
    total_linea_usd
FROM Fact_Ventas_Detalle;
GO

-- KPI_Inf5_Volumen_Unidades — reconstruye la misma lógica de Fact_Ventas_Analitico (duplicado
-- intencional, mismo criterio de exclusión por catálogo, ver docs/claude.md)
DROP VIEW IF EXISTS [dbo].[KPI_Inf5_Volumen_Unidades];
GO

CREATE VIEW [dbo].[KPI_Inf5_Volumen_Unidades] AS
SELECT 
    D.id_factura, D.id_linea, D.id_producto, V.id_sucursal,
    P.nombre_producto, P.id_categoria, C.nombre_categoria, D.cantidad,
    CAST(DATEADD(HOUR, -4, V.fecha_factura) AS DATE)  AS fecha_factura,
    YEAR(DATEADD(HOUR, -4, V.fecha_factura))           AS anio_venta,
    MONTH(DATEADD(HOUR, -4, V.fecha_factura))          AS mes_venta_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, V.fecha_factura)),
        'Enero','Febrero','Marzo','Abril','Mayo','Junio',
        'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_venta_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, V.fecha_factura)), '-',
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, V.fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_venta,
    ROUND(D.total_linea, 2)                            AS monto_final_transaccional,
    -- NUEVO: USD
    D.total_linea_usd
FROM Ventas_Detalle D
INNER JOIN Ventas_Cabecera V ON D.id_factura = V.id_factura
INNER JOIN Maestro_Productos P ON D.id_producto = P.id_producto
INNER JOIN Maestro_Categorias C ON P.id_categoria = C.id_categoria
WHERE V.fecha_factura >= '2025-01-01';
GO


-- ============================================================
-- PARCHE DE DATOS: líneas de detalle y cobros huérfanos sin USD
-- 44 líneas de Ventas_Detalle y 210 filas de Finanzas_Cobros quedaron sin dolarizar por el ETL
-- (backfill/incremental no las tocó, causa raíz probable: timing entre la cabecera dolarizada y la
-- inserción v1 de líneas de notas de crédito). Corregido con UPDATE directo usando la tasa ya
-- disponible en la cabecera/Param_Tasas_Cambio. Aplicado el 20/07/2026.
-- ============================================================

-- Parche 1: 44 líneas de Ventas_Detalle
UPDATE d
   SET d.total_linea_usd = ROUND(d.total_linea * c.monto_total_usd / c.monto_total, 2)
FROM dbo.Ventas_Detalle d
INNER JOIN dbo.Ventas_Cabecera c ON c.id_factura = d.id_factura
WHERE d.total_linea_usd IS NULL
  AND c.monto_total IS NOT NULL AND c.monto_total <> 0
  AND c.monto_total_usd IS NOT NULL;

-- Parche 2: 210 filas de Finanzas_Cobros (mismo patrón COALESCE que sync_dolar_cobros)
UPDATE fc
   SET fc.tasa_cambio_aplicada = COALESCE(vc.tasa_cambio, pt.tasa),
       fc.monto_cobrado_usd    = ROUND(fc.monto_cobrado / COALESCE(vc.tasa_cambio, pt.tasa), 2),
       fc.origen_tasa          = CASE WHEN vc.tasa_cambio IS NOT NULL THEN 'FACTURA_REAL' ELSE 'DERIVADA_FECHA' END,
       fc.fecha_dolarizacion   = SYSUTCDATETIME()
FROM dbo.Finanzas_Cobros fc
LEFT JOIN dbo.Ventas_Cabecera vc ON vc.id_factura = fc.id_factura AND vc.tasa_cambio IS NOT NULL
OUTER APPLY (SELECT TOP 1 tasa FROM dbo.Param_Tasas_Cambio WHERE fecha <= CAST(fc.fecha_cobro AS DATE) ORDER BY fecha DESC) pt
WHERE fc.monto_cobrado_usd IS NULL
  AND COALESCE(vc.tasa_cambio, pt.tasa) IS NOT NULL;
