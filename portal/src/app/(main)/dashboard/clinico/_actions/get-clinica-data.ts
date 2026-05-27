"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";
import { MAP_MES_NUM_TO_ABBR as MES_ABBR } from "@/lib/date-utils";

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
  total_examenes: number;      // F-3: expuesto para la línea dominante del gráfico
  convertidos: number;
  no_convertidos: number;
  pct_conversion: number;
};

export type GeneroExamen = {
  genero_label: string;
  total_examenes: number;
  porcentaje: number;       // Calculado en SQL con window function OVER()
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

// F-9: isSupervisor eliminado — buildSucursalFilter() nunca lo referencia en SQL
type FetchParams = Params & { allowedSucursales: string; excludedClinica: string };

// C-4.3: KPI fetcher necesita rangos de "hoy" calculados fuera del cache
type KpiParams = FetchParams & { inicioHoy: string; finHoy: string };

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type ValorRow        = { valor: number };
type PeriodoStatsRow = {
  totalExamenes: number;
  convertidos: number;
  noConvertidos: number;
  pctConversion: number;
  promedioDiario: number;
};
type TendenciaVolRow = { periodo: string; total_examenes: number; convertidos: number; no_convertidos: number };
type GeneroRow       = { genero_label: string; total_examenes: number; porcentaje: number };
type EdadRow         = { rango_edad_descripcion: string; total_examenes: number };
type SucursalRow     = { nombre_sucursal: string; total_examenes: number };

// ─── Auxiliares ───────────────────────────────────────────────────────────────

function extractMinAge(rango: string): number {
  const match = rango.match(/\d+/);
  return match ? parseInt(match[0], 10) : 0;
}

// F-8: Abreviatura mes con sufijo de año ("Ene '25") — evita ambigüedad al cruzar años

function buildMesLabel(periodo: string): string {
  const year  = periodo.slice(2, 4);
  const month = periodo.slice(5, 7);
  return `${MES_ABBR[month] ?? periodo} '${year}`;
}

// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchClinicaKPIs = unstable_cache(
  async (params: KpiParams): Promise<ClinicaKpis> => {
    const { startDate, endDate, sucursales, allowedSucursales, inicioHoy, finHoy, excludedClinica } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("excludedClinica",   excludedClinica);

    const [examenesHoyRes, periodoStatsRes] = await Promise.all([
      // C-4.3: Exámenes Hoy — fuente transaccional, sin lag ETL de ~3h
      pool
        .request()
        .input("inicioHoy",         inicioHoy)
        .input("finHoy",            finHoy)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("excludedClinica",   excludedClinica)
        .query(`
          SELECT COUNT(DISTINCT fe.id_examen) AS valor
          FROM dbo.Fact_Examenes fe
          WHERE fe.fecha_examen_completa >= @inicioHoy
            AND fe.fecha_examen_completa <= @finHoy
            AND fe.id_sucursal NOT IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@excludedClinica, ','))
            ${buildSucursalFilter("fe")}
        `),

      // KPIs período — Fact_Examenes es ahora la fuente directa y única de verdad
      req().query(`
        SELECT 
          COUNT(DISTINCT fe.id_examen) AS [totalExamenes],
          COUNT(DISTINCT CASE WHEN fe.estado_conversion = 'Convertido' THEN fe.id_examen END) AS [convertidos],
          COUNT(DISTINCT CASE WHEN fe.estado_conversion != 'Convertido' OR fe.estado_conversion IS NULL THEN fe.id_examen END) AS [noConvertidos],
          CAST(COUNT(DISTINCT CASE WHEN fe.estado_conversion = 'Convertido' THEN fe.id_examen END) * 100.0 / NULLIF(COUNT(DISTINCT fe.id_examen), 0) AS DECIMAL(5,2)) AS [pctConversion],
          CAST(COUNT(DISTINCT fe.id_examen) * 1.0 / NULLIF(COUNT(DISTINCT fe.fecha_examen_completa), 0) AS DECIMAL(5,2)) AS [promedioDiario]
        FROM dbo.Fact_Examenes fe
        WHERE fe.fecha_examen_completa >= CAST(@startDate AS DATE)
          AND fe.fecha_examen_completa < DATEADD(DAY, 1, CAST(@endDate AS DATE))
          AND fe.id_sucursal NOT IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@excludedClinica, ','))
          ${buildSucursalFilter("fe")}
      `),
    ]);

    const stats = (periodoStatsRes.recordset as PeriodoStatsRow[])[0]
      ?? { totalExamenes: 0, convertidos: 0, noConvertidos: 0, pctConversion: 0, promedioDiario: 0 };
    const totalExamenes = Number(stats.totalExamenes ?? 0);
    const convertidos   = Number(stats.convertidos ?? 0);
    const pctConversion = Number(stats.pctConversion ?? 0);

    return {
      examenesHoy:    Number((examenesHoyRes.recordset as ValorRow[])[0]?.valor ?? 0),
      totalExamenes,
      pctConversion,
      promedioDiario: Math.round(Number(stats.promedioDiario ?? 0) * 100) / 100,
      convertidos,
      noConvertidos:  Number(stats.noConvertidos ?? 0),
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
    // C-4.3: Rango "hoy" calculado fuera del cache en hora Venezuela (sin lag ETL)
    const hoy       = new Date().toLocaleDateString("en-CA", { timeZone: "America/Caracas" });
    const inicioHoy = `${hoy} 00:00:00`;
    const finHoy    = `${hoy} 23:59:59`;
    const excludedClinica = process.env.EXCLUDED_CLINICA_IDS || "3,4";
    const data = await fetchClinicaKPIs({ ...params, allowedSucursales, inicioHoy, finHoy, excludedClinica });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getClinicaKPIs]", err);
    return { success: false, error: "Error al obtener KPIs de clínica." };
  }
}

// ─── 2. Tendencia ────────────────────────────────────────────────────────────

const fetchTendenciaExamen = unstable_cache(
  async (params: FetchParams): Promise<TendenciaExamen[]> => {
    const { endDate, sucursales, allowedSucursales, excludedClinica } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("excludedClinica",   excludedClinica);

    const res = await req().query(`
      SELECT 
        CONVERT(VARCHAR(7), fe.fecha_examen_completa, 120) AS periodo,
        COUNT(DISTINCT fe.id_examen) AS total_examenes
      FROM dbo.Fact_Examenes fe
      WHERE fe.fecha_examen_completa >= DATEADD(MONTH, -12, CAST(@endDate AS DATE))
        AND fe.fecha_examen_completa < DATEADD(DAY, 1, CAST(@endDate AS DATE))
        AND fe.id_sucursal NOT IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@excludedClinica, ','))
        ${buildSucursalFilter("fe")}
      GROUP BY CONVERT(VARCHAR(7), fe.fecha_examen_completa, 120)
      ORDER BY periodo ASC
    `);

    return (res.recordset as { periodo: string; total_examenes: number }[]).map((r) => ({
      mes_examen_nombre: buildMesLabel(r.periodo),   // F-8: "Ene '25" con año
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
    const excludedClinica = process.env.EXCLUDED_CLINICA_IDS || "3,4";
    const data = await fetchTendenciaExamen({ ...params, allowedSucursales, excludedClinica });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTendenciaExamen]", err);
    return { success: false, error: "Error al obtener tendencia de exámenes." };
  }
}

// ─── 3. Volumen vs Conversión ─────────────────────────────────────────────────

const fetchVolumenConversion = unstable_cache(
  async (params: FetchParams): Promise<VolumenConversion[]> => {
    const { endDate, sucursales, allowedSucursales, excludedClinica } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("excludedClinica",   excludedClinica);

    const res = await req().query(`
      SELECT 
        CONVERT(VARCHAR(7), fe.fecha_examen_completa, 120) AS periodo,
        COUNT(DISTINCT fe.id_examen) AS total_examenes,
        COUNT(DISTINCT CASE WHEN fe.estado_conversion = 'Convertido' THEN fe.id_examen END) AS convertidos,
        COUNT(DISTINCT CASE WHEN fe.estado_conversion != 'Convertido' OR fe.estado_conversion IS NULL THEN fe.id_examen END) AS no_convertidos
      FROM dbo.Fact_Examenes fe
      WHERE fe.fecha_examen_completa >= DATEADD(MONTH, -12, CAST(@endDate AS DATE))
        AND fe.fecha_examen_completa < DATEADD(DAY, 1, CAST(@endDate AS DATE))
        AND fe.id_sucursal NOT IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@excludedClinica, ','))
        ${buildSucursalFilter("fe")}
      GROUP BY CONVERT(VARCHAR(7), fe.fecha_examen_completa, 120)
      ORDER BY periodo ASC
    `);

    return (res.recordset as TendenciaVolRow[]).map((r) => {
      const total = Number(r.total_examenes ?? 0);
      const conv  = Number(r.convertidos ?? 0);
      return {
        mes_examen_nombre: buildMesLabel(r.periodo),   // F-8: "Ene '25"
        total_examenes:    total,                       // F-3: expuesto para la línea del gráfico
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
    const excludedClinica = process.env.EXCLUDED_CLINICA_IDS || "3,4";
    const data = await fetchVolumenConversion({ ...params, allowedSucursales, excludedClinica });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getVolumenConversion]", err);
    return { success: false, error: "Error al obtener volumen de conversión." };
  }
}

// ─── 4. Género ───────────────────────────────────────────────────────────────

const fetchGeneroExamen = unstable_cache(
  async (params: FetchParams): Promise<GeneroExamen[]> => {
    const { startDate, endDate, sucursales, allowedSucursales, excludedClinica } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("excludedClinica",   excludedClinica);

    const res = await req().query(`
      SELECT
        CASE
          WHEN dc.genero_label IS NULL OR RTRIM(LTRIM(dc.genero_label)) = '' THEN 'NO DEFINIDO (PENDIENTE)'
          ELSE UPPER(RTRIM(LTRIM(dc.genero_label)))
        END AS genero_label,
        COUNT(DISTINCT fe.id_examen) AS total_examenes,
        CAST(
          COUNT(DISTINCT fe.id_examen) * 100.0
          / SUM(COUNT(DISTINCT fe.id_examen)) OVER()
          AS DECIMAL(5,2)
        ) AS porcentaje
      FROM dbo.Fact_Examenes fe
      LEFT JOIN dbo.Dim_Clientes dc ON fe.id_cliente = dc.id_cliente
      WHERE fe.fecha_examen_completa >= CAST(@startDate AS DATE)
        AND fe.fecha_examen_completa < DATEADD(DAY, 1, CAST(@endDate AS DATE))
        AND fe.id_sucursal NOT IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@excludedClinica, ','))
        ${buildSucursalFilter("fe")}
      GROUP BY
        CASE
          WHEN dc.genero_label IS NULL OR RTRIM(LTRIM(dc.genero_label)) = '' THEN 'NO DEFINIDO (PENDIENTE)'
          ELSE UPPER(RTRIM(LTRIM(dc.genero_label)))
        END
      ORDER BY total_examenes DESC
    `);

    return (res.recordset as GeneroRow[]).map((r) => ({
      genero_label:   String(r.genero_label ?? ""),
      total_examenes: Number(r.total_examenes ?? 0),
      porcentaje:     Number(r.porcentaje ?? 0),
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
    const excludedClinica = process.env.EXCLUDED_CLINICA_IDS || "3,4";
    const data = await fetchGeneroExamen({ ...params, allowedSucursales, excludedClinica });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getGeneroExamen]", err);
    return { success: false, error: "Error al obtener datos por género." };
  }
}

// ─── 5. Edad ─────────────────────────────────────────────────────────────────

const fetchEdadExamen = unstable_cache(
  async (params: FetchParams): Promise<EdadExamen[]> => {
    const { startDate, endDate, sucursales, allowedSucursales, excludedClinica } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("excludedClinica",   excludedClinica);

    // F-2-b: Rangos calculados dinámicamente — CASE WHEN sobre c.edad
    // Fuente: Fact_Examenes LEFT JOIN Dim_Clientes (cubre huérfanos y nulos)
    // Filtro sargable: permite index seek sobre fecha_examen_completa
    const res = await req().query(`
      SELECT
        CASE
          WHEN c.edad IS NULL OR c.edad <= 0 OR c.edad > 110 THEN 'No Indica'
          WHEN c.edad BETWEEN 1  AND 18  THEN '01 a 18'
          WHEN c.edad BETWEEN 19 AND 30  THEN '19 a 30'
          WHEN c.edad BETWEEN 31 AND 40  THEN '31 a 40'
          WHEN c.edad BETWEEN 41 AND 50  THEN '41 a 50'
          ELSE '51 a 100'
        END AS rango_edad_descripcion,
        COUNT(DISTINCT fe.id_examen) AS total_examenes
      FROM dbo.Fact_Examenes fe
      LEFT JOIN dbo.Dim_Clientes c ON fe.id_cliente = c.id_cliente
      WHERE fe.fecha_examen_completa >= CAST(@startDate AS DATE)
        AND fe.fecha_examen_completa < DATEADD(DAY, 1, CAST(@endDate AS DATE))
        AND fe.id_sucursal NOT IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@excludedClinica, ','))
        ${buildSucursalFilter("fe")}
      GROUP BY
        CASE
          WHEN c.edad IS NULL OR c.edad <= 0 OR c.edad > 110 THEN 'No Indica'
          WHEN c.edad BETWEEN 1  AND 18  THEN '01 a 18'
          WHEN c.edad BETWEEN 19 AND 30  THEN '19 a 30'
          WHEN c.edad BETWEEN 31 AND 40  THEN '31 a 40'
          WHEN c.edad BETWEEN 41 AND 50  THEN '41 a 50'
          ELSE '51 a 100'
        END
      ORDER BY rango_edad_descripcion ASC
    `);

    const rawEdades = (res.recordset as EdadRow[]).map((r) => {
      const desc = String(r.rango_edad_descripcion ?? "No Indica");
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
    const excludedClinica = process.env.EXCLUDED_CLINICA_IDS || "3,4";
    const data = await fetchEdadExamen({ ...params, allowedSucursales, excludedClinica });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getEdadExamen]", err);
    return { success: false, error: "Error al obtener datos por edad." };
  }
}

// ─── 6. Top Sucursales ────────────────────────────────────────────────────────

const fetchTopSucursalesExamen = unstable_cache(
  async (params: FetchParams): Promise<SucursalExamen[]> => {
    const { startDate, endDate, sucursales, allowedSucursales, excludedClinica } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales)
        .input("excludedClinica",   excludedClinica);

    const res = await req().query(`
      SELECT 
        s.nombre_sucursal,
        COUNT(DISTINCT fe.id_examen) AS total_examenes
      FROM dbo.Fact_Examenes fe
      LEFT JOIN dbo.Dim_Sucursales s ON fe.id_sucursal = s.id_sucursal
      WHERE fe.fecha_examen_completa >= CAST(@startDate AS DATE)
        AND fe.fecha_examen_completa < DATEADD(DAY, 1, CAST(@endDate AS DATE))
        AND fe.id_sucursal NOT IN (SELECT CAST(value AS int) FROM STRING_SPLIT(@excludedClinica, ','))
        ${buildSucursalFilter("fe")}
      GROUP BY s.nombre_sucursal
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
    const excludedClinica = process.env.EXCLUDED_CLINICA_IDS || "3,4";
    const data = await fetchTopSucursalesExamen({ ...params, allowedSucursales, excludedClinica });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTopSucursalesExamen]", err);
    return { success: false, error: "Error al obtener top sucursales de clínica." };
  }
}
