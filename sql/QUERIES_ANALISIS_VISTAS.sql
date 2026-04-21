-- ================================================================
-- OPTI-COLOR VENEZUELA - QUERIES ÚTILES PARA ANÁLISIS
-- Archivo: QUERIES_ANALISIS_VISTAS.sql
-- Propósito: Ejemplos para validar y analizar datos en vistas
-- ================================================================

-- ================================================================
-- ANALISIS 1: ESTADO DE VISTAS (Validación)
-- ================================================================
PRINT '=== ANÁLISIS 1: ESTADO DE TODAS LAS VISTAS ==='
GO

SELECT
    TABLE_NAME AS nombre_vista,
    CASE WHEN TABLE_NAME LIKE 'Dim_%' THEN 'Dimensión' ELSE 'Hecho' END AS tipo_vista,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = V.TABLE_NAME AND TABLE_SCHEMA = 'dbo') AS num_columnas,
    'OK' AS estado
FROM INFORMATION_SCHEMA.VIEWS V
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%')
ORDER BY tipo_vista DESC, TABLE_NAME;
GO

-- ================================================================
-- ANALISIS 2: CONTEO DE REGISTROS POR VISTA
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 2: CONTEO DE REGISTROS POR VISTA ==='
GO

-- Nota: Ejecuta estas queries individuales si alguna falla
-- (algunas vistas podrían depender de otras)

DECLARE @resultados TABLE (
    nombre_vista VARCHAR(100),
    cantidad_registros INT,
    tipo_vista VARCHAR(20),
    fecha_consulta DATETIME
);

-- Dimensiones
INSERT INTO @resultados VALUES ('Dim_Sucursales', (SELECT COUNT(*) FROM [dbo].[Dim_Sucursales]), 'Dim', GETDATE());
INSERT INTO @resultados VALUES ('Dim_Categorias', (SELECT COUNT(*) FROM [dbo].[Dim_Categorias]), 'Dim', GETDATE());
INSERT INTO @resultados VALUES ('Dim_Clientes', (SELECT COUNT(*) FROM [dbo].[Dim_Clientes]), 'Dim', GETDATE());

-- Hechos
BEGIN TRY
    INSERT INTO @resultados VALUES ('Fact_Pedidos', (SELECT COUNT(*) FROM [dbo].[Fact_Pedidos]), 'Fact', GETDATE());
END TRY BEGIN CATCH END;

BEGIN TRY
    INSERT INTO @resultados VALUES ('Fact_Ventas', (SELECT COUNT(*) FROM [dbo].[Fact_Ventas]), 'Fact', GETDATE());
END TRY BEGIN CATCH END;

BEGIN TRY
    INSERT INTO @resultados VALUES ('Fact_Recaudo', (SELECT COUNT(*) FROM [dbo].[Fact_Recaudo]), 'Fact', GETDATE());
END TRY BEGIN CATCH END;

BEGIN TRY
    INSERT INTO @resultados VALUES ('Fact_Examenes', (SELECT COUNT(*) FROM [dbo].[Fact_Examenes]), 'Fact', GETDATE());
END TRY BEGIN CATCH END;

BEGIN TRY
    INSERT INTO @resultados VALUES ('Fact_Tesoreria', (SELECT COUNT(*) FROM [dbo].[Fact_Tesoreria]), 'Fact', GETDATE());
END TRY BEGIN CATCH END;

SELECT
    nombre_vista,
    cantidad_registros,
    CASE WHEN cantidad_registros = 0 THEN '(sin datos — normal)' ELSE '✓ OK' END AS estado,
    tipo_vista
FROM @resultados
ORDER BY tipo_vista DESC, nombre_vista;
GO

-- ================================================================
-- ANALISIS 3: RANGO DE FECHAS EN VISTAS (Timeline)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 3: RANGO DE FECHAS (Timeline) ==='
GO

-- Fact_Pedidos
PRINT 'Fact_Pedidos:'
SELECT
    MIN(fecha_pedido_completa) AS fecha_minima,
    MAX(fecha_pedido_completa) AS fecha_maxima,
    COUNT(*) AS total_registros
FROM [dbo].[Fact_Pedidos];
GO

-- Fact_Ventas
PRINT 'Fact_Ventas:'
SELECT
    MIN(fecha_factura) AS fecha_minima,
    MAX(fecha_factura) AS fecha_maxima,
    COUNT(*) AS total_registros
FROM [dbo].[Fact_Ventas];
GO

-- Fact_Recaudo
PRINT 'Fact_Recaudo:'
SELECT
    MIN(fecha_completa) AS fecha_minima,
    MAX(fecha_completa) AS fecha_maxima,
    COUNT(*) AS total_registros
FROM [dbo].[Fact_Recaudo];
GO

-- ================================================================
-- ANALISIS 4: VERIFICACIÓN IVA (16% Venezuela)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 4: VERIFICACIÓN IVA 16% ==='
GO

SELECT TOP 10
    id_factura,
    monto_total,
    monto_sin_iva,
    CAST(monto_total - monto_sin_iva AS DECIMAL(10,2)) AS iva_absoluto,
    CAST((monto_total - monto_sin_iva) / NULLIF(monto_sin_iva, 0) * 100 AS DECIMAL(5,2)) AS iva_porcentaje,
    CASE
        WHEN ABS(((monto_total - monto_sin_iva) / NULLIF(monto_sin_iva, 0) * 100) - 16) < 0.5 THEN '✓ CORRECTO (16%)'
        WHEN (monto_total - monto_sin_iva) / NULLIF(monto_sin_iva, 0) * 100 BETWEEN 6 AND 8 THEN '✗ INCORRECTO (7% Panamá)'
        ELSE '⚠️ DIFERENTE'
    END AS validacion_iva
FROM [dbo].[Fact_Ventas]
WHERE monto_total <> 0
ORDER BY fecha_factura DESC;
GO

-- ================================================================
-- ANALISIS 5: TIMEZONE GMT-4 (Venezuela)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 5: VERIFICACIÓN TIMEZONE GMT-4 ==='
GO

-- Muestra rango de fechas en formato para verificar timezone
SELECT TOP 5
    fecha_pedido_completa,
    mes_pedido_nombre,
    anio_pedido,
    mes_pedido_nro,
    periodo_pedido,
    'Debe estar en GMT-4' AS nota
FROM [dbo].[Fact_Pedidos]
ORDER BY fecha_pedido_completa DESC;
GO

-- ================================================================
-- ANALISIS 6: DISTRIBUCIÓN GEOGRÁFICA (Venezuela)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 6: SUCURSALES POR ESTADO (Geografía Venezuela) ==='
GO

SELECT
    provincia,
    municipio,
    COUNT(DISTINCT id_sucursal) AS num_sucursales,
    STRING_AGG(nombre_sucursal, ', ') AS sucursales
FROM [dbo].[Dim_Sucursales]
WHERE provincia <> 'POR CLASIFICAR'
GROUP BY provincia, municipio
ORDER BY provincia, municipio;
GO

-- ================================================================
-- ANALISIS 7: CATEGORÍAS Y LÍNEAS DE NEGOCIO
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 7: CATEGORÍAS DISPONIBLES ==='
GO

SELECT
    linea_negocio,
    COUNT(*) AS num_categorias,
    STRING_AGG(nombre_categoria, ', ') AS categorias_incluidas
FROM [dbo].[Dim_Categorias]
GROUP BY linea_negocio
ORDER BY linea_negocio;
GO

-- ================================================================
-- ANALISIS 8: CLIENTES ACTIVOS
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 8: CLIENTES SEGMENTADOS ==='
GO

SELECT
    rango_edad_descripcion,
    genero_label,
    COUNT(*) AS num_clientes,
    COUNT(DISTINCT mes_registro_nombre) AS meses_activos
FROM [dbo].[Dim_Clientes]
GROUP BY rango_edad_descripcion, genero_label
ORDER BY rango_edad_descripcion, genero_label;
GO

-- ================================================================
-- ANALISIS 9: ESTADO ÓRDENES DE CRISTALES (Eficiencia Lab)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 9: EFICIENCIA ÓRDENES DE CRISTALES ==='
GO

SELECT TOP 20
    numero_pedido,
    Estado_Operativo_Texto,
    Estatus_Logistico,
    Dias_Lab,
    Semaforo_Meta,
    Calidad_Analisis
FROM [dbo].[Fact_Eficiencia_Ordenes]
WHERE Dias_Lab > 0
ORDER BY Dias_Lab DESC, Fecha_Pedido DESC;
GO

-- ================================================================
-- ANALISIS 10: VENTAS VS RECAUDOS
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 10: COMPARATIVA VENTAS VS RECAUDOS (Flujo Caja) ==='
GO

SELECT
    V.periodo_factura AS periodo,
    COUNT(V.id_factura) AS num_facturas,
    SUM(V.monto_total) AS total_vendido,
    COUNT(R.id_cobro) AS num_cobros,
    ISNULL(SUM(R.importe_neto), 0) AS total_recaudado,
    CAST(ISNULL(SUM(R.importe_neto), 0) / SUM(V.monto_total) * 100 AS DECIMAL(5,2)) AS porcentaje_cobranza
FROM [dbo].[Fact_Ventas] V
LEFT JOIN [dbo].[Fact_Recaudo] R ON V.id_factura = R.id_factura
GROUP BY V.periodo_factura
ORDER BY V.periodo_factura DESC;
GO

-- ================================================================
-- ANALISIS 11: VOLUMEN EXÁMENES CLÍNICOS
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 11: EXÁMENES CLÍNICOS (Desempeño Clínico) ==='
GO

SELECT
    tipo_examen,
    COUNT(*) AS num_examenes,
    COUNT(DISTINCT id_cliente) AS num_clientes_unicos,
    COUNT(DISTINCT id_sucursal) AS sucursales_con_examenes
FROM [dbo].[Fact_Examenes]
GROUP BY tipo_examen
ORDER BY num_examenes DESC;
GO

-- ================================================================
-- ANALISIS 12: MÉTODOS DE PAGO (Tesorería)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 12: ANÁLISIS DE MÉTODOS DE PAGO ==='
GO

SELECT
    metodo_pago,
    COUNT(*) AS num_transacciones,
    SUM(importe_neto) AS monto_total,
    AVG(importe_neto) AS promedio_transaccion
FROM [dbo].[Fact_Recaudo]
GROUP BY metodo_pago
ORDER BY monto_total DESC;
GO

-- ================================================================
-- ANALISIS 13: VENTAS POR MOTIVO (Marketing)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 13: ORIGEN DE VENTAS (MOTIVO) ==='
GO

SELECT
    motivo_visita,
    COUNT(*) AS num_ventas,
    SUM(monto_total) AS monto_total,
    CAST(AVG(monto_total) AS DECIMAL(10,2)) AS ticket_promedio
FROM [dbo].[Fact_Ventas_Por_Motivo]
WHERE motivo_visita IS NOT NULL
GROUP BY motivo_visita
ORDER BY monto_total DESC;
GO

-- ================================================================
-- ANALISIS 14: ANÁLISIS DE PRODUCTOS (Líneas de Venta)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 14: PRODUCTOS VENDIDOS (Líneas de Negocio) ==='
GO

SELECT TOP 20
    subcategoria_lente,
    COUNT(*) AS num_articulos_vendidos,
    SUM(monto_final_transaccional) AS monto_venta,
    CAST(AVG(precio_lista_unitario) AS DECIMAL(10,2)) AS precio_promedio
FROM [dbo].[Fact_Ventas_Analitico]
GROUP BY subcategoria_lente
ORDER BY monto_venta DESC;
GO

-- ================================================================
-- ANALISIS 15: DESEMPEÑO POR SUCURSAL (Comparativa Regional)
-- ================================================================
PRINT ''
PRINT '=== ANÁLISIS 15: DESEMPEÑO POR SUCURSAL (Top 10) ==='
GO

SELECT TOP 10
    S.nombre_comercial,
    S.provincia,
    COUNT(DISTINCT V.id_factura) AS num_facturas,
    SUM(V.monto_total) AS total_venta,
    CAST(AVG(V.monto_total) AS DECIMAL(10,2)) AS ticket_promedio,
    COUNT(DISTINCT V.id_cliente) AS clientes_unicos
FROM [dbo].[Fact_Ventas] V
INNER JOIN [dbo].[Dim_Sucursales] S ON V.id_sucursal = S.id_sucursal
GROUP BY S.nombre_comercial, S.provincia, V.id_sucursal
ORDER BY total_venta DESC;
GO

-- ================================================================
-- FIN DE ANÁLISIS
-- ================================================================
PRINT ''
PRINT '✓ ANÁLISIS COMPLETADO'
PRINT '  Próximo paso: Cargar datos ETL desde Gesvision API'
GO
