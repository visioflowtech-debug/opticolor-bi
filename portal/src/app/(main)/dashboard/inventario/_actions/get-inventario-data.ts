"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter, buildNamedInFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type InventarioKpis = {
  stockFisico: number;
  capitalInvertidoUsd: number;
  unidadesVendidas: number;
  ventaNetaProducto: number;
  upt: number;
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



    // Filtros dimensionales compartidos — alias dp presente en stock (fi LEFT JOIN dp) y ventas (dvr LEFT JOIN dp)
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

    const [inventarioRes, salesRes, facturasRes] = await Promise.all([
      // C-5.1 / C-5.2 · Stock y Capital — direct query on Fact_Inventario (acumulados históricos sin snapshot temporal)
      // Sin filtro de fecha — confirmado que ya cumple la paridad con Power BI (no
      // reacciona al slicer de fecha), no se le agrega ninguno.
      req().query(`
        SELECT
          ISNULL(SUM(fi.cantidad_disponible), 0) AS stockFisico,
          ISNULL(SUM(fi.valor_total_inventario_usd), 0) AS capitalInvertidoUsd
        FROM dbo.Fact_Inventario fi
        LEFT JOIN dbo.Dim_Productos dp ON fi.id_producto = dp.SK_Producto
        WHERE (dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS') OR dp.Segmento_Comercial IS NULL)
          ${buildSucursalFilter("fi", sucursales, allowedSucursales)}
          ${marcaSql}
          ${grupoSql}
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

    const inv    = inventarioRes.recordset[0] ?? { stockFisico: 0, capitalInvertidoUsd: 0 };
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

    const [inventarioRes, salesRes] = await Promise.all([
      req().query(`
        SELECT
          ISNULL(dp.Marca, 'SIN MARCA')                 AS marca,
          ISNULL(SUM(fi.cantidad_disponible),  0)       AS stockFisico,
          ISNULL(SUM(fi.valor_total_inventario_usd),  0) AS capitalInvertidoUsd
        FROM dbo.Fact_Inventario fi
        LEFT JOIN dbo.Dim_Productos dp ON fi.id_producto = dp.SK_Producto
        WHERE (dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS') OR dp.Segmento_Comercial IS NULL)
          ${marcaSql}
          ${grupoSql}
          ${buildSucursalFilter("fi", sucursales, allowedSucursales)}
        GROUP BY dp.Marca
        ORDER BY SUM(fi.cantidad_disponible) DESC
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

    const [inventarioRes, salesRes] = await Promise.all([
      req().query(`
        SELECT
          ISNULL(dp.Segmento_Comercial, 'SIN GRUPO')    AS grupo,
          ISNULL(SUM(fi.cantidad_disponible),  0)       AS stockFisico,
          ISNULL(SUM(fi.valor_total_inventario_usd),  0) AS capitalInvertidoUsd
        FROM dbo.Fact_Inventario fi
        LEFT JOIN dbo.Dim_Productos dp ON fi.id_producto = dp.SK_Producto
        WHERE (dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS') OR dp.Segmento_Comercial IS NULL)
          ${marcaSql}
          ${grupoSql}
          ${buildSucursalFilter("fi", sucursales, allowedSucursales)}
        GROUP BY dp.Segmento_Comercial
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
