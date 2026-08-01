// STRING_SPLIT() sobre un parámetro de cadena le da al optimizador una
// estimación de cardinalidad genérica (no puede "ver" cuántos IDs hay hasta
// ejecutar), lo que en tablas grandes (confirmado contra Operaciones_Inventario,
// 435k filas) le hace elegir un plan que cae a un spill a tempdb — +9 a +10s
// extra medidos vs. el mismo filtro escrito como lista literal `IN (1,2,3)`.
// `OPTION (RECOMPILE)` no lo arregla (mismo plan lento, confirmado con evidencia)
// porque el problema es la falta de cardinalidad conocida en tiempo de
// compilación, no un parámetro mal sniffeado. Por eso acá se arma el `IN (...)`
// como lista literal de enteros — nunca se concatena el string crudo del
// usuario: cada valor se valida con `/^-?\d+$/` y se descarta si no matchea,
// el mismo nivel de seguridad que tenía la versión parametrizada.
function toSafeIntCsv(csv: string | null | undefined): string[] {
  if (!csv) return [];
  return csv
    .split(",")
    .map((v) => v.trim())
    .filter((v) => /^-?\d+$/.test(v));
}

export function buildSucursalFilter(
  tableAlias = "",
  sucursales: string | null = null,
  allowedSucursales = "-1",
): string {
  const col = tableAlias ? `${tableAlias}.id_sucursal` : "id_sucursal";

  // Sin IDs válidos en allowedSucursales -> no debe matchear ninguna fila
  // (mismo comportamiento de "deny all" que el sentinel "-1" de getUserAllowedSucursales).
  const allowedIds = toSafeIntCsv(allowedSucursales);
  const allowedClause = allowedIds.length > 0 ? `${col} IN (${allowedIds.join(",")})` : "1 = 0";

  // sucursales == null (o sin IDs válidos) -> sin restricción adicional, igual
  // que el `@sucursales IS NULL OR ...` original.
  const selectedIds = toSafeIntCsv(sucursales);
  const selectedClause = selectedIds.length > 0 ? ` AND ${col} IN (${selectedIds.join(",")})` : "";

  return `
    AND ${allowedClause}${selectedClause}
  `;
}

// Mismo antipattern que buildSucursalFilter (STRING_SPLIT con mala estimación
// de cardinalidad), pero para filtros de TEXTO (Marca, Segmento_Comercial,
// tipo_lente_agrupado) — acá no se puede validar con una regex de solo dígitos
// como con sucursal, así que en vez de armar un literal SQL (que requeriría
// escapar comillas a mano) cada valor viaja como su propio parámetro bindeado
// (@prefix0, @prefix1, ...). Cero riesgo de inyección — nunca se interpola el
// texto del usuario directo en el SQL, solo los nombres de parámetro generados
// acá (siempre `${paramPrefix}${indice}`, nunca derivados del input).
export type NamedInFilter = {
  sql: string;
  entries: [name: string, value: string][];
};

const isAllSentinel = (val: string | null | undefined): boolean =>
  !val || val.toUpperCase() === "TODOS" || val === "%";

export function buildNamedInFilter(
  column: string,
  paramPrefix: string,
  csv: string | null | undefined,
): NamedInFilter {
  if (isAllSentinel(csv)) return { sql: "", entries: [] };

  const values = csv!
    .split(",")
    .map((v) => v.trim())
    .filter((v) => v.length > 0);
  if (values.length === 0) return { sql: "", entries: [] };

  const entries: [string, string][] = values.map((v, i) => [`${paramPrefix}${i}`, v]);
  const sql = `AND ${column} IN (${entries.map(([name]) => `@${name}`).join(", ")})`;
  return { sql, entries };
}
