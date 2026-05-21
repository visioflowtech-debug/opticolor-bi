export function buildSucursalFilter(tableAlias = ""): string {
  const col = tableAlias ? `${tableAlias}.id_sucursal` : "id_sucursal";
  return `
    AND ${col} IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@allowedSucursales, ','))
    AND (@sucursales IS NULL OR ${col} IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@sucursales, ',')))
  `;
}
