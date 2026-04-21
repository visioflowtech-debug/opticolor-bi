-- ================================================================
-- OPTI-COLOR VENEZUELA - SCRIPT DE VISTAS
-- Origen: Optilux Panamá (Adaptado para Venezuela)
-- Fecha: 20/04/2026
-- ================================================================
-- CAMBIOS APLICADOS:
-- 1. ELIMINADAS: Fact_Zoho_Gastos, Fact_Embudo_Marketing, Dim_GHL_Sucursales_Link
-- 2. MODIFICADAS: GMT-5 → GMT-4 (Venezuela)
-- 3. MODIFICADAS: IVA 7% → 16% (donde aplica)
-- 4. SIMPLIFICADA: Fact_Examenes (sin dependencia GHL)
-- ================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ================================================================
-- TABLA AUXILIAR: Parámetros Geografía Venezuela
-- ================================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Param_Venezuela_Geografia]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[Param_Venezuela_Geografia] (
        id_param INT PRIMARY KEY IDENTITY(1,1),
        estado VARCHAR(100) NOT NULL,
        municipio VARCHAR(100),
        latitud DECIMAL(10,8),
        longitud DECIMAL(11,8),
        UNIQUE(estado, municipio)
    );
END
GO

-- ================================================================
-- VISTA 1: Dim_Sucursales (AJUSTADA PARA VENEZUELA - Sin hardcoding)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Sucursales] AS
SELECT 
    S.id_sucursal,
    UPPER(S.nombre_sucursal) AS nombre_sucursal,
    UPPER(ISNULL(S.alias_sucursal, S.nombre_sucursal)) AS nombre_comercial,
    
    -- Geografía: Usar tabla de parámetros Venezuela
    ISNULL(G.estado, 'POR CLASIFICAR') AS provincia,
    ISNULL(G.municipio, 'POR CLASIFICAR') AS municipio,
    
    -- Coordenadas: Usar datos del maestro de sucursales
    ISNULL(S.latitud, G.latitud) AS latitud,
    ISNULL(S.longitud, G.longitud) AS longitud,
    
    S.direccion_raw AS direccion_exacta,
    
    CASE 
        WHEN S.nombre_sucursal LIKE '%Mall%' OR S.nombre_sucursal LIKE '%Multi%' THEN 'Centro Comercial'
        ELSE 'Sucursal Calle'
    END AS tipo_punto_venta

FROM [dbo].[Maestro_Sucursales] S
LEFT JOIN [dbo].[Param_Venezuela_Geografia] G 
    ON UPPER(ISNULL(S.estado_raw, '')) = UPPER(G.estado);
GO

-- ================================================================
-- VISTA 2: Dim_Sucursales_Limpia
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Sucursales_Limpia] AS
SELECT 
    id_sucursal,
    nombre_comercial AS [Nombre_Sucursal],
    provincia AS [Estado],
    municipio AS [Municipio],
    latitud,
    longitud
FROM [dbo].[Dim_Sucursales];
GO

-- ================================================================
-- VISTA 3: Dim_Categorias
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Categorias] AS
SELECT 
    id_categoria,
    UPPER(nombre_categoria) AS nombre_categoria,
    CASE 
        WHEN id_categoria_padre = 1 OR id_categoria_padre IS NULL THEN 'CATEGORIA PRINCIPAL'
        ELSE 'SUBCATEGORIA'
    END AS nivel_jerarquia,
    CASE 
        WHEN nombre_categoria LIKE '%LENTE%' THEN 'LENTICULAR'
        WHEN nombre_categoria LIKE '%ARO%' THEN 'MONTURAS'
        WHEN nombre_categoria LIKE '%SOLUCIONES%' OR nombre_categoria LIKE '%ACCESORIOS%' THEN 'SUMINISTROS'
        ELSE 'OTROS'
    END AS linea_negocio
FROM [dbo].[Maestro_Categorias]
WHERE esta_activo = 1;
GO

-- ================================================================
-- VISTA 4: Dim_Clientes
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Clientes] AS
SELECT 
    id_cliente,
    LTRIM(RTRIM(UPPER(ISNULL(nombre, '') + ' ' + ISNULL(apellido, '')))) AS nombre_completo,
    CASE 
        WHEN genero = 'H' THEN 'MASCULINO'
        WHEN genero = 'M' THEN 'FEMENINO'
        ELSE 'NO DEFINIDO (PENDIENTE)'
    END AS genero_label, 
    
    ISNULL(DATEDIFF(YEAR, fecha_nacimiento, GETDATE()), 0) AS edad, 
    
    CASE 
        WHEN fecha_nacimiento IS NULL OR DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) <= 0 THEN 'No Indicado'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 1 AND 18 THEN '01 a 18'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 19 AND 30 THEN '19 a 30'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 31 AND 40 THEN '31 a 40'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 41 AND 50 THEN '41 a 50'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 51 AND 100 THEN '51 a 100'
        ELSE 'Mayor de 100'
    END AS rango_edad_descripcion, 
    
    UPPER(ISNULL(ciudad, 'DESCONOCIDO')) AS distrito_residencia,
    email,
    
    -- Ajuste a GMT-4 para Venezuela
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

FROM [dbo].[Maestro_Clientes];
GO

-- ================================================================
-- VISTA 5: Fact_Pedidos (AJUSTADA GMT-4)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Pedidos] AS
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

    -- Ajuste a GMT-4 para Venezuela
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
FROM [dbo].[Ventas_Pedidos]
WHERE fecha_pedido >= '2025-01-01';
GO

-- ================================================================
-- VISTA 6: Fact_Ventas_Por_Motivo (AJUSTADA GMT-4)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Ventas_Por_Motivo] AS
WITH AgendaLimpia AS (
    SELECT 
        id_cliente,
        UPPER(detalles_cita) AS nota_raw,
        CASE 
            WHEN detalles_cita LIKE '%REDES%' OR detalles_cita LIKE '%INSTA%' OR detalles_cita LIKE '%FACE%' 
                 OR detalles_cita LIKE '%TIK%' OR detalles_cita LIKE '%GOOGLE%' THEN 'REDES SOCIALES'
            WHEN detalles_cita LIKE '%LETRE%' OR detalles_cita LIKE '%VALLA%' OR detalles_cita LIKE '%PLAZA%' 
                 THEN 'LETRERO'
            WHEN detalles_cita LIKE '%REFER%' OR detalles_cita LIKE '%AMIG%' OR detalles_cita LIKE '%FAMILI%' 
                 OR detalles_cita LIKE '%RECOMEN%' THEN 'REFERIDOS'
            WHEN detalles_cita LIKE '%VOLANT%' THEN 'VOLANTEO'
            WHEN detalles_cita LIKE '%KREDI%' THEN 'KREDIYA'
            WHEN detalles_cita LIKE '%EMPRES%' OR detalles_cita LIKE '%CONVEN%' OR detalles_cita LIKE '%BANCO%' 
                 OR detalles_cita LIKE '%LICITA%' THEN 'CONVENIOS'
            ELSE 'OTROS / LLEGADA DIRECTA'
        END AS motivo_real,
        ROW_NUMBER() OVER(PARTITION BY id_cliente ORDER BY fecha_creacion_cita DESC) as rnk
    FROM [dbo].[Marketing_Citas]
    WHERE detalles_cita IS NOT NULL AND detalles_cita <> ''
)
SELECT 
    P.id_pedido,
    P.id_cliente,
    P.monto_total,
    P.fecha_pedido_completa AS fecha,
    ISNULL(A.motivo_real, 'OTROS / LLEGADA DIRECTA') AS motivo_visita,
    ISNULL(A.nota_raw, 'SIN NOTA EN AGENDA') AS nota_auditoria
FROM [dbo].[Fact_Pedidos] P
LEFT JOIN AgendaLimpia A ON P.id_cliente = A.id_cliente AND A.rnk = 1
WHERE P.anio_pedido = 2026;
GO

-- ================================================================
-- VISTA 7: Fact_Examenes (SIMPLIFICADA - Sin GHL)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Examenes] AS
SELECT 
    e.id_examen,
    e.id_cliente,
    e.id_sucursal,
    e.id_empleado AS id_optometrista,
    
    UPPER(ISNULL(e.examType, 'GENERAL')) AS tipo_examen,
    UPPER(ISNULL(e.observaciones, 'SIN OBSERVACIONES')) AS notas_clinicas,

    -- Ajuste a GMT-4 para Venezuela
    CAST(DATEADD(HOUR, -4, e.fecha_examen) AS DATE) AS fecha_examen_completa,
    YEAR(DATEADD(HOUR, -4, e.fecha_examen)) AS anio_examen,
    MONTH(DATEADD(HOUR, -4, e.fecha_examen)) AS mes_examen_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, e.fecha_examen)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_examen_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -4, e.fecha_examen)), 
        '-', 
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, e.fecha_examen)) AS VARCHAR(2)), 2)
    ) AS periodo_examen,

    0 AS es_origen_ghl,
    'Orgánico' AS canal_adquisicion

FROM [dbo].[Clinica_Examenes] e;
GO

-- ================================================================
-- VISTA 8: Fact_Eficiencia_Ordenes (AJUSTADA GMT-4)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Eficiencia_Ordenes] AS
WITH BaseData AS (
    SELECT 
        V.id_pedido,
        V.numero_pedido,
        V.id_sucursal,
        V.id_cliente,
        ISNULL(C.nombre, 'SIN CLIENTE') + ' ' + ISNULL(C.apellido, '') AS nombre_cliente,
        CAST(DATEADD(HOUR, -4, V.fecha_pedido) AS DATE) AS [Fecha_Pedido],
        O.id_estado_orden,
        R.fecha_recepcion,
        CAST(DATEADD(HOUR, -4, R.fecha_recepcion) AS DATE) AS [Fecha_Recepcion]

    FROM [dbo].[Ventas_Pedidos] V
    INNER JOIN [dbo].[Operaciones_Ordenes_Cristales] O ON V.id_pedido = O.id_pedido_venta
    LEFT JOIN [dbo].[Operaciones_Recepciones_Lab] R ON O.id_orden_cristal = R.id_pedido_origen
    LEFT JOIN [dbo].[Maestro_Clientes] C ON V.id_cliente = C.id_cliente
    WHERE V.fecha_pedido >= '2025-01-01'
)

SELECT 
    *,
    
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

    CASE 
        WHEN id_estado_orden IN (10, 13) AND [Fecha_Recepcion] IS NOT NULL 
             THEN DATEDIFF(DAY, [Fecha_Pedido], [Fecha_Recepcion])
        WHEN id_estado_orden IN (6, 7, 14, 15) 
             THEN DATEDIFF(DAY, [Fecha_Pedido], CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE))
        ELSE DATEDIFF(DAY, [Fecha_Pedido], ISNULL([Fecha_Recepcion], CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE)))
    END AS [Dias_Lab],

    CASE 
        WHEN id_estado_orden = 13 THEN 'Entregado'
        WHEN id_estado_orden = 10 THEN 'Listo en Tienda'
        WHEN id_estado_orden = 7  THEN 'En Laboratorio'
        WHEN id_estado_orden = 17 THEN 'Poco Abono'
        WHEN [Fecha_Recepcion] IS NULL AND DATEDIFF(DAY, [Fecha_Pedido], CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE)) > 15 THEN 'Retrasado Crítico'
        ELSE 'En Proceso'
    END AS [Estatus_Logistico],

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
        WHEN [Fecha_Recepcion] IS NULL AND DATEDIFF(DAY, [Fecha_Pedido], CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE)) <= 10 THEN 'En Proceso (Lab)'
        ELSE 'Fuera de Meta' 
    END AS [Semaforo_Meta],

    CASE 
        WHEN [Fecha_Recepcion] IS NOT NULL AND DATEDIFF(DAY, [Fecha_Pedido], [Fecha_Recepcion]) BETWEEN 0 AND 30 THEN 'Dato Operativo Real'
        WHEN [Fecha_Recepcion] IS NOT NULL AND DATEDIFF(DAY, [Fecha_Pedido], [Fecha_Recepcion]) > 30 THEN 'Histórico Atípico'
        WHEN [Fecha_Recepcion] IS NULL AND DATEDIFF(DAY, [Fecha_Pedido], CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE)) > 10 THEN 'Dato Operativo Real'
        ELSE 'Faltante' 
    END AS [Calidad_Analisis]

FROM BaseData;
GO

-- ================================================================
-- VISTA 9: Fact_Produccion_Lentes (AJUSTADA GMT-4)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Produccion_Lentes] AS
SELECT 
    id_orden_cristal AS [ID_Orden],
    codigo_orden AS [Codigo_Sobre],
    id_pedido_venta AS [ID_Pedido],
    id_sucursal AS [ID_Sucursal],
    id_cliente AS [ID_Cliente],
    DATEADD(HOUR, -4, fecha_creacion) AS [Fecha_Promesa],
    
    od_esfera, od_cilindro, od_adicion,
    od_tipo_lente, od_material,
    
    oi_esfera, oi_cilindro, oi_adicion,
    oi_tipo_lente, oi_material,

    CASE 
        WHEN od_esfera < 0 THEN 'Miopía'
        WHEN od_esfera > 0 THEN 'Hipermetropía'
        ELSE 'Neutro'
    END AS [Diagnostico_Derecho],
    
    DATEADD(HOUR, -4, fecha_carga_etl) AS fecha_carga_etl
FROM [dbo].[Operaciones_Ordenes_Cristales];
GO

-- ================================================================
-- VISTA 10: Fact_Recaudo (AJUSTADA GMT-4)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Recaudo] AS
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

    -- Ajuste a GMT-4 para Venezuela
    CAST(DATEADD(HOUR, -4, C.fecha_cobro) AS DATE) AS fecha_completa,
    YEAR(DATEADD(HOUR, -4, C.fecha_cobro)) AS anio_cobro,
    MONTH(DATEADD(HOUR, -4, C.fecha_cobro)) AS mes_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, C.fecha_cobro)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, C.fecha_cobro)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, C.fecha_cobro)) AS VARCHAR(2)), 2)) AS periodo
FROM [dbo].[Finanzas_Cobros] C
WHERE C.fecha_cobro >= '2025-01-01';
GO

-- ================================================================
-- VISTA 11: Fact_Tesoreria (AJUSTADA GMT-4)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Tesoreria] AS
SELECT 
    id_pago_tesoreria,
    id_sucursal,
    UPPER(TRIM(descripcion)) AS concepto_movimiento,
    UPPER(TRIM(metodo_pago_nombre)) AS metodo_pago,
    monto AS monto_movimiento,
    
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
    
    -- Ajuste a GMT-4 para Venezuela
    CAST(DATEADD(HOUR, -4, fecha_movimiento) AS DATE) AS fecha_completa,
    YEAR(DATEADD(HOUR, -4, fecha_movimiento)) AS anio_tesoreria,
    MONTH(DATEADD(HOUR, -4, fecha_movimiento)) AS mes_tesoreria_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_movimiento)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_tesoreria_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, fecha_movimiento)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_movimiento)) AS VARCHAR(2)), 2)) AS periodo_tesoreria
FROM [dbo].[Finanzas_Tesoreria]
WHERE fecha_movimiento >= '2025-01-01'
  AND UPPER(TRIM(tipo_movimiento)) = 'MC' 
  AND monto <> 0;
GO

-- ================================================================
-- VISTA 12: Fact_Ventas (AJUSTADA GMT-4 + IVA 16%)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Ventas] AS
SELECT 
    id_factura,
    CAST(DATEADD(HOUR, -4, fecha_factura) AS DATE) AS fecha_factura,
    id_sucursal,
    id_cliente,
    ISNULL(id_empleado, 0) AS id_vendedor,     
    ISNULL(id_optometrista, -1) AS id_optometrista,
    monto_total,
    CASE 
        WHEN monto_total < 0 THEN 'Devolución' 
        ELSE 'Venta' 
    END AS tipo_transaccion,
    -- IVA VENEZUELA 16% (NO 7% de Panamá)
    CAST(monto_total / 1.16 AS DECIMAL(18,4)) AS monto_sin_iva,

    -- Ajuste a GMT-4 para Venezuela
    YEAR(DATEADD(HOUR, -4, fecha_factura)) AS anio_factura,
    MONTH(DATEADD(HOUR, -4, fecha_factura)) AS mes_factura_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_factura)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_factura_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, fecha_factura)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_factura
FROM [dbo].[Ventas_Cabecera]
WHERE fecha_factura >= '2025-01-01';
GO

-- ================================================================
-- VISTA 13: Fact_Ventas_Analitico (AJUSTADA GMT-4)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Ventas_Analitico] AS
SELECT 
    D.id_factura,
    D.id_linea,
    D.id_producto,
    D.cantidad,
    V.id_sucursal,
    
    D.precio_unitario AS precio_lista_unitario, 
    D.total_linea AS monto_final_transaccional, 
    CAST(D.total_linea - (D.cantidad * D.precio_unitario) AS DECIMAL(18,4)) AS ajuste_comercial_neto,

    P.nombre_producto,
    P.nombre_modelo_padre,
    P.material_marco,
    P.tipo_montura,
    P.genero_objetivo,

    C.nombre_categoria,
    C.id_categoria_padre,

    CASE 
        WHEN UPPER(P.nombre_producto) LIKE '%TRANSITION%' 
          OR UPPER(P.nombre_producto) LIKE '%TGENS%' THEN 'FOTOCROMATICO (TRANSITIONS)'
        WHEN UPPER(P.nombre_producto) LIKE '%PHOTOMAX%' 
          OR UPPER(P.nombre_producto) LIKE '%PHOTO MAX%' 
          OR UPPER(P.nombre_producto) LIKE '% PHOTO %' THEN 'FOTOCROMATICO (PHOTOMAX)'
        WHEN UPPER(P.nombre_producto) LIKE '%COLORMATIC%' THEN 'FOTOCROMATICO (COLORMATIC)'
        WHEN UPPER(P.nombre_producto) LIKE '%FOTOCROMATICO%' 
          OR UPPER(P.nombre_producto) LIKE '%FOTOCROMÁTICO%' THEN 'FOTOCROMATICO (GENERICO)'
        WHEN C.id_categoria IN (41, 45, 28) THEN 'NORMAL (BLANCO)'
        ELSE UPPER(C.nombre_categoria) 
    END AS subcategoria_lente,

    -- Ajuste a GMT-4 para Venezuela
    CAST(DATEADD(HOUR, -4, V.fecha_factura) AS DATE) AS fecha_factura,
    YEAR(DATEADD(HOUR, -4, V.fecha_factura)) AS anio_venta,
    MONTH(DATEADD(HOUR, -4, V.fecha_factura)) AS mes_venta_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, V.fecha_factura)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_venta_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, V.fecha_factura)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, V.fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_venta

FROM [dbo].[Ventas_Detalle] D
INNER JOIN [dbo].[Ventas_Cabecera] V ON D.id_factura = V.id_factura
INNER JOIN [dbo].[Maestro_Productos] P ON D.id_producto = P.id_producto
INNER JOIN [dbo].[Maestro_Categorias] C ON P.id_categoria = C.id_categoria;
GO

-- ================================================================
-- VISTA 14: Fact_Ventas_Detalle (AJUSTADA GMT-4)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Ventas_Detalle] AS
SELECT 
    D.id_factura,
    D.id_linea,
    D.id_producto,
    D.cantidad,
    V.id_sucursal,
    D.precio_unitario AS precio_lista_unitario, 
    D.total_linea AS monto_final_transaccional, 
    CAST(D.total_linea - (D.cantidad * D.precio_unitario) AS DECIMAL(18,4)) AS ajuste_comercial_neto,

    -- Ajuste a GMT-4 para Venezuela
    CAST(DATEADD(HOUR, -4, V.fecha_factura) AS DATE) AS fecha_factura,
    YEAR(DATEADD(HOUR, -4, V.fecha_factura)) AS anio_venta,
    MONTH(DATEADD(HOUR, -4, V.fecha_factura)) AS mes_venta_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, V.fecha_factura)), 
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_venta_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, V.fecha_factura)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, V.fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_venta
FROM [dbo].[Ventas_Detalle] D
INNER JOIN [dbo].[Ventas_Cabecera] V ON D.id_factura = V.id_factura;
GO

-- ================================================================
-- FIN DE SCRIPT
-- ================================================================
PRINT '✓ Todas las vistas para OPTI-COLOR Venezuela han sido creadas exitosamente'
PRINT '✓ Se han eliminado referencias a Zoho Books y GHL'
PRINT '✓ Se han aplicado ajustes GMT-4 (Venezuela) en todas las vistas temporales'
PRINT '✓ IVA ajustado a 16% donde aplica'
GO
