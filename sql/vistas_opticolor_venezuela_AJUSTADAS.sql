-- ================================================================
-- OPTI-COLOR VENEZUELA - VISTAS AJUSTADAS A ESTRUCTURA REAL
-- Fecha: 20/04/2026
-- Cambios: GMT-4, IVA 16%, geografía parametrizada
-- Nota: Ajustadas a estructura DDL real de Opticolor Venezuela
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
-- VISTA 1: Dim_Sucursales (AJUSTADA - Sin columnas inexistentes)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Sucursales] AS
SELECT
    id_sucursal,
    UPPER(nombre_sucursal) AS nombre_sucursal,
    UPPER(ISNULL(alias_sucursal, nombre_sucursal)) AS nombre_comercial,
    ISNULL(municipio_raw, 'POR CLASIFICAR') AS municipio,
    ISNULL(localidad_raw, 'POR CLASIFICAR') AS localidad,
    direccion_raw AS direccion_exacta,
    CASE
        WHEN nombre_sucursal LIKE '%Mall%' OR nombre_sucursal LIKE '%Multi%' THEN 'Centro Comercial'
        ELSE 'Sucursal Calle'
    END AS tipo_punto_venta,
    fecha_carga_etl
FROM [dbo].[Maestro_Sucursales]
GO

-- ================================================================
-- VISTA 2: Dim_Sucursales_Limpia
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Sucursales_Limpia] AS
SELECT
    id_sucursal,
    nombre_comercial AS [Nombre_Sucursal],
    municipio AS [Municipio],
    localidad AS [Localidad]
FROM [dbo].[Dim_Sucursales]
GO

-- ================================================================
-- VISTA 3: Dim_Categorias
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Categorias] AS
SELECT
    id_categoria,
    UPPER(nombre_categoria) AS nombre_categoria,
    CASE
        WHEN nombre_categoria LIKE '%LENTE%' THEN 'LENTICULAR'
        WHEN nombre_categoria LIKE '%ARO%' THEN 'MONTURAS'
        WHEN nombre_categoria LIKE '%SOLUCIONES%' OR nombre_categoria LIKE '%ACCESORIOS%' THEN 'SUMINISTROS'
        ELSE 'OTROS'
    END AS linea_negocio
FROM [dbo].[Maestro_Categorias]
WHERE esta_activo = 1
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
        ELSE 'NO DEFINIDO'
    END AS genero_label,
    ISNULL(DATEDIFF(YEAR, fecha_nacimiento, GETDATE()), 0) AS edad,
    CASE
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 1 AND 18 THEN '01 a 18'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 19 AND 30 THEN '19 a 30'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 31 AND 40 THEN '31 a 40'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 41 AND 50 THEN '41 a 50'
        WHEN DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) BETWEEN 51 AND 100 THEN '51 a 100'
        ELSE 'Mayor de 100'
    END AS rango_edad_descripcion,
    UPPER(ISNULL(ciudad, 'DESCONOCIDO')) AS distrito_residencia,
    email,
    CAST(DATEADD(HOUR, -4, fecha_creacion_cliente) AS DATE) AS fecha_registro_completa,
    YEAR(DATEADD(HOUR, -4, fecha_creacion_cliente)) AS anio_registro,
    MONTH(DATEADD(HOUR, -4, fecha_creacion_cliente)) AS mes_registro_nro
FROM [dbo].[Maestro_Clientes]
GO

-- ================================================================
-- VISTA 5: Fact_Pedidos (AJUSTADA)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Pedidos] AS
SELECT
    id_pedido,
    numero_pedido,
    id_sucursal,
    id_cliente,
    ISNULL(id_empleado, 0) AS id_asesor,
    monto_total,
    monto_pagado,
    saldo_pendiente,
    estado_pedido,
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
WHERE fecha_pedido >= '2025-01-01'
GO

-- ================================================================
-- VISTA 6: Fact_Ventas (AJUSTADA - IVA 16% Venezuela)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Ventas] AS
SELECT
    id_factura,
    CAST(DATEADD(HOUR, -4, fecha_factura) AS DATE) AS fecha_factura,
    id_sucursal,
    id_cliente,
    ISNULL(id_empleado, 0) AS id_vendedor,
    monto_total,
    CASE
        WHEN monto_total < 0 THEN 'Devolución'
        ELSE 'Venta'
    END AS tipo_transaccion,
    CAST(monto_total / 1.16 AS DECIMAL(18,4)) AS monto_sin_iva,
    YEAR(DATEADD(HOUR, -4, fecha_factura)) AS anio_factura,
    MONTH(DATEADD(HOUR, -4, fecha_factura)) AS mes_factura_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_factura)),
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_factura_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, fecha_factura)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_factura)) AS VARCHAR(2)), 2)) AS periodo_factura
FROM [dbo].[Ventas_Cabecera]
WHERE fecha_factura >= '2025-01-01'
GO

-- ================================================================
-- VISTA 7: Fact_Recaudo (AJUSTADA)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Recaudo] AS
SELECT
    id_cobro,
    ISNULL(id_factura, 0) AS id_factura,
    id_pedido,
    id_sucursal,
    id_cliente,
    UPPER(TRIM(metodo_pago_nombre)) AS metodo_pago,
    CASE
        WHEN id_factura = 0 OR id_factura IS NULL THEN 'ANTICIPO (PENDIENTE ENTREGA)'
        ELSE 'LIQUIDACIÓN (FACTURADO)'
    END AS tipo_recaudo,
    ISNULL(monto_cobrado, 0) AS importe_neto,
    CAST(DATEADD(HOUR, -4, fecha_cobro) AS DATE) AS fecha_completa,
    YEAR(DATEADD(HOUR, -4, fecha_cobro)) AS anio_cobro,
    MONTH(DATEADD(HOUR, -4, fecha_cobro)) AS mes_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_cobro)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, fecha_cobro)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_cobro)) AS VARCHAR(2)), 2)) AS periodo
FROM [dbo].[Finanzas_Cobros]
WHERE fecha_cobro >= '2025-01-01'
GO

-- ================================================================
-- VISTA 8: Fact_Tesoreria (AJUSTADA)
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
    CAST(DATEADD(HOUR, -4, fecha_movimiento) AS DATE) AS fecha_completa,
    YEAR(DATEADD(HOUR, -4, fecha_movimiento)) AS anio_tesoreria,
    MONTH(DATEADD(HOUR, -4, fecha_movimiento)) AS mes_tesoreria_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_movimiento)), 'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre') AS mes_tesoreria_nombre,
    CONCAT(YEAR(DATEADD(HOUR, -4, fecha_movimiento)), '-', RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_movimiento)) AS VARCHAR(2)), 2)) AS periodo_tesoreria
FROM [dbo].[Finanzas_Tesoreria]
WHERE fecha_movimiento >= '2025-01-01'
  AND UPPER(TRIM(tipo_movimiento)) = 'MC'
  AND monto <> 0
GO

-- ================================================================
-- VISTA 9: Fact_Examenes (AJUSTADA - columnas reales)
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Fact_Examenes] AS
SELECT
    id_examen,
    id_cliente,
    id_sucursal,
    id_empleado AS id_optometrista,
    UPPER(ISNULL(tipo_examen, 'GENERAL')) AS tipo_examen,
    UPPER(ISNULL(observaciones, 'SIN OBSERVACIONES')) AS notas_clinicas,
    CAST(DATEADD(HOUR, -4, fecha_examen) AS DATE) AS fecha_examen_completa,
    YEAR(DATEADD(HOUR, -4, fecha_examen)) AS anio_examen,
    MONTH(DATEADD(HOUR, -4, fecha_examen)) AS mes_examen_nro,
    CHOOSE(MONTH(DATEADD(HOUR, -4, fecha_examen)),
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS mes_examen_nombre,
    CONCAT(
        YEAR(DATEADD(HOUR, -4, fecha_examen)),
        '-',
        RIGHT('0' + CAST(MONTH(DATEADD(HOUR, -4, fecha_examen)) AS VARCHAR(2)), 2)
    ) AS periodo_examen
FROM [dbo].[Clinica_Examenes]
GO

-- ================================================================
-- VISTA 10: Fact_Produccion_Lentes (AJUSTADA)
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
FROM [dbo].[Operaciones_Ordenes_Cristales]
GO

-- ================================================================
-- VISTA 11: Fact_Eficiencia_Ordenes (AJUSTADA)
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
        ELSE '0. OTROS'
    END AS [Estado_Operativo_Texto],
    DATEDIFF(DAY, [Fecha_Pedido], ISNULL([Fecha_Recepcion], CAST(DATEADD(HOUR, -4, GETUTCDATE()) AS DATE))) AS [Dias_Lab],
    CASE
        WHEN id_estado_orden = 13 THEN 'Entregado'
        WHEN id_estado_orden = 10 THEN 'Listo en Tienda'
        WHEN id_estado_orden = 7  THEN 'En Laboratorio'
        ELSE 'En Proceso'
    END AS [Estatus_Logistico],
    YEAR([Fecha_Pedido]) AS [Anio],
    MONTH([Fecha_Pedido]) AS [Mes_Nro],
    CASE MONTH([Fecha_Pedido])
        WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
    END AS [Mes_Nombre]
FROM BaseData
GO

-- ================================================================
-- VISTA 12: Dim_Estados_Venezuela
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Estados_Venezuela] AS
SELECT DISTINCT
    1 AS id_estado,
    municipio_raw AS estado_nombre,
    COUNT(DISTINCT id_sucursal) AS num_sucursales
FROM [dbo].[Maestro_Sucursales]
WHERE municipio_raw IS NOT NULL
GROUP BY municipio_raw
GO

-- ================================================================
-- VISTA 13: Dim_Municipios_Venezuela
-- ================================================================
CREATE OR ALTER VIEW [dbo].[Dim_Municipios_Venezuela] AS
SELECT DISTINCT
    1 AS id_municipio,
    localidad_raw AS municipio_nombre,
    COUNT(DISTINCT id_sucursal) AS num_sucursales
FROM [dbo].[Maestro_Sucursales]
WHERE localidad_raw IS NOT NULL
GROUP BY localidad_raw
GO

-- ================================================================
-- FIN DE SCRIPT
-- ================================================================
PRINT 'Todas las vistas para OPTI-COLOR Venezuela han sido creadas exitosamente'
PRINT 'Se han eliminado referencias a Zoho Books y GHL'
PRINT 'Se han aplicado ajustes GMT-4 (Venezuela) en todas las vistas temporales'
PRINT 'IVA ajustado a 16% donde aplica'
GO
