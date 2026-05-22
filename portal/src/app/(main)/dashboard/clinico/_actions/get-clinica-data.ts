"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type ClinicaKpis = {
  totalExamenes: number;
  pctConversion: number;
  examenesHoy: number;
  promedioDiario: number;
  convertidos: number;
  noConvertidos: number;
};

export type TendenciaExamen = {
  mes_examen_nombre: string;
  total_examenes: number;
};

export type VolumenConversion = {
  mes_examen_nombre: string;
  convertidos: number;
  no_convertidos: number;
  pct_conversion: number;
};

export type GeneroExamen = {
  genero_label: string;
  total_examenes: number;
};

export type EdadExamen = {
  rango_edad_descripcion: string;
  min_edad: number;
  total_examenes: number;
};

export type SucursalExamen = {
  nombre_sucursal: string;
  total_examenes: number;
};

export type Params = {
  startDate: string; // "YYYY-MM-DD"
  endDate: string;   // "YYYY-MM-DD"
  sucursales: string | null; // IDs separados por coma, null = todas
};

type FetchParams = Params & { allowedSucursales: string; isSupervisor: boolean };

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type ValorRow        = { valor: number };
type PeriodoStatsRow = { total_examenes: number; convertidos: number; no_convertidos: number; promedio_diario: number };
type TendenciaVolRow = { periodo: string; total_examenes: number; convertidos: number; no_convertidos: number };
type GeneroRow       = { genero_label: string; total_examenes: number };
type EdadRow         = { rango_edad_descripcion: string; total_examenes: number };
type SucursalRow     = { nombre_sucursal: string; total_examenes: number };

// ─── Auxiliares ───────────────────────────────────────────────────────────────

function extractMinAge(rango: string): number {
  const match = rango.match(/\d+/);
  return match ? parseInt(match[0], 10) : 0;
}

const MESES = [
  "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
  "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
];

// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchClinicaKPIs = unstable_cache(
  async (params: FetchParams): Promise<ClinicaKpis> => {
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

    const [examenesHoyRes, periodoStatsRes] = await Promise.all([
      // Exámenes Hoy
      req().query(`
        SELECT ISNULL(SUM(dca.total_examenes), 0) AS valor
        FROM dbo.Dash_Clinico_Agregado dca
        WHERE dca.fecha_examen = CAST(GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'SA Western Standard Time' AS DATE)
          ${buildSucursalFilter("dca")}
      `),

      // KPIs período
      req().query(`
        SELECT
          ISNULL(SUM(dca.total_examenes), 0)                                                                    AS total_examenes,
          ISNULL(SUM(CASE WHEN dca.estado_conversion = 'CONVERTIDO'    THEN dca.total_examenes ELSE 0 END), 0)  AS convertidos,
          ISNULL(SUM(CASE WHEN dca.estado_conversion = 'NO CONVERTIDO' THEN dca.total_examenes ELSE 0 END), 0)  AS no_convertidos,
          ISNULL(
            SUM(dca.total_examenes) * 1.0 / NULLIF(COUNT(DISTINCT dca.fecha_examen), 0),
            0
          )                                                                                                      AS promedio_diario
        FROM dbo.Dash_Clinico_Agregado dca
        WHERE dca.fecha_examen BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("dca")}
      `),
    ]);

    const stats = (periodoStatsRes.recordset as PeriodoStatsRow[])[0]
      ?? { total_examenes: 0, convertidos: 0, no_convertidos: 0, promedio_diario: 0 };
    const totalExamenes = Number(stats.total_examenes ?? 0);
    const convertidos   = Number(stats.convertidos ?? 0);
    const pctConversion = totalExamenes > 0 ? Math.round((convertidos / totalExamenes) * 10000) / 100 : 0;

    return {
      examenesHoy:    Number((examenesHoyRes.recordset as ValorRow[])[0]?.valor ?? 0),
      totalExamenes,
      pctConversion,
      promedioDiario: Math.round(Number(stats.promedio_diario ?? 0) * 100) / 100,
      convertidos,
      noConvertidos:  Number(stats.no_convertidos ?? 0),
    };
  },
  ["dash-clinico-kpis"],
  { revalidate: 3600, tags: ["dash-clinico-kpis"] }
);

export async function getClinicaKPIs(
  params: Params,
): Promise<{ success: boolean; data?: ClinicaKpis; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchClinicaKPIs({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getClinicaKPIs]", err);
    return { success: false, error: "Error al obtener KPIs de clínica." };
  }
}

// ─── 2. Tendencia ────────────────────────────────────────────────────────────

const fetchTendenciaExamen = unstable_cache(
  async (params: FetchParams): Promise<TendenciaExamen[]> => {
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
        dca.periodo                                                                                            AS periodo,
        ISNULL(SUM(dca.total_examenes), 0)                                                                    AS total_examenes
      FROM dbo.Dash_Clinico_Agregado dca
      WHERE dca.fecha_examen >= DATEADD(MONTH, -12, CAST(@endDate AS DATE))
        AND dca.fecha_examen <= CAST(@endDate AS DATE)
        ${buildSucursalFilter("dca")}
      GROUP BY dca.periodo
      ORDER BY dca.periodo ASC
    `);

    return (res.recordset as { periodo: string; total_examenes: number }[]).map((r) => ({
      mes_examen_nombre: MESES[parseInt(r.periodo.slice(5, 7), 10) - 1] ?? r.periodo,
      total_examenes:    Number(r.total_examenes ?? 0),
    }));
  },
  ["dash-clinico-tendencia"],
  { revalidate: 3600, tags: ["dash-clinico-tendencia"] }
);

export async function getTendenciaExamen(
  params: Params,
): Promise<{ success: boolean; data?: TendenciaExamen[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchTendenciaExamen({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTendenciaExamen]", err);
    return { success: false, error: "Error al obtener tendencia de exámenes." };
  }
}

// ─── 3. Volumen vs Conversión ─────────────────────────────────────────────────

const fetchVolumenConversion = unstable_cache(
  async (params: FetchParams): Promise<VolumenConversion[]> => {
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
        dca.periodo                                                                                            AS periodo,
        ISNULL(SUM(dca.total_examenes), 0)                                                                    AS total_examenes,
        ISNULL(SUM(CASE WHEN dca.estado_conversion = 'CONVERTIDO'    THEN dca.total_examenes ELSE 0 END), 0)  AS convertidos,
        ISNULL(SUM(CASE WHEN dca.estado_conversion = 'NO CONVERTIDO' THEN dca.total_examenes ELSE 0 END), 0)  AS no_convertidos
      FROM dbo.Dash_Clinico_Agregado dca
      WHERE dca.fecha_examen >= DATEADD(MONTH, -12, CAST(@endDate AS DATE))
        AND dca.fecha_examen <= CAST(@endDate AS DATE)
        ${buildSucursalFilter("dca")}
      GROUP BY dca.periodo
      ORDER BY dca.periodo ASC
    `);

    return (res.recordset as TendenciaVolRow[]).map((r) => {
      const total = Number(r.total_examenes ?? 0);
      const conv  = Number(r.convertidos ?? 0);
      return {
        mes_examen_nombre: MESES[parseInt(r.periodo.slice(5, 7), 10) - 1] ?? r.periodo,
        convertidos:       conv,
        no_convertidos:    Number(r.no_convertidos ?? 0),
        pct_conversion:    total > 0 ? Math.round((conv / total) * 10000) / 100 : 0,
      };
    });
  },
  ["dash-clinico-volumen-conversion"],
  { revalidate: 3600, tags: ["dash-clinico-volumen-conversion"] }
);

export async function getVolumenConversion(
  params: Params,
): Promise<{ success: boolean; data?: VolumenConversion[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchVolumenConversion({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getVolumenConversion]", err);
    return { success: false, error: "Error al obtener volumen de conversión." };
  }
}

// ─── 4. Género ───────────────────────────────────────────────────────────────

const fetchGeneroExamen = unstable_cache(
  async (params: FetchParams): Promise<GeneroExamen[]> => {
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
        ISNULL(dc.genero_label, 'Sin Definir') AS genero_label,
        ISNULL(COUNT(DISTINCT fe.id_examen), 0) AS total_examenes
      FROM dbo.Fact_Examenes fe
      LEFT JOIN dbo.Dim_Clientes dc ON fe.id_cliente = dc.id_cliente
      WHERE CAST(fe.fecha_examen_completa AS DATE) BETWEEN @startDate AND @endDate
        ${buildSucursalFilter("fe")}
      GROUP BY dc.genero_label
      ORDER BY total_examenes DESC
    `);

    return (res.recordset as GeneroRow[]).map((r) => ({
      genero_label:   String(r.genero_label ?? ""),
      total_examenes: Number(r.total_examenes ?? 0),
    }));
  },
  ["dash-clinico-genero"],
  { revalidate: 3600, tags: ["dash-clinico-genero"] }
);

export async function getGeneroExamen(
  params: Params,
): Promise<{ success: boolean; data?: GeneroExamen[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchGeneroExamen({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getGeneroExamen]", err);
    return { success: false, error: "Error al obtener datos por género." };
  }
}

// ─── 5. Edad ─────────────────────────────────────────────────────────────────

const fetchEdadExamen = unstable_cache(
  async (params: FetchParams): Promise<EdadExamen[]> => {
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
        ISNULL(dc.rango_edad_descripcion, 'Sin Definir') AS rango_edad_descripcion,
        ISNULL(COUNT(DISTINCT fe.id_examen), 0) AS total_examenes
      FROM dbo.Fact_Examenes fe
      LEFT JOIN dbo.Dim_Clientes dc ON fe.id_cliente = dc.id_cliente
      WHERE CAST(fe.fecha_examen_completa AS DATE) BETWEEN @startDate AND @endDate
        ${buildSucursalFilter("fe")}
      GROUP BY dc.rango_edad_descripcion
    `);

    const rawEdades = (res.recordset as EdadRow[]).map((r) => {
      const desc = String(r.rango_edad_descripcion ?? "Sin Definir");
      return {
        rango_edad_descripcion: desc,
        min_edad:               extractMinAge(desc),
        total_examenes:         Number(r.total_examenes ?? 0),
      };
    });

    return rawEdades.sort((a, b) => a.min_edad - b.min_edad);
  },
  ["dash-clinico-edad"],
  { revalidate: 3600, tags: ["dash-clinico-edad"] }
);

export async function getEdadExamen(
  params: Params,
): Promise<{ success: boolean; data?: EdadExamen[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchEdadExamen({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getEdadExamen]", err);
    return { success: false, error: "Error al obtener datos por edad." };
  }
}

// ─── 6. Top Sucursales ────────────────────────────────────────────────────────

const fetchTopSucursalesExamen = unstable_cache(
  async (params: FetchParams): Promise<SucursalExamen[]> => {
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
        dca.nombre_sucursal,
        ISNULL(SUM(dca.total_examenes), 0) AS total_examenes
      FROM dbo.Dash_Clinico_Agregado dca
      WHERE dca.fecha_examen BETWEEN @startDate AND @endDate
        ${buildSucursalFilter("dca")}
      GROUP BY dca.nombre_sucursal
      ORDER BY total_examenes DESC
    `);

    return (res.recordset as SucursalRow[]).map((r) => ({
      nombre_sucursal: String(r.nombre_sucursal ?? ""),
      total_examenes:  Number(r.total_examenes ?? 0),
    }));
  },
  ["dash-clinico-top-sucursales"],
  { revalidate: 3600, tags: ["dash-clinico-top-sucursales"] }
);

export async function getTopSucursalesExamen(
  params: Params,
): Promise<{ success: boolean; data?: SucursalExamen[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchTopSucursalesExamen({ ...params, allowedSucursales, isSupervisor: auth.isSupervisor });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTopSucursalesExamen]", err);
    return { success: false, error: "Error al obtener top sucursales de clínica." };
  }
}
