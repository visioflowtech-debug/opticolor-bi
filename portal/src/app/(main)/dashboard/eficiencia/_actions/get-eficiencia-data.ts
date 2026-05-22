"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type EficienciaKpis = {
  ordenesHoy: number;
  volumenOrdenes: number;
  promedioDiario: number;
  montoTotal: number;
};

export type TendenciaOrden = {
  mes_nombre: string;
  volumen_ordenes: number;
};

export type TipoLenteDetalle = {
  tipo_lente_descripcion: string;
  volumen_ordenes: number;
  monto_total: number;
};

export type OrdenesSucursal = {
  nombre_sucursal: string;
  volumen_ordenes: number;
};

export type Params = {
  startDate: string; // "YYYY-MM-DD"
  endDate: string;   // "YYYY-MM-DD"
  sucursales: string | null; // IDs separados por coma, null = todas
};

type FetchParams = Params & { allowedSucursales: string; isSupervisor: boolean };

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type ValorRow        = { valor: number };
type PeriodoStatsRow = { volumen_ordenes: number; monto_total: number; promedio_ordenes_diarias: number };
type TendenciaRow    = { periodo: string; volumen_ordenes: number };
type TipoLenteRow    = { tipo_lente_descripcion: string; volumen_ordenes: number; monto_total: number };
type SucursalRow     = { nombre_sucursal: string; volumen_ordenes: number };

const MESES = [
  "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
  "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
];

// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchEficienciaKPIs = unstable_cache(
  async (params: FetchParams): Promise<EficienciaKpis> => {
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

    const [ordenesHoyRes, periodoStatsRes] = await Promise.all([
      req().query(`
        SELECT ISNULL(SUM(dea.total_ordenes), 0) AS valor
        FROM dbo.Dash_Eficiencia_Agregado dea
        WHERE dea.fecha_pedido = CAST(GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'SA Western Standard Time' AS DATE)
          ${buildSucursalFilter("dea")}
      `),
      req().query(`
        SELECT
          ISNULL(SUM(dea.total_ordenes), 0)                                           AS volumen_ordenes,
          ISNULL(SUM(dea.monto_total),   0)                                           AS monto_total,
          ISNULL(
            SUM(dea.total_ordenes) * 1.0 / NULLIF(COUNT(DISTINCT dea.fecha_pedido), 0),
            0
          )                                                                            AS promedio_ordenes_diarias
        FROM dbo.Dash_Eficiencia_Agregado dea
        WHERE dea.fecha_pedido BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("dea")}
      `),
    ]);

    const stats = (periodoStatsRes.recordset as PeriodoStatsRow[])[0]
      ?? { volumen_ordenes: 0, promedio_ordenes_diarias: 0, monto_total: 0 };

    return {
      ordenesHoy:     Number((ordenesHoyRes.recordset as ValorRow[])[0]?.valor ?? 0),
      volumenOrdenes: Number(stats.volumen_ordenes ?? 0),
      promedioDiario: Math.round(Number(stats.promedio_ordenes_diarias ?? 0) * 100) / 100,
      montoTotal:     Math.round(Number(stats.monto_total ?? 0) * 100) / 100,
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
    const data = await fetchEficienciaKPIs({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getEficienciaKPIs]", err);
    return { success: false, error: "Error al obtener KPIs de eficiencia." };
  }
}

// ─── 2. Tendencia ────────────────────────────────────────────────────────────

const fetchTendenciaOrden = unstable_cache(
  async (params: FetchParams): Promise<TendenciaOrden[]> => {
    const { endDate, sucursales, allowedSucursales, isSupervisor } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("endDate",      endDate)
        .input("sucursales",   sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("isSupervisor", isSupervisor ? 1 : 0);

    const res = await req().query(`
      SELECT
        dea.periodo                           AS periodo,
        ISNULL(SUM(dea.total_ordenes), 0)     AS volumen_ordenes
      FROM dbo.Dash_Eficiencia_Agregado dea
      WHERE dea.fecha_pedido >= DATEADD(MONTH, -12, CAST(@endDate AS DATE))
        AND dea.fecha_pedido <= CAST(@endDate AS DATE)
        ${buildSucursalFilter("dea")}
      GROUP BY dea.periodo
      ORDER BY dea.periodo ASC
    `);

    return (res.recordset as { periodo: string; volumen_ordenes: number }[]).map((r) => ({
      mes_nombre:      MESES[parseInt(r.periodo.slice(5, 7), 10) - 1] ?? r.periodo,
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
    const data = await fetchTendenciaOrden({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTendenciaOrden]", err);
    return { success: false, error: "Error al obtener tendencia de órdenes." };
  }
}

// ─── 3. Tipo de Lente ─────────────────────────────────────────────────────────

const fetchTipoLente = unstable_cache(
  async (params: FetchParams): Promise<TipoLenteDetalle[]> => {
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
        ISNULL(dea.tipo_lente, 'Sin Definir')  AS tipo_lente_descripcion,
        ISNULL(SUM(dea.total_ordenes), 0)       AS volumen_ordenes,
        ISNULL(SUM(dea.monto_total),   0)       AS monto_total
      FROM dbo.Dash_Eficiencia_Agregado dea
      WHERE dea.fecha_pedido BETWEEN @startDate AND @endDate
        ${buildSucursalFilter("dea")}
      GROUP BY dea.tipo_lente
      ORDER BY volumen_ordenes DESC
    `);

    return (res.recordset as TipoLenteRow[]).map((r) => ({
      tipo_lente_descripcion: String(r.tipo_lente_descripcion ?? ""),
      volumen_ordenes:        Number(r.volumen_ordenes ?? 0),
      monto_total:            Number(r.monto_total ?? 0),
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
    const data = await fetchTipoLente({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTipoLente]", err);
    return { success: false, error: "Error al obtener tipo de lente." };
  }
}

// ─── 4. Órdenes por Sucursal ──────────────────────────────────────────────────

const fetchOrdenesSucursal = unstable_cache(
  async (params: FetchParams): Promise<OrdenesSucursal[]> => {
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
        ds.nombre_sucursal,
        ISNULL(SUM(dea.total_ordenes), 0) AS volumen_ordenes
      FROM dbo.Dash_Eficiencia_Agregado dea
      LEFT JOIN dbo.Dim_Sucursales ds ON dea.id_sucursal = ds.id_sucursal
      WHERE dea.fecha_pedido BETWEEN @startDate AND @endDate
        ${buildSucursalFilter("dea")}
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
    const data = await fetchOrdenesSucursal({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getOrdenesSucursal]", err);
    return { success: false, error: "Error al obtener órdenes por sucursal." };
  }
}
