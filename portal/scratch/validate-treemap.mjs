import sql from "mssql";

const config = {
  server: process.env.AZURE_SQL_SERVER,
  database: process.env.AZURE_SQL_DATABASE,
  user: process.env.AZURE_SQL_USER,
  password: process.env.AZURE_SQL_PASSWORD,
  port: Number(process.env.AZURE_SQL_PORT || 1433),
  options: { encrypt: true, trustServerCertificate: false },
};

const pool = await sql.connect(config);
const START = "2026-01-01";
const END = "2026-07-28"; // día cerrado

console.log("=== Query actual del treemap (sin filtro LENTES/TRATAMIENTOS) ===");
const actual = await pool.request().query(`
  SELECT
    ISNULL(dp.Segmento_Comercial, 'SIN GRUPO') AS grupo,
    ISNULL(SUM(fvd.total_linea_usd), 0)       AS ventaNetaUsd
  FROM dbo.Fact_Ventas_Detalle fvd
  LEFT JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
  WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN '${START}' AND '${END}'
  GROUP BY dp.Segmento_Comercial
  ORDER BY SUM(fvd.total_linea_usd) DESC
`);
console.log(actual.recordset);

console.log("\n=== Diagnóstico 'Sin Grupo': huérfanas de join vs producto existente con Segmento_Comercial nulo ===");
const diag = await pool.request().query(`
  SELECT
    CASE
      WHEN dp.SK_Producto IS NULL THEN 'HUERFANA_SIN_MATCH_DIM_PRODUCTOS'
      WHEN dp.Segmento_Comercial IS NULL OR LTRIM(RTRIM(dp.Segmento_Comercial)) = '' THEN 'PRODUCTO_EXISTE_SEGMENTO_NULO'
      ELSE 'OTRO'
    END AS caso,
    COUNT(*) AS filas,
    ISNULL(SUM(fvd.total_linea_usd), 0) AS montoUsd
  FROM dbo.Fact_Ventas_Detalle fvd
  LEFT JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
  WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN '${START}' AND '${END}'
    AND (dp.SK_Producto IS NULL OR dp.Segmento_Comercial IS NULL OR LTRIM(RTRIM(dp.Segmento_Comercial)) = '')
  GROUP BY CASE
      WHEN dp.SK_Producto IS NULL THEN 'HUERFANA_SIN_MATCH_DIM_PRODUCTOS'
      WHEN dp.Segmento_Comercial IS NULL OR LTRIM(RTRIM(dp.Segmento_Comercial)) = '' THEN 'PRODUCTO_EXISTE_SEGMENTO_NULO'
      ELSE 'OTRO'
    END
`);
console.log(diag.recordset);

console.log("\n=== Con filtro LENTES/TRATAMIENTOS excluido (prueba temporal) ===");
const conFiltro = await pool.request().query(`
  SELECT
    ISNULL(dp.Segmento_Comercial, 'SIN GRUPO') AS grupo,
    ISNULL(SUM(fvd.total_linea_usd), 0)       AS ventaNetaUsd
  FROM dbo.Fact_Ventas_Detalle fvd
  LEFT JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
  WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN '${START}' AND '${END}'
    AND (dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS') OR dp.Segmento_Comercial IS NULL)
  GROUP BY dp.Segmento_Comercial
  ORDER BY SUM(fvd.total_linea_usd) DESC
`);
console.log(conFiltro.recordset);

console.log("\n=== Fix definitivo propuesto: excluir LENTES/TRATAMIENTOS Y excluir Sin Grupo (INNER JOIN + Segmento no nulo) ===");
const finalFix = await pool.request().query(`
  SELECT
    dp.Segmento_Comercial AS grupo,
    ISNULL(SUM(fvd.total_linea_usd), 0) AS ventaNetaUsd
  FROM dbo.Fact_Ventas_Detalle fvd
  INNER JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
  WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN '${START}' AND '${END}'
    AND dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS')
    AND dp.Segmento_Comercial IS NOT NULL AND LTRIM(RTRIM(dp.Segmento_Comercial)) <> ''
  GROUP BY dp.Segmento_Comercial
  ORDER BY SUM(fvd.total_linea_usd) DESC
`);
console.log(finalFix.recordset);

await pool.close();
