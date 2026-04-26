/* ================================================================
   OPTICOLOR BI VENEZUELA — Vistas KPI (Equivalentes DAX)

   Archivo: kpi_venezuela_v1.sql
   Fecha: 26 de Abril de 2026
   Depende de: vistas_venezuela_v1.sql (debe desplegarse primero)

   CONVENCIÓN DE NOMBRES:
   - Dim_Tiempo     → dimensión tiempo dinámica para slicers
   - KPI_Inf1_*     → Informe 1: Resumen Comercial
   - KPI_Inf2_*     → Informe 2: Eficiencia Órdenes
   - KPI_Inf3_*     → Informe 3: Control Cartera
   - KPI_Inf4_*     → Informe 4: Desempeño Clínico
   - KPI_Inf5_*     → Informe 5: Inventario

   IMPORTANTE: Dim_Tiempo es 100% dinámica — se alimenta
   automáticamente de los datos reales cargados por el ETL.
   No tiene fechas hardcodeadas. Cada nuevo registro del ETL
   aparece automáticamente en el slicer sin tocar esta vista.
   ================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ================================================================
-- Dim_Tiempo — Dimensión de tiempo dinámica Venezuela
-- Fuente: fechas reales de tablas transaccionales (no hardcodeada)
-- GMT-4 Venezuela aplicado en todas las fechas
-- Slicer_Mes: 'Mes Actual' por defecto, luego meses anteriores
-- Filtro_Comparativo_Dinamico: año actual y anterior = 1
-- Se actualiza automáticamente con cada carga del ETL
-- ================================================================

CREATE OR ALTER VIEW [dbo].[Dim_Tiempo] AS
WITH Periodos AS (
    SELECT DISTINCT
        CAST(DATEADD(HOUR, -4, fecha_factura) AS DATE) AS fecha
    FROM Ventas_Cabecera
    UNION
    SELECT DISTINCT
        CAST(DATEADD(HOUR, -4, fecha_pedido) AS DATE)
    FROM Ventas_Pedidos
    UNION
    SELECT DISTINCT
        CAST(DATEADD(HOUR, -4, fecha_examen) AS DATE)
    FROM Clinica_Examenes
    UNION
    SELECT DISTINCT
        CAST(DATEADD(HOUR, -4, fecha_cobro) AS DATE)
    FROM Finanzas_Cobros
)
SELECT DISTINCT
    fecha                                                   AS Date,
    YEAR(fecha)                                             AS Anio,
    MONTH(fecha)                                            AS Mes_Nro,
    DAY(fecha)                                              AS Dia,
    FORMAT(fecha, 'MMMM', 'es-VE')                         AS Mes,
    FORMAT(fecha, 'MMM', 'es-VE')                          AS Mes_Corto,
    CONCAT('Q', DATEPART(QUARTER, fecha))                   AS Trimestre,
    FORMAT(fecha, 'yyyy-MM')                                AS Anio_Mes,
    DATEPART(WEEKDAY, fecha)                                AS Dia_Semana,
    FORMAT(fecha, 'dddd', 'es-VE')                         AS Nombre_Dia,
    CASE WHEN DATEPART(WEEKDAY, fecha) IN (1, 7)
        THEN 'Si' ELSE 'No'
    END                                                     AS Es_Fin_Semana,

    -- Fecha relativa vs hoy GMT-4
    CASE
        WHEN fecha = CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE)
            THEN 'Hoy'
        WHEN fecha < CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE)
            THEN 'Pasado'
        ELSE 'Futuro'
    END                                                     AS Fecha_Relativa,

    -- Slicer principal (equivalente al slicer de Power BI)
    -- 'Mes Actual' para el mes en curso, nombre del mes para anteriores
    CASE
        WHEN YEAR(fecha) = YEAR(CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE))
         AND MONTH(fecha) = MONTH(CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE))
            THEN 'Mes Actual'
        ELSE FORMAT(fecha, 'MMMM yyyy', 'es-VE')
    END                                                     AS Slicer_Mes,

    -- Filtro comparativo: 1 si año actual o anterior, 0 si futuros
    CASE
        WHEN YEAR(fecha) IN (
            YEAR(CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE)),
            YEAR(CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE)) - 1
        ) THEN 1
        ELSE 0
    END                                                     AS Filtro_Comparativo_Dinamico

FROM Periodos
WHERE fecha IS NOT NULL;
GO

-- ================================================================
-- CHECKLIST VALIDACIÓN — Dim_Tiempo
-- Ejecutar por separado en SSMS después de compilar:
--
-- SELECT DISTINCT Slicer_Mes, Anio, Mes_Nro
-- FROM Dim_Tiempo
-- ORDER BY Anio DESC, Mes_Nro DESC;
-- Esperado: 'Mes Actual' para abril 2026
-- Meses anteriores en español: 'marzo 2026', 'febrero 2026'
-- Solo meses con datos reales de Venezuela
--
-- SELECT COUNT(DISTINCT Date) as dias_totales,
--        MIN(Date) as primer_dia,
--        MAX(Date) as ultimo_dia
-- FROM Dim_Tiempo;
-- Esperado: días reales desde inicio de operaciones VE
-- ================================================================

-- ================================================================
-- KPI_Inf1_Venta_Bruta — Informe 1: Resumen Comercial
-- Equivalente DAX: CALCULATE(SUM(monto_total), tipo <> "Devolución")
-- Excluye devoluciones — no las resta, las omite del cálculo
-- Granularidad: por factura — Next.js agrega según slicer
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_factura
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Venta_Bruta] AS
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
    ROUND(monto_sin_iva, 2)    AS venta_bruta_sin_iva
FROM Fact_Ventas
WHERE tipo_transaccion = 'Venta';
GO

-- [✅] KPI_Inf1_Venta_Bruta — completada 26/04/2026

/*
SELECT periodo_factura,
       COUNT(*) AS facturas,
       ROUND(SUM(venta_bruta), 2) AS total_venta_bruta,
       ROUND(SUM(venta_bruta_sin_iva), 2) AS total_sin_iva
FROM KPI_Inf1_Venta_Bruta
GROUP BY periodo_factura
ORDER BY periodo_factura DESC;
*/

-- ================================================================
-- KPI_Inf1_Devoluciones — Informe 1: Resumen Comercial
-- Equivalente DAX: ABS(CALCULATE(SUM(monto_total), tipo = "Devolución"))
-- ABS() convierte montos negativos a positivos
-- Granularidad: por factura — Next.js agrega según slicer
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_factura
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Devoluciones] AS
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
    ROUND(ABS(monto_sin_iva), 2)    AS devolucion_sin_iva
FROM Fact_Ventas
WHERE tipo_transaccion = 'Devolución';
GO

-- [✅] KPI_Inf1_Devoluciones — completada 26/04/2026

/*
SELECT fecha_factura,
       COUNT(*) AS devoluciones,
       ROUND(SUM(devolucion), 2) AS total_devolucion,
       ROUND(SUM(devolucion_sin_iva), 2) AS total_sin_iva
FROM KPI_Inf1_Devoluciones
GROUP BY fecha_factura
ORDER BY fecha_factura DESC;
*/

-- ================================================================
-- KPI_Inf1_Venta_Neta — Informe 1: Resumen Comercial
-- Equivalente DAX: Venta Bruta - Devoluciones
-- Incluye ventas (+) y devoluciones (-) en un solo resultado
-- Next.js hace SUM(monto_neto) para obtener la venta neta final
-- Granularidad: por factura
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_factura
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Venta_Neta] AS
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
    -- Ventas suman (+), devoluciones restan (-)
    ROUND(monto_total, 2)      AS monto_neto,
    ROUND(monto_sin_iva, 2)    AS monto_neto_sin_iva
FROM Fact_Ventas;
GO

-- [✅] KPI_Inf1_Venta_Neta — completada 26/04/2026

/*
SELECT periodo_factura,
       ROUND(SUM(monto_neto), 2) AS venta_neta,
       ROUND(SUM(monto_neto_sin_iva), 2) AS venta_neta_sin_iva,
       COUNT(CASE WHEN tipo_transaccion = 'Venta'
             THEN 1 END) AS facturas_venta,
       COUNT(CASE WHEN tipo_transaccion = 'Devolución'
             THEN 1 END) AS facturas_devolucion
FROM KPI_Inf1_Venta_Neta
GROUP BY periodo_factura
ORDER BY periodo_factura DESC;
*/

-- ================================================================
-- KPI_Inf1_Cantidad_Facturas — Informe 1: Resumen Comercial
-- Equivalente DAX: COALESCE(DISTINCTCOUNT(Fact_Ventas[id_factura]), 0)
-- Solo facturas de tipo Venta (excluye devoluciones)
-- Next.js hace COUNT(DISTINCT id_factura) según slicer
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_factura
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Cantidad_Facturas] AS
SELECT
    id_factura,
    id_sucursal,
    id_cliente,
    id_vendedor,
    fecha_factura,
    anio_factura,
    mes_factura_nro,
    mes_factura_nombre,
    periodo_factura
FROM Fact_Ventas
WHERE tipo_transaccion = 'Venta';
GO

-- [✅] KPI_Inf1_Cantidad_Facturas — completada 26/04/2026

/*
SELECT periodo_factura,
       COUNT(DISTINCT id_factura) AS cantidad_facturas,
       COUNT(DISTINCT id_sucursal) AS sucursales_activas,
       COUNT(DISTINCT id_cliente) AS clientes_unicos
FROM KPI_Inf1_Cantidad_Facturas
GROUP BY periodo_factura
ORDER BY periodo_factura DESC;
*/

-- ================================================================
-- KPI_Inf1_Total_Cobrado — Informe 1: Resumen Comercial
-- Equivalente DAX: COALESCE(SUM(Fact_Recaudo[importe_neto]), 0)
-- Fuente: Fact_Recaudo (cobros reales, no ventas)
-- Un pedido puede tener múltiples cobros parciales
-- Next.js hace SUM(importe_neto) según slicer
-- Filtros disponibles: fecha_completa, id_sucursal, periodo
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Total_Cobrado] AS
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
    ROUND(importe_neto, 2)    AS importe_neto
FROM Fact_Recaudo;
GO

-- [✅] KPI_Inf1_Total_Cobrado — completada 26/04/2026

/*
SELECT periodo,
       COUNT(*) AS cobros,
       ROUND(SUM(importe_neto), 2) AS total_cobrado,
       COUNT(DISTINCT id_sucursal) AS sucursales,
       COUNT(DISTINCT metodo_pago) AS metodos_pago
FROM KPI_Inf1_Total_Cobrado
GROUP BY periodo
ORDER BY periodo DESC;
*/

-- ================================================================
-- KPI_Inf1_Mix_Medios_Pago — Informe 1: Resumen Comercial
-- Equivalente DAX: % Mix Medios Pago + Total Recaudado Efectivo
-- Alimenta el donut de Distribución por Medio de Pago
-- Incluye todos los métodos — Next.js filtra por método si necesita
-- Next.js calcula % dividiendo cada método / total período
-- Filtros disponibles: fecha_completa, id_sucursal, periodo,
--   metodo_pago, tipo_recaudo
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Mix_Medios_Pago] AS
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
    ROUND(importe_neto, 2)    AS importe_neto
FROM Fact_Recaudo
WHERE importe_neto > 0;
GO

-- [✅] KPI_Inf1_Mix_Medios_Pago — completada 26/04/2026

/*
SELECT periodo,
       metodo_pago,
       COUNT(*) AS cobros,
       ROUND(SUM(importe_neto), 2) AS total_cobrado,
       ROUND(SUM(importe_neto) * 100.0 /
             SUM(SUM(importe_neto)) OVER(PARTITION BY periodo), 2)
             AS pct_participacion
FROM KPI_Inf1_Mix_Medios_Pago
GROUP BY periodo, metodo_pago
ORDER BY periodo DESC, total_cobrado DESC;
*/

-- ================================================================
-- KPI_Inf1_Proyeccion_Venta_Neta — Informe 1: Resumen Comercial
-- Equivalente DAX: (Venta Neta / Dias_Transcurridos) * Dias_Mes
-- NOTA GMT-4: fechas de Fact_Ventas ya vienen ajustadas
-- Solo GETUTCDATE() requiere DATEADD(HOUR,-4,...) en esta vista
-- Lógica dual en Next.js:
--   Mes pasado → muestra venta_neta real (sin proyectar)
--   Mes actual → calcula proyeccion_cierre
-- Filtros disponibles: periodo_factura, id_sucursal, fecha_factura
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Proyeccion_Venta_Neta] AS
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

    -- dias_del_mes: total días del mes de la factura
    -- fecha_factura ya viene en GMT-4 desde Fact_Ventas — sin ajuste
    DAY(EOMONTH(fecha_factura))                              AS dias_del_mes,

    -- dia_hoy, mes_actual, anio_actual: tiempo real
    -- GETUTCDATE() devuelve UTC — sí necesita ajuste GMT-4
    DAY(CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE))      AS dia_hoy_gmt4,
    MONTH(DATEADD(HOUR, -4, GETUTCDATE()))                   AS mes_actual_gmt4,
    YEAR(DATEADD(HOUR, -4, GETUTCDATE()))                    AS anio_actual_gmt4,

    -- Flag: 1 = mes en curso, 0 = mes pasado
    -- Compara mes/año de la factura (GMT-4) vs hoy (GMT-4)
    CASE
        WHEN mes_factura_nro = MONTH(DATEADD(HOUR, -4, GETUTCDATE()))
         AND anio_factura    = YEAR(DATEADD(HOUR, -4, GETUTCDATE()))
            THEN 1
        ELSE 0
    END                                                      AS es_mes_actual

FROM Fact_Ventas;
GO

-- [✅] KPI_Inf1_Proyeccion_Venta_Neta — completada 26/04/2026

/*
SELECT periodo_factura,
       es_mes_actual,
       dias_del_mes,
       dia_hoy_gmt4,
       ROUND(SUM(monto_neto), 2) AS venta_neta,
       ROUND(SUM(monto_neto) /
             NULLIF(CASE WHEN es_mes_actual = 1
                    THEN dia_hoy_gmt4 - 1
                    ELSE dias_del_mes END, 0)
             * dias_del_mes, 2) AS proyeccion_cierre
FROM KPI_Inf1_Proyeccion_Venta_Neta
GROUP BY periodo_factura, es_mes_actual,
         dias_del_mes, dia_hoy_gmt4
ORDER BY periodo_factura DESC;
*/

-- ================================================================
-- KPI_Inf1_Ticket_Promedio — Informe 1: Resumen Comercial
-- Equivalente DAX: COALESCE(DIVIDE([Venta Neta],[Cantidad Pedidos]),0)
-- Optimizado: CTEs separadas evitan producto cartesiano
-- Venta_Neta y Pedidos se agregan primero, luego se unen
-- Filtros disponibles: periodo, id_sucursal, anio, mes_nro
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Ticket_Promedio] AS
WITH Ventas AS (
    SELECT
        periodo_factura                  AS periodo,
        anio_factura                     AS anio,
        mes_factura_nro                  AS mes_nro,
        mes_factura_nombre               AS mes_nombre,
        id_sucursal,
        ROUND(SUM(monto_total), 2)       AS venta_neta
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
    ISNULL(P.cantidad_pedidos, 0)        AS cantidad_pedidos,
    ROUND(
        CASE
            WHEN ISNULL(P.cantidad_pedidos, 0) = 0 THEN 0
            ELSE V.venta_neta / P.cantidad_pedidos
        END, 2)                          AS ticket_promedio
FROM Ventas V
LEFT JOIN Pedidos P
    ON V.periodo    = P.periodo
    AND V.id_sucursal = P.id_sucursal;
GO

-- [✅] KPI_Inf1_Ticket_Promedio — optimizada 26/04/2026

/*
SELECT periodo,
       id_sucursal,
       venta_neta,
       cantidad_pedidos,
       ticket_promedio
FROM KPI_Inf1_Ticket_Promedio
ORDER BY periodo DESC, ticket_promedio DESC;
*/

-- ================================================================
-- KPI_Inf1_Net_Sales — Informe 1: Resumen Comercial
-- Equivalente DAX: SUM(Fact_Ventas_Analitico[monto_final_transaccional])
-- Fuente: Fact_Ventas_Analitico (detalle líneas con descuentos)
-- Diferente a Venta_Neta: incluye ajustes comerciales por línea
-- Next.js hace SUM(monto_final_transaccional) según slicer
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_venta,
--   subcategoria_lente, nombre_producto
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Net_Sales] AS
SELECT
    id_factura,
    id_linea,
    id_producto,
    id_sucursal,
    nombre_producto,
    nombre_categoria,
    subcategoria_lente,
    cantidad,
    fecha_factura,
    anio_venta,
    mes_venta_nro,
    mes_venta_nombre,
    periodo_venta,
    ROUND(monto_final_transaccional, 2)    AS monto_final_transaccional,
    ROUND(precio_lista_unitario, 2)        AS precio_lista_unitario,
    ROUND(ajuste_comercial_neto, 2)        AS ajuste_comercial_neto
FROM Fact_Ventas_Analitico;
GO

-- [✅] KPI_Inf1_Net_Sales — completada 26/04/2026

/*
SELECT periodo_venta,
       COUNT(DISTINCT id_factura) AS facturas,
       SUM(cantidad) AS unidades,
       ROUND(SUM(monto_final_transaccional), 2) AS net_sales,
       ROUND(SUM(ajuste_comercial_neto), 2) AS total_ajustes
FROM KPI_Inf1_Net_Sales
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
*/

-- ================================================================
-- KPI_Inf1_Venta_Neta_Producto — Informe 1: Resumen Comercial
-- Equivalente DAX: SUM(Fact_Ventas_Detalle[monto_final_transaccional])
-- Fuente: Fact_Ventas_Detalle (líneas de factura sin atributos)
-- Next.js hace SUM(monto_final_transaccional) según slicer
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_venta,
--   id_producto
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Venta_Neta_Producto] AS
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
    ROUND(ajuste_comercial_neto, 2)        AS ajuste_comercial_neto
FROM Fact_Ventas_Detalle;
GO

-- [✅] KPI_Inf1_Venta_Neta_Producto — completada 26/04/2026

/*
SELECT periodo_venta,
       COUNT(DISTINCT id_factura) AS facturas,
       SUM(cantidad) AS unidades,
       ROUND(SUM(monto_final_transaccional), 2) AS venta_neta_producto,
       ROUND(SUM(ajuste_comercial_neto), 2) AS total_ajustes
FROM KPI_Inf1_Venta_Neta_Producto
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
*/

-- ================================================================
-- KPI_Inf1_Venta_Teorica_Lista — Informe 1: Resumen Comercial
-- Equivalente DAX: SUMX(Fact_Ventas_Detalle, cantidad * precio_lista)
-- Valor bruto sin descuentos — precio de lista × unidades
-- Comparar con Net_Sales para medir impacto de descuentos
-- Next.js hace SUM(venta_teorica) según slicer
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_venta,
--   id_producto
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf1_Venta_Teorica_Lista] AS
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
          (cantidad * precio_lista_unitario), 2)           AS descuento_aplicado
FROM Fact_Ventas_Detalle;
GO

-- [✅] KPI_Inf1_Venta_Teorica_Lista — completada 26/04/2026

/*
SELECT periodo_venta,
       SUM(cantidad) AS unidades,
       ROUND(SUM(venta_teorica_lista), 2) AS venta_teorica,
       ROUND(SUM(monto_final_transaccional), 2) AS venta_real,
       ROUND(SUM(descuento_aplicado), 2) AS total_descuentos,
       ROUND(SUM(descuento_aplicado) * 100.0 /
             NULLIF(SUM(venta_teorica_lista), 0), 2) AS pct_descuento
FROM KPI_Inf1_Venta_Teorica_Lista
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
*/

-- ================================================================
-- KPI_Inf3_Monto_Pedidos — Informe 3: Control Cartera
-- Equivalente DAX: COALESCE(SUM(Fact_Pedidos[monto_total]), 0)
-- Fuente: Fact_Pedidos Venezuela (columnas validadas 26/04/2026)
-- Next.js hace SUM(monto_total) según slicer
-- Filtros disponibles: fecha_pedido_completa, id_sucursal,
--   periodo_pedido, estado_pago_interno, id_cliente
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf3_Monto_Pedidos] AS
SELECT
    id_pedido,
    numero_pedido,
    id_sucursal,
    id_cliente,
    id_asesor,
    estado_pago_interno,
    id_estado_orden,
    Estado_Orden_Detalle,
    fecha_pedido_completa,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    periodo_pedido,
    ROUND(monto_total, 2)        AS monto_total,
    ROUND(monto_pagado, 2)       AS monto_pagado,
    ROUND(saldo_pendiente, 2)    AS saldo_pendiente
FROM Fact_Pedidos;
GO

-- [✅] KPI_Inf3_Monto_Pedidos — completada 26/04/2026

/*
SELECT periodo_pedido,
       estado_pago_interno,
       COUNT(DISTINCT id_pedido) AS pedidos,
       ROUND(SUM(monto_total), 2) AS monto_total,
       ROUND(SUM(monto_pagado), 2) AS monto_pagado,
       ROUND(SUM(saldo_pendiente), 2) AS saldo_pendiente
FROM KPI_Inf3_Monto_Pedidos
GROUP BY periodo_pedido, estado_pago_interno
ORDER BY periodo_pedido DESC;
*/

-- ================================================================
-- KPI_Inf3_Saldo_Pendiente — Informe 3: Control Cartera
-- Equivalente DAX: COALESCE(SUM(Fact_Pedidos[saldo_pendiente]), 0)
-- Solo pedidos con saldo_pendiente > 0 (deuda real con el cliente)
-- Next.js hace SUM(saldo_pendiente) según slicer
-- Filtros disponibles: fecha_pedido_completa, id_sucursal,
--   periodo_pedido, id_cliente
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf3_Saldo_Pendiente] AS
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
    ROUND(saldo_pendiente, 2)    AS saldo_pendiente
FROM Fact_Pedidos
WHERE saldo_pendiente > 0;
GO

-- [✅] KPI_Inf3_Saldo_Pendiente — completada 26/04/2026

/*
SELECT periodo_pedido,
       COUNT(DISTINCT id_pedido) AS pedidos_con_saldo,
       COUNT(DISTINCT id_cliente) AS clientes_con_deuda,
       ROUND(SUM(saldo_pendiente), 2) AS total_saldo_pendiente,
       ROUND(AVG(saldo_pendiente), 2) AS promedio_saldo
FROM KPI_Inf3_Saldo_Pendiente
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
*/

-- ================================================================
-- KPI_Inf3_Recaudado_Pedidos — Informe 3: Control Cartera
-- Equivalente DAX: COALESCE(SUM(Fact_Pedidos[monto_pagado]), 0)
-- Suma lo pagado por el cliente en cada pedido
-- Incluye abonos parciales + pagos completos
-- Next.js hace SUM(monto_pagado) según slicer
-- Filtros disponibles: fecha_pedido_completa, id_sucursal,
--   periodo_pedido, estado_pago_interno, id_cliente
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf3_Recaudado_Pedidos] AS
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
    ROUND(saldo_pendiente, 2)    AS saldo_pendiente
FROM Fact_Pedidos
WHERE monto_pagado > 0;
GO

-- [✅] KPI_Inf3_Recaudado_Pedidos — completada 26/04/2026

/*
SELECT periodo_pedido,
       estado_pago_interno,
       COUNT(DISTINCT id_pedido) AS pedidos,
       ROUND(SUM(monto_pagado), 2) AS total_recaudado,
       ROUND(SUM(monto_total), 2) AS total_pedidos,
       ROUND(SUM(monto_pagado) * 100.0 /
             NULLIF(SUM(monto_total), 0), 2) AS pct_recaudado
FROM KPI_Inf3_Recaudado_Pedidos
GROUP BY periodo_pedido, estado_pago_interno
ORDER BY periodo_pedido DESC;
*/

-- ================================================================
-- KPI_Inf3_Pct_Cobro_Inmediato — Informe 3: Control Cartera
-- Equivalente DAX: DIVIDE(PedidosPagadosFull, TotalPedidos, 0)
-- Adaptación VE: saldo_pendiente <= 0 (incluye sobrepagos)
-- Fórmula: pedidos_cobrados / total_pedidos * 100
-- Next.js calcula DIVIDE según slicer seleccionado
-- Filtros disponibles: periodo_pedido, id_sucursal, anio_pedido
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf3_Pct_Cobro_Inmediato] AS
SELECT
    periodo_pedido,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    id_sucursal,
    COUNT(DISTINCT id_pedido)                               AS total_pedidos,
    COUNT(DISTINCT CASE WHEN saldo_pendiente <= 0
          THEN id_pedido END)                               AS pedidos_cobrados,
    ROUND(
        COUNT(DISTINCT CASE WHEN saldo_pendiente <= 0
              THEN id_pedido END) * 100.0 /
        NULLIF(COUNT(DISTINCT id_pedido), 0)
    , 2)                                                    AS pct_cobro_inmediato
FROM Fact_Pedidos
GROUP BY periodo_pedido, anio_pedido,
         mes_pedido_nro, mes_pedido_nombre,
         id_sucursal;
GO

-- [✅] KPI_Inf3_Pct_Cobro_Inmediato — completada 26/04/2026

/*
SELECT periodo_pedido,
       SUM(total_pedidos) AS total_pedidos,
       SUM(pedidos_cobrados) AS pedidos_cobrados,
       ROUND(SUM(pedidos_cobrados) * 100.0 /
             NULLIF(SUM(total_pedidos), 0), 2) AS pct_cobro_inmediato
FROM KPI_Inf3_Pct_Cobro_Inmediato
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
*/

-- ================================================================
-- KPI_Inf3_Pct_Nivel_Abono — Informe 3: Control Cartera
-- Equivalente DAX: COALESCE(DIVIDE([Recaudado],[Monto Pedidos]),0)
-- Fórmula: SUM(monto_pagado) / SUM(monto_total) * 100
-- Mide % del valor cobrado vs valor total de pedidos
-- Next.js calcula DIVIDE según slicer seleccionado
-- Filtros disponibles: periodo_pedido, id_sucursal, anio_pedido
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf3_Pct_Nivel_Abono] AS
SELECT
    periodo_pedido,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    id_sucursal,
    ROUND(SUM(monto_total), 2)                              AS monto_total,
    ROUND(SUM(monto_pagado), 2)                             AS monto_pagado,
    ROUND(SUM(saldo_pendiente), 2)                          AS saldo_pendiente,
    ROUND(
        SUM(monto_pagado) * 100.0 /
        NULLIF(SUM(monto_total), 0)
    , 2)                                                    AS pct_nivel_abono
FROM Fact_Pedidos
GROUP BY periodo_pedido, anio_pedido,
         mes_pedido_nro, mes_pedido_nombre,
         id_sucursal;
GO

-- [✅] KPI_Inf3_Pct_Nivel_Abono — completada 26/04/2026

/*
SELECT periodo_pedido,
       ROUND(SUM(monto_total), 2) AS monto_total,
       ROUND(SUM(monto_pagado), 2) AS monto_pagado,
       ROUND(SUM(saldo_pendiente), 2) AS saldo_pendiente,
       ROUND(SUM(monto_pagado) * 100.0 /
             NULLIF(SUM(monto_total), 0), 2) AS pct_nivel_abono
FROM KPI_Inf3_Pct_Nivel_Abono
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
*/

-- ================================================================
-- KPI_Inf3_Pedidos_Liquidar — Informe 3: Control Cartera
-- Equivalente DAX: DISTINCTCOUNT(id_pedido) WHERE saldo > 0
-- Pedidos con deuda real pendiente de cobro
-- Next.js hace COUNT según slicer seleccionado
-- Filtros disponibles: periodo_pedido, id_sucursal, id_cliente
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf3_Pedidos_Liquidar] AS
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
    ROUND(saldo_pendiente, 2)    AS saldo_pendiente
FROM Fact_Pedidos
WHERE saldo_pendiente > 0;
GO

-- [✅] KPI_Inf3_Pedidos_Liquidar — completada 26/04/2026

/*
SELECT periodo_pedido,
       COUNT(DISTINCT id_pedido) AS pedidos_por_liquidar,
       COUNT(DISTINCT id_cliente) AS clientes_con_deuda,
       ROUND(SUM(saldo_pendiente), 2) AS total_por_cobrar,
       ROUND(AVG(saldo_pendiente), 2) AS promedio_deuda
FROM KPI_Inf3_Pedidos_Liquidar
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
*/

-- ================================================================
-- KPI_Inf4_Total_Examenes — Informe 4: Desempeño Clínico
-- Equivalente DAX: COALESCE(COUNTROWS(Fact_Examenes), 0)
-- Venezuela: exámenes desde enero 2026 (sin histórico previo)
-- Next.js hace COUNT(id_examen) según slicer
-- Filtros disponibles: fecha_examen_completa, id_sucursal,
--   periodo_examen, id_optometrista
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf4_Total_Examenes] AS
SELECT
    id_examen,
    id_cliente,
    id_sucursal,
    id_optometrista,
    fecha_examen_completa,
    anio_examen,
    mes_examen_nro,
    mes_examen_nombre,
    periodo_examen
FROM Fact_Examenes;
GO

-- [✅] KPI_Inf4_Total_Examenes — completada 26/04/2026

/*
SELECT periodo_examen,
       COUNT(id_examen) AS total_examenes,
       COUNT(DISTINCT id_sucursal) AS sucursales_activas,
       COUNT(DISTINCT id_optometrista) AS optometristas_activos,
       COUNT(DISTINCT id_cliente) AS pacientes_unicos
FROM KPI_Inf4_Total_Examenes
GROUP BY periodo_examen
ORDER BY periodo_examen DESC;
*/

-- ================================================================
-- KPI_Inf4_Cantidad_Pedidos — Informe 4: Desempeño Clínico
-- Equivalente DAX: DISTINCTCOUNT(Fact_Pedidos[id_pedido])
-- Se combina con KPI_Inf4_Total_Examenes para % Cierre General
-- Next.js hace COUNT(DISTINCT id_pedido) según slicer
-- Filtros disponibles: fecha_pedido_completa, id_sucursal,
--   periodo_pedido, id_cliente
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf4_Cantidad_Pedidos] AS
SELECT
    id_pedido,
    id_sucursal,
    id_cliente,
    id_asesor,
    fecha_pedido_completa,
    anio_pedido,
    mes_pedido_nro,
    mes_pedido_nombre,
    periodo_pedido
FROM Fact_Pedidos;
GO

-- [✅] KPI_Inf4_Cantidad_Pedidos — completada 26/04/2026

/*
SELECT periodo_pedido,
       COUNT(DISTINCT id_pedido) AS cantidad_pedidos,
       COUNT(DISTINCT id_sucursal) AS sucursales_activas,
       COUNT(DISTINCT id_cliente) AS clientes_unicos
FROM KPI_Inf4_Cantidad_Pedidos
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
*/

-- ================================================================
-- KPI_Inf4_Pct_Cierre_General — Informe 4: Desempeño Clínico
-- Equivalente DAX: DIVIDE([Total Pedidos],[Total Exámenes],0)
-- Venezuela: examen no obligatorio → puede superar 100%
-- Interpretación: % de exámenes que generaron pedido en el período
-- Optimizado con CTEs para evitar producto cartesiano
-- Filtros disponibles: periodo, id_sucursal
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf4_Pct_Cierre_General] AS
WITH Pedidos AS (
    SELECT
        periodo_pedido          AS periodo,
        anio_pedido             AS anio,
        mes_pedido_nro          AS mes_nro,
        mes_pedido_nombre       AS mes_nombre,
        id_sucursal,
        COUNT(DISTINCT id_pedido) AS cantidad_pedidos
    FROM Fact_Pedidos
    GROUP BY periodo_pedido, anio_pedido,
             mes_pedido_nro, mes_pedido_nombre,
             id_sucursal
),
Examenes AS (
    SELECT
        periodo_examen          AS periodo,
        id_sucursal,
        COUNT(id_examen)        AS total_examenes
    FROM Fact_Examenes
    GROUP BY periodo_examen, id_sucursal
)
SELECT
    P.periodo,
    P.anio,
    P.mes_nro,
    P.mes_nombre,
    P.id_sucursal,
    P.cantidad_pedidos,
    ISNULL(E.total_examenes, 0)          AS total_examenes,
    ROUND(
        P.cantidad_pedidos * 100.0 /
        NULLIF(ISNULL(E.total_examenes, 0), 0)
    , 2)                                 AS pct_cierre_general
FROM Pedidos P
LEFT JOIN Examenes E
    ON P.periodo    = E.periodo
    AND P.id_sucursal = E.id_sucursal;
GO

-- [✅] KPI_Inf4_Pct_Cierre_General — completada 26/04/2026

/*
SELECT periodo,
       SUM(cantidad_pedidos) AS pedidos,
       SUM(total_examenes) AS examenes,
       ROUND(SUM(cantidad_pedidos) * 100.0 /
             NULLIF(SUM(total_examenes), 0), 2) AS pct_cierre_general
FROM KPI_Inf4_Pct_Cierre_General
GROUP BY periodo
ORDER BY periodo DESC;
*/

-- ================================================================
-- KPI_Inf5_Stock_Fisico — Informe 5: Inventario
-- Equivalente DAX: SUMX(Dim_Productos × Fact_Inventario,
--                       cantidad_disponible)
-- Granularidad: por producto y sucursal
-- Next.js hace SUM(cantidad_disponible) según slicer
-- Filtros disponibles: id_sucursal, id_producto, estado_stock,
--   fecha_movimiento_stock, Segmento_Comercial, Marca
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf5_Stock_Fisico] AS
SELECT
    I.id_producto,
    I.id_sucursal,
    I.cantidad_disponible,
    I.estado_stock,
    I.calidad_costo,
    I.fecha_movimiento_stock,
    ROUND(I.costo_unitario, 2)           AS costo_unitario,
    ROUND(I.valor_total_inventario, 2)   AS valor_total_inventario,

    -- Atributos del producto desde Dim_Productos
    P.nombre_producto,
    P.Marca,
    P.Categoria,
    P.Categoria_Padre,
    P.Segmento_Comercial,
    P.Genero,
    P.Material,
    P.Tipo_Montura,
    ROUND(P.Precio_Venta, 2)             AS precio_venta
FROM Fact_Inventario I
LEFT JOIN Dim_Productos P
    ON I.id_producto = P.SK_Producto;
GO

-- [✅] KPI_Inf5_Stock_Fisico — completada 26/04/2026

/*
SELECT Segmento_Comercial,
       COUNT(DISTINCT id_producto) AS productos,
       COUNT(DISTINCT id_sucursal) AS sucursales,
       SUM(cantidad_disponible) AS stock_total,
       ROUND(SUM(valor_total_inventario), 2) AS valor_inventario
FROM KPI_Inf5_Stock_Fisico
GROUP BY Segmento_Comercial
ORDER BY stock_total DESC;
*/

-- ================================================================
-- KPI_Inf5_Capital_Invertido — Informe 5: Inventario
-- Equivalente DAX: COALESCE(SUM(Fact_Inventario[valor_total_inventario]),0)
-- Valor total del inventario al costo
-- Next.js hace SUM(valor_total_inventario) según slicer
-- Filtros disponibles: id_sucursal, id_producto, estado_stock,
--   fecha_movimiento_stock
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf5_Capital_Invertido] AS
SELECT
    id_producto,
    id_sucursal,
    cantidad_disponible,
    estado_stock,
    calidad_costo,
    fecha_movimiento_stock,
    ROUND(costo_unitario, 2)           AS costo_unitario,
    ROUND(valor_total_inventario, 2)   AS valor_total_inventario
FROM Fact_Inventario
WHERE valor_total_inventario > 0;
GO

-- [✅] KPI_Inf5_Capital_Invertido — completada 26/04/2026

/*
SELECT COUNT(DISTINCT id_producto) AS productos,
       COUNT(DISTINCT id_sucursal) AS sucursales,
       SUM(cantidad_disponible) AS stock_total,
       ROUND(SUM(valor_total_inventario), 2) AS capital_invertido,
       ROUND(AVG(costo_unitario), 2) AS costo_promedio
FROM KPI_Inf5_Capital_Invertido;
*/

-- ================================================================
-- KPI_Inf5_Unidades_Vendidas — Informe 5: Inventario
-- Equivalente DAX: COALESCE(SUM(Fact_Ventas_Detalle[cantidad]), 0)
-- Cuenta unidades físicas vendidas por línea de factura
-- Next.js hace SUM(cantidad) según slicer
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_venta,
--   id_producto, subcategoria_lente
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf5_Unidades_Vendidas] AS
SELECT
    id_factura,
    id_linea,
    id_producto,
    id_sucursal,
    fecha_factura,
    anio_venta,
    mes_venta_nro,
    mes_venta_nombre,
    periodo_venta,
    cantidad,
    ROUND(precio_lista_unitario, 2)      AS precio_lista_unitario,
    ROUND(monto_final_transaccional, 2)  AS monto_final_transaccional
FROM Fact_Ventas_Detalle;
GO

-- [✅] KPI_Inf5_Unidades_Vendidas — completada 26/04/2026

/*
SELECT periodo_venta,
       COUNT(DISTINCT id_factura) AS facturas,
       SUM(cantidad) AS unidades_vendidas,
       COUNT(DISTINCT id_producto) AS productos_distintos,
       COUNT(DISTINCT id_sucursal) AS sucursales_activas
FROM KPI_Inf5_Unidades_Vendidas
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
*/

-- ================================================================
-- KPI_Inf5_UPT — Informe 5: Inventario
-- Equivalente DAX: COALESCE(DIVIDE([Unidades],[Facturas],0),0)
-- Promedio de unidades por factura (ticket)
-- Optimizado con CTEs — sin producto cartesiano
-- Next.js calcula DIVIDE(unidades, facturas) según slicer
-- Filtros disponibles: periodo_venta, id_sucursal, anio_venta
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf5_UPT] AS
WITH Unidades AS (
    SELECT
        periodo_venta,
        anio_venta,
        mes_venta_nro,
        mes_venta_nombre,
        id_sucursal,
        SUM(cantidad)                   AS unidades_vendidas
    FROM Fact_Ventas_Detalle
    GROUP BY periodo_venta, anio_venta,
             mes_venta_nro, mes_venta_nombre,
             id_sucursal
),
Facturas AS (
    SELECT
        periodo_factura                 AS periodo_venta,
        id_sucursal,
        COUNT(DISTINCT id_factura)      AS cantidad_facturas
    FROM Fact_Ventas
    WHERE tipo_transaccion = 'Venta'
    GROUP BY periodo_factura, id_sucursal
)
SELECT
    U.periodo_venta,
    U.anio_venta,
    U.mes_venta_nro,
    U.mes_venta_nombre,
    U.id_sucursal,
    U.unidades_vendidas,
    ISNULL(F.cantidad_facturas, 0)      AS cantidad_facturas,
    ROUND(
        U.unidades_vendidas * 1.0 /
        NULLIF(ISNULL(F.cantidad_facturas, 0), 0)
    , 2)                                AS upt
FROM Unidades U
LEFT JOIN Facturas F
    ON U.periodo_venta  = F.periodo_venta
    AND U.id_sucursal   = F.id_sucursal;
GO

-- [✅] KPI_Inf5_UPT — completada 26/04/2026

/*
SELECT periodo_venta,
       SUM(unidades_vendidas) AS unidades,
       SUM(cantidad_facturas) AS facturas,
       ROUND(SUM(unidades_vendidas) * 1.0 /
             NULLIF(SUM(cantidad_facturas), 0), 2) AS upt
FROM KPI_Inf5_UPT
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
*/

-- ================================================================
-- KPI_Inf5_ASP — Informe 5: Inventario
-- Equivalente DAX: COALESCE(DIVIDE([Venta Neta Producto],[Unidades],0),0)
-- Precio promedio por unidad vendida (Average Selling Price)
-- Optimizado con CTEs — sin producto cartesiano
-- Next.js calcula DIVIDE(venta_neta, unidades) según slicer
-- Filtros disponibles: periodo_venta, id_sucursal, anio_venta
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf5_ASP] AS
WITH VentaNeta AS (
    SELECT
        periodo_venta,
        anio_venta,
        mes_venta_nro,
        mes_venta_nombre,
        id_sucursal,
        ROUND(SUM(monto_final_transaccional), 2)  AS venta_neta_producto
    FROM Fact_Ventas_Detalle
    GROUP BY periodo_venta, anio_venta,
             mes_venta_nro, mes_venta_nombre,
             id_sucursal
),
Unidades AS (
    SELECT
        periodo_venta,
        id_sucursal,
        SUM(cantidad)                             AS unidades_vendidas
    FROM Fact_Ventas_Detalle
    GROUP BY periodo_venta, id_sucursal
)
SELECT
    V.periodo_venta,
    V.anio_venta,
    V.mes_venta_nro,
    V.mes_venta_nombre,
    V.id_sucursal,
    V.venta_neta_producto,
    ISNULL(U.unidades_vendidas, 0)               AS unidades_vendidas,
    ROUND(
        V.venta_neta_producto /
        NULLIF(ISNULL(U.unidades_vendidas, 0), 0)
    , 2)                                          AS asp
FROM VentaNeta V
LEFT JOIN Unidades U
    ON V.periodo_venta  = U.periodo_venta
    AND V.id_sucursal   = U.id_sucursal;
GO

-- [✅] KPI_Inf5_ASP — completada 26/04/2026

/*
SELECT periodo_venta,
       ROUND(SUM(venta_neta_producto), 2) AS venta_neta,
       SUM(unidades_vendidas) AS unidades,
       ROUND(SUM(venta_neta_producto) /
             NULLIF(SUM(unidades_vendidas), 0), 2) AS asp
FROM KPI_Inf5_ASP
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
*/

-- ================================================================
-- KPI_Inf5_Volumen_Unidades — Informe 5: Inventario
-- Equivalente DAX: SUM(Fact_Ventas_Analitico[cantidad])
-- OPTIMIZADO: sin subcategoria_lente — usa nombre_categoria directo
-- Elimina LIKE masivo contra nombre_producto (causa de lentitud)
-- Power BI agrupa categorías con DAX si necesita clasificación
-- Filtros disponibles: fecha_factura, id_sucursal, periodo_venta,
--   nombre_categoria, id_categoria
-- ================================================================

CREATE OR ALTER VIEW [dbo].[KPI_Inf5_Volumen_Unidades] AS
SELECT
    D.id_factura,
    D.id_linea,
    D.id_producto,
    V.id_sucursal,
    P.nombre_producto,
    P.id_categoria,
    C.nombre_categoria,
    D.cantidad,
    CAST(DATEADD(HOUR, -4, V.fecha_factura) AS DATE)  AS fecha_factura,
    YEAR(DATEADD(HOUR, -4, V.fecha_factura))           AS anio_venta,
    MONTH(DATEADD(HOUR, -4, V.fecha_factura))          AS mes_venta_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, V.fecha_factura)),
        'Enero','Febrero','Marzo','Abril','Mayo','Junio',
        'Julio','Agosto','Septiembre','Octubre',
        'Noviembre','Diciembre')                       AS mes_venta_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, V.fecha_factura)),
        '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4,
        V.fecha_factura)) AS VARCHAR(2)), 2))          AS periodo_venta,
    ROUND(D.total_linea, 2)                            AS monto_final_transaccional
FROM Ventas_Detalle D
INNER JOIN Ventas_Cabecera V
    ON D.id_factura = V.id_factura
INNER JOIN Maestro_Productos P
    ON D.id_producto = P.id_producto
INNER JOIN Maestro_Categorias C
    ON P.id_categoria = C.id_categoria
WHERE V.fecha_factura >= '2025-01-01';
GO

-- [✅] KPI_Inf5_Volumen_Unidades — optimizada 26/04/2026

/*
SET STATISTICS TIME ON;
SELECT periodo_venta,
       nombre_categoria,
       SUM(cantidad) AS volumen_unidades,
       ROUND(SUM(monto_final_transaccional), 2) AS venta_neta,
       COUNT(DISTINCT id_sucursal) AS sucursales
FROM KPI_Inf5_Volumen_Unidades
GROUP BY periodo_venta, nombre_categoria
ORDER BY periodo_venta DESC, volumen_unidades DESC;
SET STATISTICS TIME OFF;
*/

-- ================================================================
-- Color Alerta ETL — Documentación Power BI y Next.js
-- NO requiere vista SQL — consume Vista_Notificacion_ETL directo
-- ================================================================
--
-- POWER BI (DAX — mantener exactamente así):
--
-- Color Alerta ETL =
-- IF(
--     SELECTEDVALUE(Vista_Notificacion_ETL[Estado_Salud]) = "OK",
--     "#2C3E50",       -- Azul corporativo = OK
--     IF(
--         SELECTEDVALUE(Vista_Notificacion_ETL[Estado_Salud]) = "EN PROCESO",
--         "#F39C12",   -- Amarillo = EN PROCESO
--         "#AD0024"    -- Rojo granate = ERROR
--     )
-- )
--
-- NEXT.JS (TypeScript — API route /api/etl/status):
--
-- const COLOR_MAP = {
--   'OK':         '#2C3E50',
--   'EN PROCESO': '#F39C12',
--   'ERROR':      '#AD0024'
-- }
-- const color = COLOR_MAP[data.Estado_Salud] ?? '#AD0024'
--
-- FUENTE: SELECT * FROM Vista_Notificacion_ETL
-- CAMPOS: Notificacion_Texto, Estado_Salud,
--         modulos_completados, modulos_en_proceso, modulos_con_error
-- ================================================================

-- [✅] Color_Alerta_ETL — documentado 26/04/2026
