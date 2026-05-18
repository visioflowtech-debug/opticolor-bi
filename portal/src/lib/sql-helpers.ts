export function buildSucursalFilter(tableAlias = ""): string {
  const col = tableAlias ? `${tableAlias}.id_sucursal` : "id_sucursal";
  return `
    AND (
      (
        @isSupervisor = 1
        AND ${col} IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@allowedSucursales, ','))
      )
      OR (
        @isSupervisor = 0
        AND ${col} IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@allowedSucursales, ','))
        AND (@sucursalId IS NULL OR ${col} = @sucursalId)
      )
    )`;
}
