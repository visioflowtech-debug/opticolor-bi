export function buildSucursalFilter(tableAlias = "", isMaster = false): string {
  const col = tableAlias ? `${tableAlias}.id_sucursal` : "id_sucursal";
  if (isMaster) {
    return `
      AND ${col} NOT IN (3, 4)
      AND (@sucursales IS NULL OR ${col} IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@sucursales, ',')))
    `;
  }
  return `
    AND ${col} IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@allowedSucursales, ','))
    AND (@sucursales IS NULL OR ${col} IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@sucursales, ',')))
  `;
}
