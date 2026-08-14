"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter, buildNamedInFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";

// ─── Stock/Capital: dbo.Dash_Inventario_Agregado ──────────────────────────────
// Tabla con MERGE por id_producto/id_sucursal (fecha_foto es un watermark por
// fila, no un lote — por eso las 4 funciones de abajo suman stock_total sin
// filtrar por fecha_foto, confirmado con Gerardo), reemplaza el cálculo en
// vivo que hacía este módulo contra Fact_Inventario (496,989 filas). El
// filtro RBAC de sucursal sigue centralizado en el único
// lugar de siempre: `buildSucursalFilter` (src/lib/sql-helpers.ts) — cuando
// llegue la decisión de cliente sobre excluir sucursales no-comerciales
// (ALMACÉN=3, LAB MARACAIBO=4, LAB 2=51) del gráfico "por sucursal", el punto
// de inserción es acá arriba (una constante nueva aplicada donde se llama a
// buildSucursalFilter("dia", ...) más abajo), no repetido por query.

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type InventarioKpis = {
  stockFisico: number;
  capitalInvertidoUsd: number;
  unidadesVendidas: number;
  ventaNetaProducto: number;
  upt: number;
  fechaFoto: string | null; // ISO; MAX(fecha_generacion) — momento en que corrió el SP, no fecha_foto
                            // (fecha_foto es un watermark por fila/producto, puede quedar vieja sin
                            // reflejar que la tabla se recalculó). null si la tabla está vacía.
};

export type MarcaItem = {
  marca: string;
  unidadesVendidas: number;
  stockFisico: number;
  ventaNetaUsd: number;
};

export type DispersionItem = {
  grupo: string;
  unidadesVendidas: number;
  stockFisico: number;
  ventaNetaUsd: number;
};

export type GrupoMix = {
  name: string;
  size: number;       // ventaNeta — Recharts Treemap usa este campo para el área
  porcentaje: number; // 1 decimal
};

export type RotacionSucursal = {
  idSucursal: number;
  nombreSucursal: string;
  unidadesVendidas: number;
  stockFisico: number;
  pctRotacion: number; // 0-100+, ya multiplicado por 100 (ej. 61.3 = 61.3%)
};

import { ReportParams } from "@/types/dashboard";

export type Params = ReportParams;

type FetchParams = Params & { allowedSucursales: string };

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type InvAggRow = {
  marca: string;
  stockFisico: number;
  capitalInvertidoUsd: number;
};

type VentaFusedRow = {
  marca: string | null;
  grupo: string | null;
  unidadesVendidas: number;
  ventaNeta: number;
};

// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchInventarioKPIs = unstable_cache(
  async (params: FetchParams): Promise<InventarioKpis> => {
    const { startDate, endDate, sucursales, marcaFilter, grupoFilter, allowedSucursales } = params;
    const pool = await getConnection();

    // Filtros dimensionales — dos variantes porque el lado de stock ahora lee
    // columnas propias de Dash_Inventario_Agregado (marca/grupo, sin alias dp)
    // mientras que ventas/facturas siguen contra Fact_Ventas_Detalle LEFT JOIN
    // Dim_Productos (dp.Marca/dp.Segmento_Comercial), sin cambios.
    const marcaF = buildNamedInFilter("dp.Marca", "marca", marcaFilter);
    const grupoF = buildNamedInFilter("dp.Segmento_Comercial", "grupo", grupoFilter);
    const marcaFAgg = buildNamedInFilter("marca", "marcaAgg", marcaFilter);
    const grupoFAgg = buildNamedInFilter("grupo", "grupoAgg", grupoFilter);
    const marcaSql = marcaF.sql;
    const grupoSql = grupoF.sql;

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      for (const [name, value] of marcaF.entries) r = r.input(name, value);
      for (const [name, value] of grupoF.entries) r = r.input(name, value);
      for (const [name, value] of marcaFAgg.entries) r = r.input(name, value);
      for (const [name, value] of grupoFAgg.entries) r = r.input(name, value);
      return r;
    };

    const [inventarioRes, salesRes, facturasRes] = await Promise.all([
      // C-5.1 / C-5.2 · Stock, Capital y fecha de generación — dbo.Dash_Inventario_Agregado
      // (MERGE por id_producto/id_sucursal, refrescada por el ETL), reemplaza el
      // escaneo en vivo de Fact_Inventario (496,989 filas → 10.5ms de CPU vs.
      // 969ms antes). Validado PASO A/PASO B: totales idénticos a la query
      // anterior sobre Fact_Inventario LEFT JOIN Dim_Productos, sin filtro de
      // sucursal. SUM(stock_total) sin filtro de fecha_foto es correcto —
      // confirmado con Gerardo: fecha_foto es un watermark por fila, no un
      // lote/snapshot completo, así que filtrar por ella subcontaría el stock.
      // fecha_generacion sí es el timestamp del último corrido del SP, por eso
      // se usa para el label "Actualizado: ..." (no fecha_foto, que puede
      // quedar vieja en un producto sin movimiento reciente aunque la tabla se
      // haya recalculado hoy).
      // Sin filtro de fecha en el WHERE — confirmado que ya cumple la paridad
      // con Power BI (no reacciona al slicer de fecha), no se le agrega ninguno.
      req().query(`
        SELECT
          ISNULL(SUM(dia.stock_total), 0) AS stockFisico,
          ISNULL(SUM(dia.valor_total_usd), 0) AS capitalInvertidoUsd,
          MAX(dia.fecha_generacion) AS fechaFoto
        FROM dbo.Dash_Inventario_Agregado dia
        WHERE dia.grupo NOT IN ('LENTES', 'TRATAMIENTOS')
          ${buildSucursalFilter("dia", sucursales, allowedSucursales)}
          ${marcaFAgg.sql}
          ${grupoFAgg.sql}
      `),

      // C-5.3 · Unidades Vendidas (numerador de UPT) — sin cambios, sigue sobre
      // Fact_Ventas_Detalle con filtro de marca/grupo (ya confirmado exacto vs Power BI).
      req().query(`
        SELECT
          ISNULL(SUM(fvd.cantidad), 0)                                     AS unidadesVendidas,
          ISNULL(SUM(fvd.total_linea_usd), 0)                              AS ventaNetaProducto
        FROM dbo.Fact_Ventas_Detalle fvd
        LEFT JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
        WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${buildSucursalFilter("fvd", sucursales, allowedSucursales)}
          ${marcaSql}
          ${grupoSql}
      `),

      // C-5.4 · Cantidad Facturas (denominador de UPT) — DISTINCTCOUNT(Fact_Ventas[id_factura])
      // sobre la cabecera de factura, NO sobre Fact_Ventas_Detalle (mismo tipo de error ya
      // corregido en Ticket Promedio de Resumen Comercial). Fact_Ventas no tiene columna de
      // producto, así que este conteo no puede filtrarse por marca/grupo — coincide con la
      // definición real del DAX, que tampoco lo permite.
      req().query(`
        SELECT COUNT(DISTINCT id_factura) AS cantidadFacturas
        FROM dbo.Fact_Ventas
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
      `),
    ]);

    const inv    = inventarioRes.recordset[0] ?? { stockFisico: 0, capitalInvertidoUsd: 0, fechaFoto: null };
    const sales  = salesRes.recordset[0] ?? { unidadesVendidas: 0, ventaNetaProducto: 0 };
    const unidadesVendidas = Number(sales.unidadesVendidas ?? 0);
    const cantidadFacturas = Number((facturasRes.recordset as { cantidadFacturas: number }[])[0]?.cantidadFacturas ?? 0);

    // UPT: DIVIDE([Unidades Vendidas], [Cantidad Facturas], 0)
    const upt = cantidadFacturas > 0
      ? Math.round((unidadesVendidas / cantidadFacturas) * 10000) / 10000
      : 0;

    return {
      stockFisico:         Number(inv.stockFisico ?? 0),
      capitalInvertidoUsd: Number(inv.capitalInvertidoUsd ?? 0),
      unidadesVendidas,
      ventaNetaProducto:   Number(sales.ventaNetaProducto ?? 0),
      upt,
      fechaFoto: inv.fechaFoto ? new Date(inv.fechaFoto).toISOString() : null,
    };
  },
  ["dash-inventario-kpis"],
  { revalidate: 3600, tags: ["dash-inventario-kpis"] }
);

export async function getInventarioKPIs(
  params: Params,
): Promise<{ success: boolean; data?: InventarioKpis; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchInventarioKPIs({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getInventarioKPIs]", err);
    return { success: false, error: "Error al obtener KPIs de inventario." };
  }
}

// ─── 2. Detalle de Marcas ─────────────────────────────────────────────────────

const fetchMarcasDetalle = unstable_cache(
  async (params: FetchParams): Promise<MarcaItem[]> => {
    const { startDate, endDate, sucursales, marcaFilter, grupoFilter, allowedSucursales } = params;
    const pool = await getConnection();

    const marcaF = buildNamedInFilter("dp.Marca", "marca", marcaFilter);
    const grupoF = buildNamedInFilter("dp.Segmento_Comercial", "grupo", grupoFilter);
    const marcaFAgg = buildNamedInFilter("marca", "marcaAgg", marcaFilter);
    const grupoFAgg = buildNamedInFilter("grupo", "grupoAgg", grupoFilter);
    const marcaSql = marcaF.sql;
    const grupoSql = grupoF.sql;

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      for (const [name, value] of marcaF.entries) r = r.input(name, value);
      for (const [name, value] of grupoF.entries) r = r.input(name, value);
      for (const [name, value] of marcaFAgg.entries) r = r.input(name, value);
      for (const [name, value] of grupoFAgg.entries) r = r.input(name, value);
      return r;
    };

    // Stock por marca: dbo.Dash_Inventario_Agregado (pre-agregada, 2.8k-11k filas)
    // en vez de escanear Fact_Inventario (497k filas). El lado de ventas
    // (abajo) sigue en Fact_Ventas_Detalle — esa tabla no tiene columnas de
    // venta, así que el cruce en JS entre stock y ventas por marca se
    // mantiene, pero ahora opera sobre, como mucho, unos cientos de filas
    // por lado en vez de cruzar contra un recordset de 497k.
    const [inventarioRes, salesRes] = await Promise.all([
      req().query(`
        SELECT
          ISNULL(marca, 'SIN MARCA')                    AS marca,
          ISNULL(SUM(stock_total),  0)                  AS stockFisico,
          ISNULL(SUM(valor_total_usd),  0)               AS capitalInvertidoUsd
        FROM dbo.Dash_Inventario_Agregado
        WHERE grupo NOT IN ('LENTES', 'TRATAMIENTOS')
          ${marcaFAgg.sql}
          ${grupoFAgg.sql}
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
        GROUP BY marca
        ORDER BY SUM(stock_total) DESC
      `),

      req().query(`
        SELECT
          ISNULL(dp.Marca, 'SIN MARCA')             AS marca,
          ISNULL(SUM(fvd.cantidad), 0)              AS unidadesVendidas,
          ISNULL(SUM(fvd.total_linea_usd), 0)       AS ventaNetaUsd
        FROM dbo.Fact_Ventas_Detalle fvd
        LEFT JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
        WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${marcaSql}
          ${grupoSql}
          ${buildSucursalFilter("fvd", sucursales, allowedSucursales)}
        GROUP BY dp.Marca
        ORDER BY SUM(fvd.total_linea_usd) DESC
      `),
    ]);

    const invRows = inventarioRes.recordset as InvAggRow[];
    const salesRows = salesRes.recordset as { marca: string; unidadesVendidas: number; ventaNetaUsd: number }[];

    const stockByMarca = new Map(
      invRows.map((r) => [String(r.marca ?? ""), Number(r.stockFisico ?? 0)]),
    );

    // Merge in-memory
    const marcasMap = new Map<string, MarcaItem>();

    salesRows.forEach((r) => {
      const name = String(r.marca ?? "");
      marcasMap.set(name, {
        marca:            name,
        unidadesVendidas: Number(r.unidadesVendidas ?? 0),
        stockFisico:      stockByMarca.get(name) ?? 0,
        ventaNetaUsd:     Number(r.ventaNetaUsd ?? 0),
      });
    });

    invRows.forEach((r) => {
      const name = String(r.marca ?? "");
      if (!marcasMap.has(name)) {
        marcasMap.set(name, {
          marca:            name,
          unidadesVendidas: 0,
          stockFisico:      Number(r.stockFisico ?? 0),
          ventaNetaUsd:     0,
        });
      }
    });

    return Array.from(marcasMap.values()).sort((a, b) => b.unidadesVendidas - a.unidadesVendidas);
  },
  ["dash-inventario-marcas"],
  { revalidate: 3600, tags: ["dash-inventario-marcas"] }
);

export async function getMarcasDetalleData(
  params: Params,
): Promise<{ success: boolean; data?: MarcaItem[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchMarcasDetalle({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getMarcasDetalleData]", err);
    return { success: false, error: "Error al obtener detalle de marcas." };
  }
}

// ─── 3. Grupos Mix ────────────────────────────────────────────────────────────

const fetchGruposMix = unstable_cache(
  async (params: FetchParams): Promise<GrupoMix[]> => {
    const { startDate, endDate, sucursales, marcaFilter, grupoFilter, allowedSucursales } = params;
    const pool = await getConnection();

    const marcaF = buildNamedInFilter("dp.Marca", "marca", marcaFilter);
    const grupoF = buildNamedInFilter("dp.Segmento_Comercial", "grupo", grupoFilter);
    const marcaSql = marcaF.sql;
    const grupoSql = grupoF.sql;

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      for (const [name, value] of marcaF.entries) r = r.input(name, value);
      for (const [name, value] of grupoF.entries) r = r.input(name, value);
      return r;
    };

    // INNER JOIN (no LEFT JOIN) — confirmado con evidencia que "Sin Grupo" eran
    // 100% líneas huérfanas de Fact_Ventas_Detalle sin match en Dim_Productos (no
    // hay casos de producto existente con Segmento_Comercial nulo). Power BI no
    // muestra esas filas en el treemap, así que se excluyen para tener paridad
    // exacta. Se excluye también LENTES/TRATAMIENTOS, mismo filtro que el resto
    // del reporte (Stock Físico/Capital Invertido) — confirmado que quita "Lentes"
    // sin alterar los montos de los demás grupos.
    const res = await req().query(`
      SELECT
        dp.Segmento_Comercial AS grupo,
        ISNULL(SUM(fvd.total_linea_usd), 0)       AS ventaNetaUsd
      FROM dbo.Fact_Ventas_Detalle fvd
      INNER JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
      WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
        AND dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS')
        AND dp.Segmento_Comercial IS NOT NULL AND LTRIM(RTRIM(dp.Segmento_Comercial)) <> ''
        ${marcaSql}
        ${grupoSql}
        ${buildSucursalFilter("fvd", sucursales, allowedSucursales)}
      GROUP BY dp.Segmento_Comercial
      ORDER BY SUM(fvd.total_linea_usd) DESC
    `);

    const rows = res.recordset as { grupo: string; ventaNetaUsd: number }[];
    const totalGrupos = rows.reduce((acc, r) => acc + Number(r.ventaNetaUsd ?? 0), 0);

    return rows.map((r) => ({
      name:       String(r.grupo ?? ""),
      size:       Number(r.ventaNetaUsd ?? 0),
      porcentaje: totalGrupos > 0 ? Math.round((Number(r.ventaNetaUsd ?? 0) / totalGrupos) * 10000) / 100 : 0,
    }));
  },
  ["dash-inventario-grupos-mix"],
  { revalidate: 3600, tags: ["dash-inventario-grupos-mix"] }
);

export async function getGruposMixData(
  params: Params,
): Promise<{ success: boolean; data?: GrupoMix[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchGruposMix({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getGruposMixData]", err);
    return { success: false, error: "Error al obtener mix de grupos comerciales." };
  }
}

// ─── 4. Detalle de Dispersión (Grupos) ────────────────────────────────────────

const fetchDispersionData = unstable_cache(
  async (params: FetchParams): Promise<DispersionItem[]> => {
    const { startDate, endDate, sucursales, marcaFilter, grupoFilter, allowedSucursales } = params;
    const pool = await getConnection();

    const marcaF = buildNamedInFilter("dp.Marca", "marca", marcaFilter);
    const grupoF = buildNamedInFilter("dp.Segmento_Comercial", "grupo", grupoFilter);
    const marcaFAgg = buildNamedInFilter("marca", "marcaAgg", marcaFilter);
    const grupoFAgg = buildNamedInFilter("grupo", "grupoAgg", grupoFilter);
    const marcaSql = marcaF.sql;
    const grupoSql = grupoF.sql;

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      for (const [name, value] of marcaF.entries) r = r.input(name, value);
      for (const [name, value] of grupoF.entries) r = r.input(name, value);
      for (const [name, value] of marcaFAgg.entries) r = r.input(name, value);
      for (const [name, value] of grupoFAgg.entries) r = r.input(name, value);
      return r;
    };

    // Stock por grupo: dbo.Dash_Inventario_Agregado en vez de Fact_Inventario
    // (mismo razonamiento que fetchMarcasDetalle — ver comentario ahí).
    const [inventarioRes, salesRes] = await Promise.all([
      req().query(`
        SELECT
          ISNULL(grupo, 'SIN GRUPO')                    AS grupo,
          ISNULL(SUM(stock_total),  0)                  AS stockFisico,
          ISNULL(SUM(valor_total_usd),  0)               AS capitalInvertidoUsd
        FROM dbo.Dash_Inventario_Agregado
        WHERE grupo NOT IN ('LENTES', 'TRATAMIENTOS')
          ${marcaFAgg.sql}
          ${grupoFAgg.sql}
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
        GROUP BY grupo
      `),

      req().query(`
        SELECT
          ISNULL(dp.Segmento_Comercial, 'SIN GRUPO') AS grupo,
          ISNULL(SUM(fvd.cantidad), 0)              AS unidadesVendidas,
          ISNULL(SUM(fvd.total_linea_usd), 0)       AS ventaNetaUsd
        FROM dbo.Fact_Ventas_Detalle fvd
        LEFT JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
        WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${marcaSql}
          ${grupoSql}
          ${buildSucursalFilter("fvd", sucursales, allowedSucursales)}
        GROUP BY dp.Segmento_Comercial
      `),
    ]);

    const invRows = inventarioRes.recordset as { grupo: string; stockFisico: number; capitalInvertidoUsd: number }[];
    const salesRows = salesRes.recordset as { grupo: string; unidadesVendidas: number; ventaNetaUsd: number }[];

    const stockByGrupo = new Map(
      invRows.map((r) => [String(r.grupo ?? ""), Number(r.stockFisico ?? 0)]),
    );

    const dispersionMap = new Map<string, DispersionItem>();

    salesRows.forEach((r) => {
      const name = String(r.grupo ?? "");
      dispersionMap.set(name, {
        grupo:            name,
        unidadesVendidas: Number(r.unidadesVendidas ?? 0),
        stockFisico:      stockByGrupo.get(name) ?? 0,
        ventaNetaUsd:     Number(r.ventaNetaUsd ?? 0),
      });
    });

    invRows.forEach((r) => {
      const name = String(r.grupo ?? "");
      if (!dispersionMap.has(name)) {
        dispersionMap.set(name, {
          grupo:            name,
          unidadesVendidas: 0,
          stockFisico:      Number(r.stockFisico ?? 0),
          ventaNetaUsd:     0,
        });
      }
    });

    return Array.from(dispersionMap.values()).sort((a, b) => b.unidadesVendidas - a.unidadesVendidas);
  },
  ["dash-inventario-dispersion"],
  { revalidate: 3600, tags: ["dash-inventario-dispersion"] }
);

export async function getDispersionData(
  params: Params,
): Promise<{ success: boolean; data?: DispersionItem[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchDispersionData({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getDispersionData]", err);
    return { success: false, error: "Error al obtener datos de dispersión por grupo." };
  }
}

// ─── 5. Ranking de Rotación por Sucursal (Top 20) ─────────────────────────────
// % Rotación = Unidades Vendidas / Stock Físico. A diferencia de las tarjetas KPI
// de Stock Físico/Capital Invertido (100% sin filtro de fecha), este gráfico SÍ
// reacciona al filtro de fecha — pero solo del lado de Unidades Vendidas, mismo
// patrón ya usado en fetchMarcasDetalle/fetchDispersionData/fetchGruposMix: la
// fecha filtra el lado de Fact_Ventas_Detalle, nunca el de Fact_Inventario (que
// es un acumulado histórico sin serie temporal, no una foto por rango). Marca y
// Grupo sí aplican a ambos lados, igual que en el resto del módulo. Confirmado
// con Gerardo/usuario: Stock Físico acá SÍ excluye Segmento_Comercial
// 'LENTES'/'TRATAMIENTOS' (mismo criterio que la tarjeta KPI ya migrada).

type RotacionStockRow = { id_sucursal: number; nombre_sucursal: string; stockFisico: number };
type RotacionVentasRow = { id_sucursal: number; unidadesVendidas: number };

const fetchRotacionSucursal = unstable_cache(
  async (params: FetchParams): Promise<RotacionSucursal[]> => {
    const { startDate, endDate, sucursales, marcaFilter, grupoFilter, allowedSucursales } = params;
    const pool = await getConnection();

    const marcaF = buildNamedInFilter("dp.Marca", "marca", marcaFilter);
    const grupoF = buildNamedInFilter("dp.Segmento_Comercial", "grupo", grupoFilter);
    const marcaFAgg = buildNamedInFilter("marca", "marcaAgg", marcaFilter);
    const grupoFAgg = buildNamedInFilter("grupo", "grupoAgg", grupoFilter);

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      for (const [name, value] of marcaF.entries) r = r.input(name, value);
      for (const [name, value] of grupoF.entries) r = r.input(name, value);
      for (const [name, value] of marcaFAgg.entries) r = r.input(name, value);
      for (const [name, value] of grupoFAgg.entries) r = r.input(name, value);
      return r;
    };

    // Stock por sucursal: dbo.Dash_Inventario_Agregado (mismo razonamiento que
    // fetchMarcasDetalle/fetchDispersionData). El lado de ventas sigue en
    // Fact_Ventas_Detalle; el cruce en JS + Top 20 se mantiene abajo porque
    // % Rotación depende de ambos lados a la vez (no se puede ordenar por
    // pctRotacion en SQL sin unir ambas fuentes) — con ≤96 sucursales el costo
    // de ese cruce/ordenamiento en memoria es despreciable.
    const [stockRes, ventasRes] = await Promise.all([
      req().query(`
        SELECT
          dia.id_sucursal,
          ms.nombre_sucursal,
          ISNULL(SUM(dia.stock_total), 0) AS stockFisico
        FROM dbo.Dash_Inventario_Agregado dia
        LEFT JOIN dbo.Maestro_Sucursales ms ON dia.id_sucursal = ms.id_sucursal
        WHERE dia.grupo NOT IN ('LENTES', 'TRATAMIENTOS')
          ${marcaFAgg.sql}
          ${grupoFAgg.sql}
          ${buildSucursalFilter("dia", sucursales, allowedSucursales)}
        GROUP BY dia.id_sucursal, ms.nombre_sucursal
      `),

      req().query(`
        SELECT
          fvd.id_sucursal,
          ISNULL(SUM(fvd.cantidad), 0) AS unidadesVendidas
        FROM dbo.Fact_Ventas_Detalle fvd
        LEFT JOIN dbo.Dim_Productos dp ON fvd.id_producto = dp.SK_Producto
        WHERE CAST(fvd.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${marcaF.sql}
          ${grupoF.sql}
          ${buildSucursalFilter("fvd", sucursales, allowedSucursales)}
        GROUP BY fvd.id_sucursal
      `),
    ]);

    const stockRows = stockRes.recordset as RotacionStockRow[];
    const ventasMap = new Map(
      (ventasRes.recordset as RotacionVentasRow[]).map((r) => [Number(r.id_sucursal), Number(r.unidadesVendidas ?? 0)]),
    );

    const merged: RotacionSucursal[] = stockRows.map((r) => {
      const stockFisico = Number(r.stockFisico ?? 0);
      const unidadesVendidas = ventasMap.get(Number(r.id_sucursal)) ?? 0;
      // % Rotación = DIVIDE(Unidades Vendidas, Stock Físico, 0) — 0 si no hay stock, nunca división por cero
      const pctRotacion = stockFisico > 0 ? Math.round((unidadesVendidas / stockFisico) * 10000) / 100 : 0;
      return {
        idSucursal:       Number(r.id_sucursal),
        nombreSucursal:   String(r.nombre_sucursal ?? ""),
        unidadesVendidas,
        stockFisico,
        pctRotacion,
      };
    });

    return merged.sort((a, b) => b.pctRotacion - a.pctRotacion).slice(0, 20);
  },
  ["dash-inventario-rotacion-sucursal"],
  { revalidate: 3600, tags: ["dash-inventario-rotacion-sucursal"] }
);

export async function getRotacionSucursal(
  params: Params,
): Promise<{ success: boolean; data?: RotacionSucursal[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchRotacionSucursal({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getRotacionSucursal]", err);
    return { success: false, error: "Error al obtener ranking de rotación por sucursal." };
  }
}
