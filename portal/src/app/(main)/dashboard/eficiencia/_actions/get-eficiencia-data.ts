"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";
import { MAP_MES_NAME_TO_ABBR as MES_ABBR } from "@/lib/date-utils";

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type EficienciaKpis = {
  ordenesHoy: number;
  volumenOrdenes: number;
  promedioDiario: number;
  montoTotalUsd: number;
};

export type TendenciaOrden = {
  mes_nombre: string;
  volumen_ordenes: number;
};

export type TipoLenteDetalle = {
  tipo_lente_descripcion: string;
  volumen_ordenes: number;
  monto_total_usd: number;
};

export type OrdenesSucursal = {
  nombre_sucursal: string;
  volumen_ordenes: number;
};

import { ReportParams } from "@/types/dashboard";

export type Params = ReportParams;

type FetchParams = Params & { allowedSucursales: string };

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type ValorRow        = { valor: number };
type PeriodoStatsRow = { volumen_ordenes: number; monto_total_usd: number; promedio_ordenes_diarias: number };
type TendenciaRow    = { periodo: string; anio: number; mes_nombre: string; volumen_ordenes: number };
type TipoLenteRow    = { tipo_lente_descripcion: string; volumen_ordenes: number; monto_total_usd: number };
type SucursalRow     = { nombre_sucursal: string; volumen_ordenes: number };



// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchEficienciaKPIs = unstable_cache(
  async (params: FetchParams): Promise<EficienciaKpis> => {
    const { startDate, endDate, sucursales, allowedSucursales } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales);

    const [ordenesHoyRes, periodoStatsRes] = await Promise.all([
      // C-3.1 Órdenes Hoy — pedidos únicos con zona horaria Venezuela (GMT-4)
      req().query(`
        SELECT COUNT(DISTINCT id_pedido) AS valor
        FROM dbo.Fact_Eficiencia_Ordenes
        WHERE CAST(fecha_pedido AS DATE) = CAST(SWITCHOFFSET(TODATETIMEOFFSET(GETDATE(), '+00:00'), '-04:00') AS DATE)
          ${buildSucursalFilter()}
      `),

      // C-3.2 Volumen + C-3.3 Promedio Diario — COUNTA semántico (filas, no pedidos únicos)
      req().query(`
        SELECT
          COUNT(f.id_pedido)                                                              AS volumen_ordenes,
          ISNULL(SUM(f.monto_total_usd), 0)                                              AS monto_total_usd,
          COUNT(f.id_pedido) * 1.0 / NULLIF(COUNT(DISTINCT f.fecha_pedido), 0)          AS promedio_ordenes_diarias
        FROM dbo.Fact_Eficiencia_Ordenes f
        WHERE CAST(f.fecha_pedido AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${buildSucursalFilter("f")}
      `),
    ]);

    const stats = (periodoStatsRes.recordset as PeriodoStatsRow[])[0]
      ?? { volumen_ordenes: 0, promedio_ordenes_diarias: 0, monto_total_usd: 0 };

    return {
      ordenesHoy:     Number((ordenesHoyRes.recordset as ValorRow[])[0]?.valor ?? 0),
      volumenOrdenes: Number(stats.volumen_ordenes ?? 0),
      promedioDiario: Math.floor(Number(stats.promedio_ordenes_diarias ?? 0)),
      montoTotalUsd:  Math.round(Number(stats.monto_total_usd ?? 0) * 100) / 100,
    };
  },
  ["dash-eficiencia-kpis"],
  { revalidate: 3600, tags: ["dash-eficiencia-kpis"] }
);

export async function getEficienciaKPIs(
  params: Params,
): Promise<{ success: boolean; data?: EficienciaKpis; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchEficienciaKPIs({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getEficienciaKPIs]", err);
    return { success: false, error: "Error al obtener KPIs de eficiencia." };
  }
}

// ─── 2. Tendencia ────────────────────────────────────────────────────────────

const fetchTendenciaOrden = unstable_cache(
  async (params: FetchParams): Promise<TendenciaOrden[]> => {
    const { endDate, sucursales, allowedSucursales } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales);

    const res = await req().query(`
      SELECT
        YEAR(f.fecha_pedido)                 AS anio,
        f.periodo                            AS periodo,
        DATENAME(MONTH, MIN(f.fecha_pedido)) AS mes_nombre,
        COUNT(f.id_pedido)                   AS volumen_ordenes
      FROM dbo.Fact_Eficiencia_Ordenes f
      WHERE CAST(f.fecha_pedido AS DATE) >= DATEADD(MONTH, -12, CAST(@endDate AS DATE))
        AND CAST(f.fecha_pedido AS DATE) <= CAST(@endDate AS DATE)
        AND ISNULL(NULLIF(RTRIM(LTRIM(f.tipo_lente_descripcion)), ''), 'No Definido') IS NOT NULL
        ${buildSucursalFilter("f")}
      GROUP BY YEAR(f.fecha_pedido), f.periodo
      ORDER BY f.periodo ASC
    `);

    return (res.recordset as TendenciaRow[]).map((r) => ({
      mes_nombre:      `${MES_ABBR[r.mes_nombre] ?? r.mes_nombre} '${String(r.anio).slice(2)}`,
      volumen_ordenes: Number(r.volumen_ordenes ?? 0),
    }));
  },
  ["dash-eficiencia-tendencia"],
  { revalidate: 3600, tags: ["dash-eficiencia-tendencia"] }
);

export async function getTendenciaOrden(
  params: Params,
): Promise<{ success: boolean; data?: TendenciaOrden[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchTendenciaOrden({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTendenciaOrden]", err);
    return { success: false, error: "Error al obtener tendencia de órdenes." };
  }
}

// ─── 3. Tipo de Lente ─────────────────────────────────────────────────────────

const fetchTipoLente = unstable_cache(
  async (params: FetchParams): Promise<TipoLenteDetalle[]> => {
    const { startDate, endDate, sucursales, allowedSucursales } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales);

    const res = await req().query(`
      SELECT
        ISNULL(NULLIF(RTRIM(LTRIM(f.tipo_lente_descripcion)), ''), 'No Definido') AS tipo_lente_descripcion,
        COUNT(f.id_pedido)                                                          AS volumen_ordenes,
        ISNULL(SUM(f.monto_total_usd), 0)                                          AS monto_total_usd
      FROM dbo.Fact_Eficiencia_Ordenes f
      WHERE CAST(f.fecha_pedido AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
        ${buildSucursalFilter("f")}
      GROUP BY RTRIM(LTRIM(f.tipo_lente_descripcion))
      ORDER BY volumen_ordenes DESC
    `);

    return (res.recordset as TipoLenteRow[]).map((r) => ({
      tipo_lente_descripcion: String(r.tipo_lente_descripcion ?? ""),
      volumen_ordenes:        Number(r.volumen_ordenes ?? 0),
      monto_total_usd:        Number(r.monto_total_usd ?? 0),
    }));
  },
  ["dash-eficiencia-tipo-lente"],
  { revalidate: 3600, tags: ["dash-eficiencia-tipo-lente"] }
);

export async function getTipoLente(
  params: Params,
): Promise<{ success: boolean; data?: TipoLenteDetalle[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchTipoLente({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTipoLente]", err);
    return { success: false, error: "Error al obtener tipo de lente." };
  }
}

// ─── 4. Órdenes por Sucursal ──────────────────────────────────────────────────

const fetchOrdenesSucursal = unstable_cache(
  async (params: FetchParams): Promise<OrdenesSucursal[]> => {
    const { startDate, endDate, sucursales, allowedSucursales } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales);

    const res = await req().query(`
      SELECT
        ds.nombre_sucursal,
        COUNT(f.id_pedido) AS volumen_ordenes
      FROM dbo.Fact_Eficiencia_Ordenes f
      LEFT JOIN dbo.Dim_Sucursales ds ON f.id_sucursal = ds.id_sucursal
      WHERE CAST(f.fecha_pedido AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
        ${buildSucursalFilter("f")}
      GROUP BY ds.nombre_sucursal
      ORDER BY volumen_ordenes DESC
    `);

    return (res.recordset as SucursalRow[]).map((r) => ({
      nombre_sucursal: String(r.nombre_sucursal ?? ""),
      volumen_ordenes: Number(r.volumen_ordenes ?? 0),
    }));
  },
  ["dash-eficiencia-ordenes-sucursal"],
  { revalidate: 3600, tags: ["dash-eficiencia-ordenes-sucursal"] }
);

export async function getOrdenesSucursal(
  params: Params,
): Promise<{ success: boolean; data?: OrdenesSucursal[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchOrdenesSucursal({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getOrdenesSucursal]", err);
    return { success: false, error: "Error al obtener órdenes por sucursal." };
  }
}
