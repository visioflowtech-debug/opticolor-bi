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

console.log("=== Fix propuesto, SIN filtro de fecha (todo el histórico) ===");
const res = await pool.request().query(`
  SELECT
    dp.Segmento_Comercial AS grupo,
    ISNULL(SUM(fvd.total_linea_usd), 0) AS ventaNetaUsd
  FROM dbo.Fact_Ventas_Detalle fvd
  INNER JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
  WHERE dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS')
    AND dp.Segmento_Comercial IS NOT NULL AND LTRIM(RTRIM(dp.Segmento_Comercial)) <> ''
  GROUP BY dp.Segmento_Comercial
  ORDER BY SUM(fvd.total_linea_usd) DESC
`);
console.log(res.recordset);
await pool.close();
