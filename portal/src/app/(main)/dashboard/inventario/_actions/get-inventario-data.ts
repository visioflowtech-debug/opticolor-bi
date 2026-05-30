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
  upt: number;
  asp: number;
  /** C-5.6 · Volumen analítico total (Dash_Ventas_Resumen sin join de dimensión) — métrica de control cruzado */
  volumenUnidades: number;
};

export type MarcaItem = {
  marca: string;
  unidadesVendidas: number;
  stockFisico: number;
  ventaNeta: number;
};

export type DispersionItem = {
  grupo: string;
  unidadesVendidas: number;
  stockFisico: number;
  ventaNeta: number;
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
  capitalInvertido: number;
};

type VentaFusedRow = {
  marca: string | null;
  grupo: string | null;
  unidadesVendidas: number;
  ventaNeta: number;
};

// Helper: Blindaje de Filtros Vacíos/Globales ("TODOS", "%")
const isAll = (val: string | null | undefined) => !val || val.toUpperCase() === 'TODOS' || val === '%';

// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchInventarioKPIs = unstable_cache(
  async (params: FetchParams): Promise<InventarioKpis> => {
    const { startDate, endDate, sucursales, marcaFilter, grupoFilter, allowedSucursales } = params;
    const pool = await getConnection();



    // Filtros dimensionales compartidos — alias dp presente en stock (fi LEFT JOIN dp) y ventas (dvr LEFT JOIN dp)
    const marcaSql = !isAll(marcaFilter)
      ? "AND dp.Marca IN (SELECT value FROM STRING_SPLIT(@marcaFilter, ','))"
      : "";
    const grupoSql = !isAll(grupoFilter)
      ? "AND dp.Segmento_Comercial IN (SELECT value FROM STRING_SPLIT(@grupoFilter, ','))"
      : "";

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      if (marcaFilter) r = r.input("marcaFilter", marcaFilter);
      if (grupoFilter) r = r.input("grupoFilter", grupoFilter);
      return r;
    };

    const [inventarioRes, salesRes, volumenRes] = await Promise.all([
      // C-5.1 / C-5.2 · Stock y Capital — direct query on Fact_Inventario (acumulados históricos sin snapshot temporal)
      req().query(`
        SELECT
          ISNULL(SUM(fi.cantidad_disponible), 0) AS stockFisico,
          ISNULL(SUM(fi.valor_total_inventario), 0) AS capitalInvertido
        FROM dbo.Fact_Inventario fi
        LEFT JOIN dbo.Dim_Productos dp ON fi.id_producto = dp.SK_Producto
        WHERE (dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS') OR dp.Segmento_Comercial IS NULL)
          ${buildSucursalFilter("fi")}
          ${marcaSql}
          ${grupoSql}
      `),

      // C-5.3 / UPT / ASP · LEFT JOIN recupera líneas huérfanas y no excluye "LENTES" / "TRATAMIENTOS" (volumen bruto)
      req().query(`
        SELECT
          ISNULL(SUM(dvr.cantidad), 0)                                     AS unidadesVendidas,
          ISNULL(SUM(dvr.monto_total), 0)                                  AS ventaNetaProducto,
          ROUND(
            CAST(SUM(dvr.cantidad) AS decimal(18,4)) /
            NULLIF(COUNT(DISTINCT dvr.id_factura), 0),
          4)                                                               AS upt,
          ROUND(
            ISNULL(SUM(dvr.monto_total), 0) /
            NULLIF(SUM(dvr.cantidad), 0),
          4)                                                               AS asp
        FROM dbo.Dash_Ventas_Resumen dvr
        LEFT JOIN dbo.Dim_Productos dp ON dvr.id_producto = dp.SK_Producto
        WHERE CAST(dvr.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${buildSucursalFilter("dvr")}
          ${marcaSql}
          ${grupoSql}
      `),

      // C-5.6 · Volumen analítico de control: total transaccional sin join de Dim_Productos
      // Sirve como validación cruzada contra unidadesVendidas (que filtra por segmento)
      req().query(`
        SELECT ISNULL(SUM(dvr.cantidad), 0) AS volumenUnidades
        FROM dbo.Dash_Ventas_Resumen dvr
        WHERE CAST(dvr.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${buildSucursalFilter("dvr")}
      `),
    ]);

    const inv    = inventarioRes.recordset[0] ?? { stockFisico: 0, capitalInvertido: 0 };
    const sales  = salesRes.recordset[0] ?? { unidadesVendidas: 0, ventaNetaProducto: 0, upt: 0, asp: 0 };
    const vol    = volumenRes.recordset[0] ?? { volumenUnidades: 0 };

    return {
      stockFisico:       Number(inv.stockFisico ?? 0),
      capitalInvertido:  Number(inv.capitalInvertido ?? 0),
      unidadesVendidas:  Number(sales.unidadesVendidas ?? 0),
      ventaNetaProducto: Number(sales.ventaNetaProducto ?? 0),
      upt:               Number(sales.upt ?? 0),
      asp:               Number(sales.asp ?? 0),
      volumenUnidades:   Number(vol.volumenUnidades ?? 0),
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

    const marcaSql = !isAll(marcaFilter)
      ? "AND dp.Marca IN (SELECT value FROM STRING_SPLIT(@marcaFilter, ','))"
      : "";
    const grupoSql = !isAll(grupoFilter)
      ? "AND dp.Segmento_Comercial IN (SELECT value FROM STRING_SPLIT(@grupoFilter, ','))"
      : "";

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      if (marcaFilter) r = r.input("marcaFilter", marcaFilter);
      if (grupoFilter) r = r.input("grupoFilter", grupoFilter);
      return r;
    };

    const [inventarioRes, salesRes] = await Promise.all([
      req().query(`
        SELECT
          ISNULL(dp.Marca, 'SIN MARCA')                 AS marca,
          ISNULL(SUM(fi.cantidad_disponible),  0)       AS stockFisico,
          ISNULL(SUM(fi.valor_total_inventario),  0)    AS capitalInvertido
        FROM dbo.Fact_Inventario fi
        LEFT JOIN dbo.Dim_Productos dp ON fi.id_producto = dp.SK_Producto
        WHERE (dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS') OR dp.Segmento_Comercial IS NULL)
          ${marcaSql}
          ${grupoSql}
          ${buildSucursalFilter("fi")}
        GROUP BY dp.Marca
        ORDER BY SUM(fi.cantidad_disponible) DESC
      `),

      req().query(`
        SELECT
          ISNULL(dp.Marca, 'SIN MARCA')             AS marca,
          ISNULL(SUM(dvr.cantidad), 0)              AS unidadesVendidas,
          ISNULL(SUM(dvr.monto_total), 0)           AS ventaNeta
        FROM dbo.Dash_Ventas_Resumen dvr
        LEFT JOIN dbo.Dim_Productos dp ON dvr.id_producto = dp.SK_Producto
        WHERE CAST(dvr.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${marcaSql}
          ${grupoSql}
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

    const marcaSql = !isAll(marcaFilter)
      ? "AND dp.Marca IN (SELECT value FROM STRING_SPLIT(@marcaFilter, ','))"
      : "";
    const grupoSql = !isAll(grupoFilter)
      ? "AND dp.Segmento_Comercial IN (SELECT value FROM STRING_SPLIT(@grupoFilter, ','))"
      : "";

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      if (marcaFilter) r = r.input("marcaFilter", marcaFilter);
      if (grupoFilter) r = r.input("grupoFilter", grupoFilter);
      return r;
    };

    const res = await req().query(`
      SELECT
        ISNULL(dp.Segmento_Comercial, 'SIN GRUPO') AS grupo,
        ISNULL(SUM(dvr.monto_total), 0)           AS ventaNeta
      FROM dbo.Dash_Ventas_Resumen dvr
      LEFT JOIN dbo.Dim_Productos dp ON dvr.id_producto = dp.SK_Producto
      WHERE CAST(dvr.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
        ${marcaSql}
        ${grupoSql}
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

    const marcaSql = !isAll(marcaFilter)
      ? "AND dp.Marca IN (SELECT value FROM STRING_SPLIT(@marcaFilter, ','))"
      : "";
    const grupoSql = !isAll(grupoFilter)
      ? "AND dp.Segmento_Comercial IN (SELECT value FROM STRING_SPLIT(@grupoFilter, ','))"
      : "";

    const req = () => {
      let r = pool
        .request()
        .input("startDate",    startDate)
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales);
      if (marcaFilter) r = r.input("marcaFilter", marcaFilter);
      if (grupoFilter) r = r.input("grupoFilter", grupoFilter);
      return r;
    };

    const [inventarioRes, salesRes] = await Promise.all([
      req().query(`
        SELECT
          ISNULL(dp.Segmento_Comercial, 'SIN GRUPO')    AS grupo,
          ISNULL(SUM(fi.cantidad_disponible),  0)       AS stockFisico,
          ISNULL(SUM(fi.valor_total_inventario),  0)    AS capitalInvertido
        FROM dbo.Fact_Inventario fi
        LEFT JOIN dbo.Dim_Productos dp ON fi.id_producto = dp.SK_Producto
        WHERE (dp.Segmento_Comercial NOT IN ('LENTES', 'TRATAMIENTOS') OR dp.Segmento_Comercial IS NULL)
          ${marcaSql}
          ${grupoSql}
          ${buildSucursalFilter("fi")}
        GROUP BY dp.Segmento_Comercial
      `),

      req().query(`
        SELECT
          ISNULL(dp.Segmento_Comercial, 'SIN GRUPO') AS grupo,
          ISNULL(SUM(dvr.cantidad), 0)              AS unidadesVendidas,
          ISNULL(SUM(dvr.monto_total), 0)           AS ventaNeta
        FROM dbo.Dash_Ventas_Resumen dvr
        LEFT JOIN dbo.Dim_Productos dp ON dvr.id_producto = dp.SK_Producto
        WHERE CAST(dvr.fecha_factura AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${marcaSql}
          ${grupoSql}
          ${buildSucursalFilter("dvr")}
        GROUP BY dp.Segmento_Comercial
      `),
    ]);

    const invRows = inventarioRes.recordset as { grupo: string; stockFisico: number; capitalInvertido: number }[];
    const salesRows = salesRes.recordset as { grupo: string; unidadesVendidas: number; ventaNeta: number }[];

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
        ventaNeta:        Number(r.ventaNeta ?? 0),
      });
    });

    invRows.forEach((r) => {
      const name = String(r.grupo ?? "");
      if (!dispersionMap.has(name)) {
        dispersionMap.set(name, {
          grupo:            name,
          unidadesVendidas: 0,
          stockFisico:      Number(r.stockFisico ?? 0),
          ventaNeta:        0,
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
