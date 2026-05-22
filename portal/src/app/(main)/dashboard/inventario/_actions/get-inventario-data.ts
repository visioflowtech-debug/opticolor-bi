"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type InventarioKpis = {
  stockFisico: number;
  capitalInvertido: number;
  unidadesVendidas: number;
  ventaNetaProducto: number;
  cantidadFacturas: number;
};

export type MarcaItem = {
  marca: string;
  unidadesVendidas: number;
  stockFisico: number;
  ventaNeta: number;
};

export type GrupoMix = {
  name: string;
  size: number;       // ventaNeta — Recharts Treemap usa este campo para el área
  porcentaje: number; // 1 decimal
};

export type Params = {
  startDate: string;
  endDate: string;
  sucursales: string | null;   // IDs separados por coma, null = todas
  marcaFilter: string | null;  // nombres separados por coma, null = todas
  grupoFilter: string | null;  // nombres separados por coma, null = todos
};

type FetchParams = Params & { allowedSucursales: string; isSupervisor: boolean };

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type InvAggRow = {
  marca: string;
  stockFisico: number;
  capitalInvertido: number;
};

type VentaFusedRow = {
  marca: string | null;
  grupo: string | null;
  unidadesVendidas: number;
  ventaNeta: number;
};

type ValorRow = { valor: number };

const EXCLUSION = `AND dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS')`;

// Helper: Blindaje de Filtros Vacíos/Globales ("TODOS", "%")
const isAll = (val: string | null) => !val || val.toUpperCase() === 'TODOS' || val === '%';

// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchInventarioKPIs = unstable_cache(
  async (params: FetchParams): Promise<InventarioKpis> => {
    const { startDate, endDate, sucursales, marcaFilter, grupoFilter, allowedSucursales, isSupervisor } = params;
    const pool = await getConnection();

    const marcaSqlAgg = !isAll(marcaFilter)
      ? "AND fi.Marca IN (SELECT value FROM STRING_SPLIT(@marcaFilter, ','))"
      : "";
    const grupoSqlAgg = !isAll(grupoFilter)
      ? "AND fi.Segmento_Comercial IN (SELECT value FROM STRING_SPLIT(@grupoFilter, ','))"
      : "";
    const marcaSql = !isAll(marcaFilter)
      ? "AND dp.Marca IN (SELECT value FROM STRING_SPLIT(@marcaFilter, ','))"
      : "";

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("isSupervisor", isSupervisor ? 1 : 0);
      if (marcaFilter) r = r.input("marcaFilter", marcaFilter);
      if (grupoFilter) r = r.input("grupoFilter", grupoFilter);
      return r;
    };

    const [inventarioRes, salesRes, facturasRes] = await Promise.all([
      req().query(`
        DECLARE @snapshotDate DATE = (
          SELECT MAX(fi_inner.fecha_foto_date)
          FROM dbo.Fact_Inventario fi_inner
          WHERE fi_inner.fecha_foto_date <= @endDate
            AND fi_inner.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS')
            ${buildSucursalFilter("fi_inner")}
        );

        SELECT
          ISNULL(SUM(fi.cantidad_disponible),  0)       AS stockFisico,
          ISNULL(SUM(fi.valor_total_inventario),  0)    AS capitalInvertido
        FROM dbo.Fact_Inventario fi
        WHERE fi.fecha_foto_date = @snapshotDate
          AND fi.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS')
          ${marcaSqlAgg}
          ${grupoSqlAgg}
          ${buildSucursalFilter("fi")}
      `),

      req().query(`
        SELECT
          ISNULL(SUM(dvr.cantidad), 0)              AS unidadesVendidas,
          ISNULL(SUM(dvr.monto_total), 0)           AS ventaNeta
        FROM dbo.Dash_Ventas_Resumen dvr
        INNER JOIN dbo.Dim_Productos dp ON dvr.id_producto = dp.SK_Producto
        WHERE dvr.fecha_factura >= @startDate
          AND dvr.fecha_factura <= @endDate
          ${EXCLUSION}
          ${marcaSql}
          AND dp.Marca IS NOT NULL AND dp.Marca <> ''
          AND dp.Segmento_Comercial IS NOT NULL AND dp.Segmento_Comercial <> ''
          ${buildSucursalFilter("dvr")}
      `),

      req().query(`
        SELECT COUNT(DISTINCT id_factura) AS valor
        FROM dbo.KPI_Inf1_Cantidad_Facturas
        WHERE fecha_factura >= @startDate
          AND fecha_factura <= @endDate
          ${buildSucursalFilter()}
      `),
    ]);

    const inv = inventarioRes.recordset[0] ?? { stockFisico: 0, capitalInvertido: 0 };
    const sales = salesRes.recordset[0] ?? { unidadesVendidas: 0, ventaNeta: 0 };

    return {
      stockFisico:       Number(inv.stockFisico ?? 0),
      capitalInvertido:  Number(inv.capitalInvertido ?? 0),
      unidadesVendidas:  Number(sales.unidadesVendidas ?? 0),
      ventaNetaProducto: Number(sales.ventaNeta ?? 0),
      cantidadFacturas:  Number((facturasRes.recordset as ValorRow[])[0]?.valor ?? 0),
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
    const data = await fetchInventarioKPIs({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getInventarioKPIs]", err);
    return { success: false, error: "Error al obtener KPIs de inventario." };
  }
}

// ─── 2. Detalle de Marcas ─────────────────────────────────────────────────────

const fetchMarcasDetalle = unstable_cache(
  async (params: FetchParams): Promise<MarcaItem[]> => {
    const { startDate, endDate, sucursales, marcaFilter, grupoFilter, allowedSucursales, isSupervisor } = params;
    const pool = await getConnection();

    const marcaSqlAgg = !isAll(marcaFilter)
      ? "AND fi.Marca IN (SELECT value FROM STRING_SPLIT(@marcaFilter, ','))"
      : "";
    const grupoSqlAgg = !isAll(grupoFilter)
      ? "AND fi.Segmento_Comercial IN (SELECT value FROM STRING_SPLIT(@grupoFilter, ','))"
      : "";
    const marcaSql = !isAll(marcaFilter)
      ? "AND dp.Marca IN (SELECT value FROM STRING_SPLIT(@marcaFilter, ','))"
      : "";

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("isSupervisor", isSupervisor ? 1 : 0);
      if (marcaFilter) r = r.input("marcaFilter", marcaFilter);
      if (grupoFilter) r = r.input("grupoFilter", grupoFilter);
      return r;
    };

    const [inventarioRes, salesRes] = await Promise.all([
      req().query(`
        DECLARE @snapshotDate DATE = (
          SELECT MAX(fi_inner.fecha_foto_date)
          FROM dbo.Fact_Inventario fi_inner
          WHERE fi_inner.fecha_foto_date <= @endDate
            AND fi_inner.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS')
            ${buildSucursalFilter("fi_inner")}
        );

        SELECT
          fi.Marca                                      AS marca,
          ISNULL(SUM(fi.cantidad_disponible),  0)       AS stockFisico,
          ISNULL(SUM(fi.valor_total_inventario),  0)    AS capitalInvertido
        FROM dbo.Fact_Inventario fi
        WHERE fi.fecha_foto_date = @snapshotDate
          AND fi.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS')
          ${marcaSqlAgg}
          ${grupoSqlAgg}
          ${buildSucursalFilter("fi")}
        GROUP BY fi.Marca
        ORDER BY SUM(fi.cantidad_disponible) DESC
      `),

      req().query(`
        SELECT
          dp.Marca                                  AS marca,
          ISNULL(SUM(dvr.cantidad), 0)              AS unidadesVendidas,
          ISNULL(SUM(dvr.monto_total), 0)           AS ventaNeta
        FROM dbo.Dash_Ventas_Resumen dvr
        INNER JOIN dbo.Dim_Productos dp ON dvr.id_producto = dp.SK_Producto
        WHERE dvr.fecha_factura >= @startDate
          AND dvr.fecha_factura <= @endDate
          ${EXCLUSION}
          ${marcaSql}
          AND dp.Marca IS NOT NULL AND dp.Marca <> ''
          AND dp.Segmento_Comercial IS NOT NULL AND dp.Segmento_Comercial <> ''
          ${buildSucursalFilter("dvr")}
        GROUP BY dp.Marca
        ORDER BY SUM(dvr.monto_total) DESC
      `),
    ]);

    const invRows = inventarioRes.recordset as InvAggRow[];
    const salesRows = salesRes.recordset as { marca: string; unidadesVendidas: number; ventaNeta: number }[];

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
        ventaNeta:        Number(r.ventaNeta ?? 0),
      });
    });

    invRows.forEach((r) => {
      const name = String(r.marca ?? "");
      if (!marcasMap.has(name)) {
        marcasMap.set(name, {
          marca:            name,
          unidadesVendidas: 0,
          stockFisico:      Number(r.stockFisico ?? 0),
          ventaNeta:        0,
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
    const data = await fetchMarcasDetalle({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getMarcasDetalleData]", err);
    return { success: false, error: "Error al obtener detalle de marcas." };
  }
}

// ─── 3. Grupos Mix ────────────────────────────────────────────────────────────

const fetchGruposMix = unstable_cache(
  async (params: FetchParams): Promise<GrupoMix[]> => {
    const { startDate, endDate, sucursales, allowedSucursales, isSupervisor } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("isSupervisor", isSupervisor ? 1 : 0);

    const res = await req().query(`
      SELECT
        dp.Segmento_Comercial                     AS grupo,
        ISNULL(SUM(dvr.monto_total), 0)           AS ventaNeta
      FROM dbo.Dash_Ventas_Resumen dvr
      INNER JOIN dbo.Dim_Productos dp ON dvr.id_producto = dp.SK_Producto
      WHERE dvr.fecha_factura >= @startDate
        AND dvr.fecha_factura <= @endDate
        ${EXCLUSION}
        AND dp.Segmento_Comercial IS NOT NULL AND dp.Segmento_Comercial <> ''
        ${buildSucursalFilter("dvr")}
      GROUP BY dp.Segmento_Comercial
      ORDER BY SUM(dvr.monto_total) DESC
    `);

    const rows = res.recordset as { grupo: string; ventaNeta: number }[];
    const totalGrupos = rows.reduce((acc, r) => acc + Number(r.ventaNeta ?? 0), 0);

    return rows.map((r) => ({
      name:       String(r.grupo ?? ""),
      size:       Number(r.ventaNeta ?? 0),
      porcentaje: totalGrupos > 0 ? Math.round((Number(r.ventaNeta ?? 0) / totalGrupos) * 10000) / 100 : 0,
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
    const data = await fetchGruposMix({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getGruposMixData]", err);
    return { success: false, error: "Error al obtener mix de grupos comerciales." };
  }
}
