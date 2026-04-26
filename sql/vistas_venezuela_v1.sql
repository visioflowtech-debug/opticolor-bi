/* ================================================================
   OPTICOLOR BI VENEZUELA — Vistas SQL Capa BI (FASE A)

   Adaptadas de: Optilux Panamá (Diccionario_vistas_dax.sql)
   Fecha: 25 de Abril de 2026
   Cambios globales: GMT-4 (Venezuela), IVA 16%, CREATE OR ALTER VIEW

   VISTAS INCLUIDAS EN FASE A (10):
   - Dim_Categorias
   - Dim_Empleados
   - Dim_Clientes
   - Fact_Ventas
   - Fact_Ventas_Detalle
   - Fact_Ventas_Analitico
   - Fact_Recaudo
   - Fact_Pedidos
   - Fact_Inventario
   - Vista_Notificacion_ETL

   VISTAS OMITIDAS (se harán en Fase B):
   - Dim_Sucursales (reescritura completa — 103 sucursales VE)
   - Dim_Sucursales_Limpia (depende de Dim_Sucursales)
   - Dim_MetodosPago (requiere datos reales de Venezuela)
   - Dim_Productos (verificar Maestro_Categorizacion_Comercial)
   - Fact_Examenes (sustitución de GHL)
   - Fact_Citas (Marketing_Citas = 0 registros)
   - Fact_Operaciones_Maestra (verificar dependencias)
   - Fact_Ventas_Por_Motivo (depende de Marketing_Citas)

   Estado: Listo para desplegar a Azure SQL
   ================================================================ */

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ================================================================
-- 1. Dim_Categorias — Sin dependencias, sin zona horaria
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Dim_Categorias] AS
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

-- ================================================================
-- 2. Dim_Empleados — Sin dependencias, sin zona horaria
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Dim_Empleados] AS
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

-- ================================================================
-- 3. Dim_Clientes — GMT-4 (Venezuela)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Dim_Clientes] AS
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

    -- INTELIGENCIA DE TIEMPO (Ajustada a GMT-4 Venezuela)
    CAST(DATEADD(HOUR, -4, fecha_creacion_cliente) AS DATE) AS fecha_registro_completa,
    YEAR(DATEADD(HOUR, -4, fecha_creacion_cliente)) AS anio_registro,
    MONTH(DATEADD(HOUR, -4, fecha_creacion_cliente)) AS mes_registro_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_creacion_cliente)),
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_registro_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -4, fecha_creacion_cliente)),
        '-',
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_creacion_cliente)) AS VARCHAR(2)), 2)
    ) AS periodo_registro

FROM Maestro_Clientes;
GO

-- ================================================================
-- 4. Fact_Ventas — GMT-4 + IVA 16% (Venezuela)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Ventas] AS
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
-- ================================================================
-- 5. Fact_Ventas_Detalle — GMT-4 (Venezuela)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Ventas_Detalle] AS
SELECT
    D.id_factura,
    D.id_linea,
    D.id_producto,
    D.cantidad,
    V.id_sucursal,
    -- Precio original del catálogo (PVP)
    D.precio_unitario AS precio_lista_unitario,
    -- Monto final cobrado (Precio con Descuento + IVA)
    D.total_linea AS monto_final_transaccional,

    -- Ajuste Comercial Neto
    CAST(D.total_linea - (D.cantidad * D.precio_unitario) AS DECIMAL(18,4)) AS ajuste_comercial_neto,

    -- INTELIGENCIA DE TIEMPO (Ajustada a GMT-4 Venezuela)
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

-- ================================================================
-- 6. Fact_Ventas_Analitico — Venezuela
-- OPTIMIZADO: eliminado subcategoria_lente (no usado en DAX ni visuals)
-- Usa nombre_categoria directo — sin LIKE masivo
-- KPI_Inf1_Net_Sales: solo consume monto_final_transaccional
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Ventas_Analitico] AS
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
    ROUND(D.total_linea -
          (D.cantidad * D.precio_unitario), 2)         AS ajuste_comercial_neto,
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
INNER JOIN Ventas_Cabecera V
    ON D.id_factura = V.id_factura
INNER JOIN Maestro_Productos P
    ON D.id_producto = P.id_producto
INNER JOIN Maestro_Categorias C
    ON P.id_categoria = C.id_categoria;
GO

-- ================================================================
-- 7. Fact_Recaudo — GMT-4 (Venezuela)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Recaudo] AS
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

    -- 5. INTELIGENCIA DE TIEMPO ESTÁNDAR (Ajustada a GMT-4 Venezuela)
    CAST(DATEADD(HOUR, -4, C.fecha_cobro) AS DATE) AS fecha_completa,
    YEAR(DATEADD(HOUR, -4, C.fecha_cobro)) AS anio_cobro,
    MONTH(DATEADD(HOUR, -4, C.fecha_cobro)) AS mes_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, C.fecha_cobro)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, C.fecha_cobro)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, C.fecha_cobro)) AS VARCHAR(2)), 2)) AS periodo
FROM Finanzas_Cobros C
WHERE C.fecha_cobro >= '2025-01-01';
GO

-- ================================================================
-- 8. Fact_Pedidos — GMT-4 (Venezuela)
-- TODO: Verificar id_estado_orden existe en Maestro_Estados_Orden Venezuela
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Pedidos] AS
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

    -- INTELIGENCIA DE TIEMPO (Ajustada a GMT-4 Venezuela)
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
WHERE fecha_pedido >= '2025-01-01';
GO

-- ================================================================
-- 9. Fact_Inventario — GMT-4 (Venezuela)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Inventario] AS
SELECT
    -- 1. LLAVES
    I.id_producto,
    I.id_sucursal,

    -- 2. MÉTRICAS BASE
    I.cantidad_disponible,

    -- 3. DATOS DE CONTROL (Ajustados a GMT-4 Venezuela)
    -- Cuándo se movió el producto en bodega (Data Gesvision)
    CAST(DATEADD(HOUR, -4, I.fecha_actualizacion) AS DATE) AS fecha_movimiento_stock,

    -- Cuándo corrió tu Python (Para que coincida con la hora del reporte local)
    DATEADD(HOUR, -4, I.fecha_carga_etl) AS fecha_foto_sistema,

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

-- ================================================================
-- 10. Vista_Notificacion_ETL — Venezuela
-- Versión mejorada: distingue PROCESANDO normal vs cuelgue
-- PROCESANDO < 15 min = EN PROCESO (normal)
-- PROCESANDO >= 15 min = ERROR (posible cuelgue)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Vista_Notificacion_ETL] AS
SELECT
    DATEADD(HOUR, -4, MAX(fecha_fin))   AS Fecha_Hora_Venezuela,

    'Sincronización: ' + FORMAT(
        DATEADD(HOUR, -4, MAX(fecha_fin)),
        'dd/MM/yyyy hh:mm tt'
    )                                    AS Notificacion_Texto,

    CASE
        -- Módulo en proceso normal (menos de 15 minutos)
        WHEN EXISTS (
            SELECT 1 FROM Etl_Control_Ejecucion
            WHERE ultimo_estatus = 'PROCESANDO'
            AND modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO')
            AND DATEDIFF(MINUTE, fecha_inicio, GETDATE()) < 15
        ) THEN 'EN PROCESO'

        -- Módulo colgado (más de 15 minutos en PROCESANDO)
        WHEN EXISTS (
            SELECT 1 FROM Etl_Control_Ejecucion
            WHERE ultimo_estatus = 'PROCESANDO'
            AND modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO')
            AND DATEDIFF(MINUTE, fecha_inicio, GETDATE()) >= 15
        ) THEN 'ERROR'

        -- Cualquier otro estado que no sea COMPLETADO
        WHEN EXISTS (
            SELECT 1 FROM Etl_Control_Ejecucion
            WHERE ultimo_estatus NOT IN ('COMPLETADO','PROCESANDO')
            AND modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO')
        ) THEN 'ERROR'

        -- Todo completado correctamente
        ELSE 'OK'
    END                                  AS Estado_Salud,

    -- Detalle para diagnóstico
    (
        SELECT COUNT(*) FROM Etl_Control_Ejecucion
        WHERE ultimo_estatus = 'COMPLETADO'
        AND modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO')
    )                                    AS modulos_completados,

    (
        SELECT COUNT(*) FROM Etl_Control_Ejecucion
        WHERE ultimo_estatus = 'PROCESANDO'
        AND modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO')
    )                                    AS modulos_en_proceso,

    (
        SELECT COUNT(*) FROM Etl_Control_Ejecucion
        WHERE ultimo_estatus NOT IN ('COMPLETADO','PROCESANDO')
        AND modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO')
    )                                    AS modulos_con_error

FROM Etl_Control_Ejecucion
WHERE modulo_nombre NOT IN ('FACTURAS_LAB','PEDIDOS_LABORATORIO');
GO

-- ================================================================
-- 11. Dim_Sucursales — Venezuela (103 sucursales, 4 estados activos)
-- JOIN contra Param_Sucursales_Enriquecimiento para geografía
-- latitud/longitud se completan vía frontend de mantenimiento
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Dim_Sucursales] AS
SELECT
    S.id_sucursal,
    UPPER(S.nombre_sucursal)                            AS nombre_sucursal,
    UPPER(ISNULL(NULLIF(S.alias_sucursal, '0'),
          S.nombre_sucursal))                           AS nombre_comercial,

    -- Geografía desde tabla de enriquecimiento
    ISNULL(E.id_estado, 0)                             AS id_estado,
    ISNULL(UPPER(ES.nombre_estado), 'POR CLASIFICAR')  AS estado,
    ISNULL(UPPER(E.zona_gerencial), 'POR CLASIFICAR')  AS zona_gerencial,

    -- Tipo de punto de venta
    ISNULL(UPPER(E.clasificacion), 'POR CLASIFICAR')   AS tipo_punto_venta,

    -- Coordenadas (NULL hasta que el frontend las complete)
    E.latitud,
    E.longitud,

    -- Dirección operativa
    ISNULL(S.direccion_raw, 'SIN DIRECCIÓN')           AS direccion,

    -- Control de calidad del enriquecimiento
    CASE
        WHEN E.id_sucursal IS NULL THEN 0
        ELSE CAST(ISNULL(E.esta_clasificada, 0) AS INT)
    END                                                AS esta_clasificada,

    E.fecha_clasificacion,
    E.usuario_clasifico

FROM Maestro_Sucursales S
LEFT JOIN Param_Sucursales_Enriquecimiento E
    ON S.id_sucursal = E.id_sucursal
LEFT JOIN Param_Venezuela_Estados ES
    ON E.id_estado = ES.id_estado

-- Excluir sucursales internas (Almacén y Laboratorio)
WHERE S.id_sucursal NOT IN (3, 4);
GO

-- ================================================================
-- 12. Dim_MetodosPago — Venezuela
-- Sin reinterpretación: respeta agrupación original de Gesvision
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Dim_MetodosPago] AS
SELECT
    id_metodo_pago,
    UPPER(nombre_metodo) AS metodo_pago,
    tipo_pago_codigo AS codigo_contable
FROM Maestro_Metodos_Pago
WHERE es_activo = 1;
GO

-- ================================================================
-- 13. Dim_Productos — Venezuela
-- Segmentación desde categorías reales Venezuela (distinta a Panamá)
-- Categoría principal: MONTURAS CORRECTIVAS (134) con 118K productos
-- Sin AROS DE MARCA/ECONÓMICOS — no existen en VE
-- Self-JOIN para jerarquía dinámica (blindado vs nuevas categorías)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Dim_Productos] AS
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

    -- Categoría padre dinámica (self-JOIN)
    ISNULL(CP.nombre_categoria,
        ISNULL(C.nombre_categoria, 'SIN CATEGORÍA'))    AS Categoria_Padre,

    -- Segmento Comercial Venezuela — basado en categorías reales
    CASE
        -- Monturas (la categoría dominante en Venezuela)
        WHEN P.id_categoria IN (134, 140, 126, 139)
            THEN 'MONTURAS'
        -- Lentes de sol
        WHEN P.id_categoria = 133
            THEN 'LENTES DE SOL'
        -- Lentes oftálmicos (subcategorías de LENTES id=65)
        WHEN C.id_categoria_padre = 65
          OR P.id_categoria = 65
            THEN 'LENTES'
        -- Lentes de contacto
        WHEN P.id_categoria IN (124, 136, 137)
            THEN 'LENTES DE CONTACTO'
        -- Accesorios y suministros
        WHEN P.id_categoria IN (125, 127, 129, 123)
            THEN 'ACCESORIOS'
        -- Tratamientos y coloraciones
        WHEN P.id_categoria IN (130, 120, 122, 128)
            THEN 'TRATAMIENTOS'
        ELSE 'OTROS'
    END                                                 AS Segmento_Comercial,

    -- ATRIBUTOS TÉCNICOS
    ISNULL(P.material_marco, 'NO APLICA')               AS Material,
    ISNULL(P.genero_objetivo, 'UNISEX')                 AS Genero,
    ISNULL(P.color_comercial, 'S/D')                    AS Color,
    ISNULL(P.tipo_montura, 'S/D')                       AS Tipo_Montura,

    -- DATOS FINANCIEROS
    ISNULL(P.costo_compra, 0)                           AS Costo_Unitario,
    ISNULL(P.precio_venta, 0)                           AS Precio_Venta,

    -- AUDITORÍA
    P.fecha_ultima_actualizacion                        AS Fecha_Dato

FROM Maestro_Productos P
LEFT JOIN Maestro_Marcas M
    ON P.id_marca = M.id_marca
LEFT JOIN Maestro_Categorias C
    ON P.id_categoria = C.id_categoria
LEFT JOIN Maestro_Categorias CP
    ON C.id_categoria_padre = CP.id_categoria
WHERE P.es_inventariable = 1;
GO

-- ================================================================
-- 14. Fact_Examenes — Venezuela
-- Versión simplificada: sin GHL, sin tipo_examen (no en API VE)
-- Columnas validadas contra DAX y visuals del dashboard
-- DAX que consumen esta vista:
--   Total Exámenes = COUNTROWS('Fact_Examenes')
--   % YoY Exámenes, % Crecimiento Real (via fecha_examen_completa)
--   Productividad Optometrista (via id_optometrista)
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Examenes] AS
SELECT
    e.id_examen,
    e.id_cliente,
    e.id_sucursal,

    -- En Venezuela el campo se llama id_empleado (no id_optometrista)
    -- Renombramos para mantener compatibilidad con DAX de Panamá
    ISNULL(e.id_empleado, 0)                            AS id_optometrista,

    -- INTELIGENCIA DE TIEMPO (GMT-4 Venezuela)
    CAST(DATEADD(HOUR, -4, e.fecha_examen) AS DATE)     AS fecha_examen_completa,
    YEAR(DATEADD(HOUR, -4, e.fecha_examen))              AS anio_examen,
    MONTH(DATEADD(HOUR, -4, e.fecha_examen))             AS mes_examen_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, e.fecha_examen)),
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre')
                                                         AS mes_examen_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -4, e.fecha_examen)),
        '-',
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, e.fecha_examen)) AS VARCHAR(2)), 2)
    )                                                    AS periodo_examen

FROM Clinica_Examenes e
WHERE e.fecha_examen >= '2025-01-01';
GO

-- ================================================================
-- 15. Fact_Operaciones_Maestra — Venezuela (SIMPLIFICADA)
--
-- Seguimiento de operaciones y cartera basado en estado_pedido
-- (PAGADO | PENDIENTE), no en logística de laboratorio.
--
-- Nota: Operaciones_Recepciones_Lab está vacía en Venezuela.
-- Campos Dias_Lab, Fecha_Recepcion siempre NULL.
-- Use Semaforo_Meta para estado de cobro (Cobrado | Pendiente de Cobro).
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Fact_Operaciones_Maestra] AS
SELECT
    V.id_pedido                                           AS [ID_Pedido],
    CAST(DATEADD(HOUR, -4, V.fecha_pedido) AS DATE)      AS [Fecha_Pedido],
    V.id_sucursal                                         AS [id_sucursal],
    V.id_cliente                                          AS [ID_Cliente],

    -- Nombre del paciente
    LTRIM(RTRIM(UPPER(
        ISNULL(C.nombre, '') + ' ' + ISNULL(C.apellido, '')
    )))                                                   AS [Paciente],

    -- Receta y material
    O.id_orden_cristal                                    AS [ID_Receta],
    O.codigo_orden                                        AS [Codigo_Sobre],
    ISNULL(O.od_material, 'No Definido')                  AS [Material],
    ISNULL(O.od_tipo_lente, 'No Definido')                AS [Tipo_Lente],
    CAST(ISNULL(O.od_esfera, 0) AS DECIMAL(10,2))         AS [Esfera_OD],
    CAST(ISNULL(O.oi_esfera, 0) AS DECIMAL(10,2))         AS [Esfera_OI],

    -- Datos financieros para Informe 3 Cartera
    V.monto_total                                         AS [Monto_Total],
    V.monto_pagado                                        AS [Monto_Pagado],
    V.saldo_pendiente                                     AS [Saldo_Pendiente],

    -- Estado de cobro (lo importante en Venezuela)
    V.estado_pedido                                       AS [Estado_Pago],
    CASE V.estado_pedido
        WHEN 'PAGADO' THEN 'Cobrado'
        WHEN 'PENDIENTE' THEN 'Pendiente de Cobro'
        ELSE 'Desconocido'
    END                                                   AS [Estatus_Cobro],

    -- Campos que estarán NULL porque no hay datos en Venezuela
    NULL                                                  AS [Fecha_Recepcion],
    NULL                                                  AS [Dias_Lab],

    -- Calendario
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

    -- Semáforo: basado en estado de cobro
    CASE
        WHEN V.estado_pedido = 'PAGADO' THEN 'Cobrado'
        ELSE 'Pendiente de Cobro'
    END                                                   AS [Semaforo_Meta],

    -- Calidad: siempre Dato Operativo Real (sin Fecha_Recepcion)
    'Dato Operativo Real'                                 AS [Calidad_Analisis]

FROM [dbo].[Ventas_Pedidos] V
INNER JOIN [dbo].[Operaciones_Ordenes_Cristales] O ON V.id_pedido = O.id_pedido_venta
LEFT JOIN [dbo].[Maestro_Clientes] C ON V.id_cliente = C.id_cliente
WHERE V.fecha_pedido >= '2025-01-01';
GO


/* ================================================================
   CHECKLIST DE VALIDACIÓN POST-DEPLOY — Venezuela
   Ejecutar en SSMS después de desplegar cada vista:

   -- 1. Dim_Categorias
   SELECT TOP 5 * FROM Dim_Categorias ORDER BY id_categoria;
   -- Esperado: categorías activas, sin nulls en nombre_categoria

   -- 2. Dim_Empleados
   SELECT TOP 5 * FROM Dim_Empleados ORDER BY id_empleado;
   -- Esperado: empleados + registro sistema + venta retail

   -- 3. Dim_Clientes
   SELECT TOP 5 *, fecha_registro_completa FROM Dim_Clientes
   ORDER BY id_cliente DESC;
   -- Verificar: fecha_registro_completa debe ser GMT-4 (Venezuela)

   -- 4. Fact_Ventas
   SELECT TOP 10 id_factura, fecha_factura, monto_total, monto_sin_iva
   FROM Fact_Ventas ORDER BY fecha_factura DESC;
   -- Verificar: monto_sin_iva = monto_total / 1.16 (IVA Venezuela)

   -- 5. Fact_Ventas_Detalle
   SELECT TOP 10 id_factura, id_producto, cantidad, monto_final_transaccional
   FROM Fact_Ventas_Detalle ORDER BY id_factura DESC;
   -- Verificar: filas y montos coinciden con Fact_Ventas

   -- 6. Fact_Ventas_Analitico
   SELECT TOP 10 id_factura, id_producto, nombre_producto, subcategoria_lente, anio_venta, mes_venta_nro
   FROM Fact_Ventas_Analitico
   WHERE YEAR(fecha_factura) = 2025 OR YEAR(fecha_factura) = 2026
   ORDER BY fecha_factura DESC;
   -- Verificar: años correctos, categorías lógicas

   -- 7. Fact_Recaudo
   SELECT periodo, COUNT(*) as cobros, SUM(importe_neto) as total
   FROM Fact_Recaudo
   GROUP BY periodo ORDER BY periodo DESC;
   -- Verificar: periodos recientes de Venezuela

   -- 8. Fact_Pedidos
   SELECT TOP 10 id_pedido, fecha_pedido_completa, id_estado_orden, Estado_Orden_Detalle
   FROM Fact_Pedidos ORDER BY fecha_pedido_completa DESC;
   -- Verificar: id_estado_orden existen en Venezuela + GMT-4

   -- 9. Fact_Inventario
   SELECT TOP 10 id_producto, id_sucursal, cantidad_disponible, estado_stock
   FROM Fact_Inventario ORDER BY id_producto DESC;
   -- Verificar: cantidades realistas, stocks con semáforos

   -- 10. Vista_Notificacion_ETL
   SELECT * FROM Vista_Notificacion_ETL;
   -- Verificar: "Sincronización: DD/MM/YYYY HH:MM AM/PM" + Estado_Salud = OK

   -- 11. Dim_Sucursales
   SELECT id_sucursal, nombre_comercial, estado,
          zona_gerencial, tipo_punto_venta, esta_clasificada
   FROM Dim_Sucursales
   ORDER BY estado, nombre_comercial;
   -- Esperado: 26+ sucursales, estados Venezuela reales,
   -- sin id_sucursal 3 ni 4

   -- 12. Dim_MetodosPago
   SELECT * FROM Dim_MetodosPago ORDER BY tipo_pago_codigo;
   -- Esperado: 11 métodos activos, agrupación por código Gesvision

   -- 13. Dim_Productos Venezuela
   SELECT Segmento_Comercial, Categoria_Padre,
          COUNT(*) as productos,
          AVG(Precio_Venta) as precio_promedio
   FROM Dim_Productos
   GROUP BY Segmento_Comercial, Categoria_Padre
   ORDER BY productos DESC;
   -- Esperado: MONTURAS dominante (118K+),
   -- LENTES DE SOL (24K+), LENTES, LC, ACCESORIOS

   -- 14. Fact_Examenes
   SELECT periodo_examen, COUNT(*) as examenes,
          COUNT(DISTINCT id_sucursal) as sucursales_activas,
          COUNT(DISTINCT id_optometrista) as optometristas
   FROM Fact_Examenes
   GROUP BY periodo_examen
   ORDER BY periodo_examen DESC;
   -- Esperado: periodos 2025-2026, volumen real Venezuela
   -- Sin tipo_examen (no existe en API Gesvision VE)
   -- Sin GHL (no aplica Venezuela)

   -- 15. Fact_Operaciones_Maestra
   SELECT Periodo, Estado_Pago,
          COUNT(DISTINCT ID_Pedido) as pedidos,
          SUM(Monto_Total) as monto_total,
          SUM(Monto_Pagado) as monto_pagado,
          SUM(Saldo_Pendiente) as saldo_pendiente
   FROM Fact_Operaciones_Maestra
   GROUP BY Periodo, Estado_Pago
   ORDER BY Periodo DESC, Estado_Pago;
   -- Esperado: periodos 2025-2026, desglose PAGADO/PENDIENTE
   -- Saldo_Pendiente > 0 en PENDIENTE → datos para Informe 3 Cartera
   -- Sin Dias_Lab (Recepciones_Lab vacía en Venezuela)
   -- Estados de pedido basados en estado_pedido (no logística)

   -- 16. Vista_Notificacion_ETL
   SELECT Notificacion_Texto, Estado_Salud
   FROM Vista_Notificacion_ETL;
   -- Esperado: fecha/hora reciente Venezuela (GMT-4)
   -- Estado_Salud = 'OK' si todos los módulos completaron bien

   ================================================================ */
