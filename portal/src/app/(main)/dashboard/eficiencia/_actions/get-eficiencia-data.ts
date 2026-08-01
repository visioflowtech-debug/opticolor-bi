"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter, buildNamedInFilter } from "@/lib/sql-helpers";
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
  tipo_lente_agrupado: string;
  volumen_ordenes: number;
  monto_total_usd: number;
};

export type MarcaDetalle = {
  marca: string;
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
type TipoLenteRow    = { tipo_lente_agrupado: string; volumen_ordenes: number; monto_total_usd: number };
type MarcaRow        = { marca: string; volumen_ordenes: number; monto_total_usd: number };
type SucursalRow     = { nombre_sucursal: string; volumen_ordenes: number };

// Helper: Blindaje de Filtros Vacíos/Globales — mismo criterio que Inventario
const isAll = (val: string | null | undefined) => !val;



// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

type HoyParams = {
  sucursales: string | null;
  allowedSucursales: string;
  tipoLenteFilter: string | null;
  marcaFilter: string | null;
};

// C-3.1 Órdenes Hoy — cache PROPIO, separado del resto de los KPIs del período.
// Antes vivía adentro de fetchEficienciaKPIs: aunque su SQL nunca usa
// startDate/endDate, unstable_cache arma la clave de caché a partir de TODOS los
// argumentos recibidos por la función envuelta — startDate/endDate viajaban como
// argumentos igual, así que cada combinación de fechas que el usuario filtraba
// generaba su propia entrada de caché, cada una con el valor de "Órdenes Hoy"
// que tenía en el momento en que esa combinación se cacheó por primera vez (una
// foto vieja, no el valor actual). Clave fija (solo sucursal/RLS + los 2 filtros
// nuevos, que sí afectan el resultado real) + revalidate corto (1 min, no 1 hora)
// — el valor cambia todo el día, a diferencia del resto.
// tipoLenteFilter: columna nativa de Fact_Eficiencia_Ordenes, sin join, siempre
// seguro de aplicar directo. marcaFilter: requiere Fact_Eficiencia_Ordenes_Marca
// (1.910 órdenes sin match, ~4.4% del total) — el INNER JOIN solo se agrega si
// el usuario seleccionó una marca activamente; sin selección, el comportamiento
// es idéntico al de hoy.
const fetchOrdenesHoy = unstable_cache(
  async (params: HoyParams): Promise<number> => {
    const { sucursales, allowedSucursales, tipoLenteFilter, marcaFilter } = params;
    const pool = await getConnection();

    const tipoLenteF = buildNamedInFilter("f.tipo_lente_agrupado", "tipoLente", tipoLenteFilter);
    const marcaJoin = !isAll(marcaFilter)
      ? "INNER JOIN dbo.Fact_Eficiencia_Ordenes_Marca fem ON fem.id_orden_cristal = f.id_orden_cristal"
      : "";
    const marcaF = buildNamedInFilter("fem.Marca", "marca", marcaFilter);
    const tipoLenteSql = tipoLenteF.sql;
    const marcaSql = marcaF.sql;

    let r = pool
      .request()
      .input("sucursales",        sucursales)
      .input("allowedSucursales", allowedSucursales);
    for (const [name, value] of tipoLenteF.entries) r = r.input(name, value);
    for (const [name, value] of marcaF.entries)     r = r.input(name, value);

    const res = await r.query(`
        SELECT COUNT(DISTINCT f.id_pedido) AS valor
        FROM dbo.Fact_Eficiencia_Ordenes f
        ${marcaJoin}
        WHERE CAST(f.fecha_pedido AS DATE) = CAST(SWITCHOFFSET(TODATETIMEOFFSET(GETDATE(), '+00:00'), '-04:00') AS DATE)
          ${tipoLenteSql}
          ${marcaSql}
          ${buildSucursalFilter("f", sucursales, allowedSucursales)}
      `);

    return Number((res.recordset as ValorRow[])[0]?.valor ?? 0);
  },
  ["dash-eficiencia-ordenes-hoy"],
  { revalidate: 60, tags: ["dash-eficiencia-ordenes-hoy"] }
);

const fetchEficienciaKPIs = unstable_cache(
  async (params: FetchParams): Promise<Omit<EficienciaKpis, "ordenesHoy">> => {
    const { startDate, endDate, sucursales, allowedSucursales, tipoLenteFilter, marcaFilter } = params;
    const pool = await getConnection();

    const tipoLenteF = buildNamedInFilter("f.tipo_lente_agrupado", "tipoLente", tipoLenteFilter);
    const marcaJoin = !isAll(marcaFilter)
      ? "INNER JOIN dbo.Fact_Eficiencia_Ordenes_Marca fem ON fem.id_orden_cristal = f.id_orden_cristal"
      : "";
    const marcaF = buildNamedInFilter("fem.Marca", "marca", marcaFilter);
    const tipoLenteSql = tipoLenteF.sql;
    const marcaSql = marcaF.sql;

    let r = pool
      .request()
      .input("startDate",         startDate)
      .input("endDate",           endDate)
      .input("sucursales",        sucursales)
      .input("allowedSucursales", allowedSucursales);
    for (const [name, value] of tipoLenteF.entries) r = r.input(name, value);
    for (const [name, value] of marcaF.entries)     r = r.input(name, value);

    // C-3.2 Volumen + C-3.3 Promedio Diario — COUNTA semántico (filas, no pedidos únicos)
    const periodoStatsRes = await r.query(`
        SELECT
          COUNT(f.id_pedido)                                                              AS volumen_ordenes,
          ISNULL(SUM(f.monto_total_usd), 0)                                              AS monto_total_usd,
          COUNT(f.id_pedido) * 1.0 / NULLIF(COUNT(DISTINCT f.fecha_pedido), 0)          AS promedio_ordenes_diarias
        FROM dbo.Fact_Eficiencia_Ordenes f
        ${marcaJoin}
        WHERE CAST(f.fecha_pedido AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
          ${tipoLenteSql}
          ${marcaSql}
          ${buildSucursalFilter("f", sucursales, allowedSucursales)}
      `);

    const stats = (periodoStatsRes.recordset as PeriodoStatsRow[])[0]
      ?? { volumen_ordenes: 0, promedio_ordenes_diarias: 0, monto_total_usd: 0 };

    return {
      volumenOrdenes: Number(stats.volumen_ordenes ?? 0),
      promedioDiario: Math.round(Number(stats.promedio_ordenes_diarias ?? 0)),
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
    const { sucursales, tipoLenteFilter, marcaFilter } = params;
    const [ordenesHoy, periodoStats] = await Promise.all([
      fetchOrdenesHoy({
        sucursales,
        allowedSucursales,
        tipoLenteFilter: tipoLenteFilter ?? null,
        marcaFilter: marcaFilter ?? null,
      }),
      fetchEficienciaKPIs({ ...params, allowedSucursales }),
    ]);
    return { success: true, data: { ordenesHoy, ...periodoStats } };
  } catch (err) {
    console.error("[ERROR][getEficienciaKPIs]", err);
    return { success: false, error: "Error al obtener KPIs de eficiencia." };
  }
}

// ─── 2. Tendencia ────────────────────────────────────────────────────────────

// Tendencia de los últimos 12 meses, SIN vínculo al slicer de fecha (paridad con
// Power BI: confirmado por Edit Interactions/Performance Analyzer que este gráfico
// no reacciona al filtro de fecha, solo al de sucursal). La ventana se ancla a
// GETDATE() — antes usaba @endDate, lo que hacía que el gráfico se vaciara por
// completo si el usuario seleccionaba un rango fuera de los últimos 12 meses.
const fetchTendenciaOrden = unstable_cache(
  async (params: FetchParams): Promise<TendenciaOrden[]> => {
    const { sucursales, allowedSucursales, tipoLenteFilter, marcaFilter } = params;
    const pool = await getConnection();

    const tipoLenteF = buildNamedInFilter("f.tipo_lente_agrupado", "tipoLente", tipoLenteFilter);
    const marcaJoin = !isAll(marcaFilter)
      ? "INNER JOIN dbo.Fact_Eficiencia_Ordenes_Marca fem ON fem.id_orden_cristal = f.id_orden_cristal"
      : "";
    const marcaF = buildNamedInFilter("fem.Marca", "marca", marcaFilter);
    const tipoLenteSql = tipoLenteF.sql;
    const marcaSql = marcaF.sql;

    let req = pool
      .request()
      .input("sucursales",        sucursales)
      .input("allowedSucursales", allowedSucursales);
    for (const [name, value] of tipoLenteF.entries) req = req.input(name, value);
    for (const [name, value] of marcaF.entries)     req = req.input(name, value);

    const res = await req.query(`
      SELECT
        YEAR(f.fecha_pedido)                 AS anio,
        f.periodo                            AS periodo,
        DATENAME(MONTH, MIN(f.fecha_pedido)) AS mes_nombre,
        COUNT(f.id_pedido)                   AS volumen_ordenes
      FROM dbo.Fact_Eficiencia_Ordenes f
      ${marcaJoin}
      WHERE CAST(f.fecha_pedido AS DATE) >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
        ${tipoLenteSql}
        ${marcaSql}
        ${buildSucursalFilter("f", sucursales, allowedSucursales)}
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

// Migrado de tipo_lente_descripcion (5 categorías granulares) a tipo_lente_agrupado
// (Visión Sencilla, Progresivo, Bifocal, Intermedio, N/A) — decisión de producto.
// tipo_lente_agrupado ya viene limpio del CASE de la vista (con ELSE 'N/A'), no
// hace falta el RTRIM/LTRIM/ISNULL que sí hacía falta para el campo de texto libre
// anterior. N/A no se filtra en ningún WHERE — sigue apareciendo en el resultado.
const fetchTipoLente = unstable_cache(
  async (params: FetchParams): Promise<TipoLenteDetalle[]> => {
    const { startDate, endDate, sucursales, allowedSucursales, tipoLenteFilter, marcaFilter } = params;
    const pool = await getConnection();

    const tipoLenteF = buildNamedInFilter("f.tipo_lente_agrupado", "tipoLente", tipoLenteFilter);
    const marcaJoin = !isAll(marcaFilter)
      ? "INNER JOIN dbo.Fact_Eficiencia_Ordenes_Marca fem ON fem.id_orden_cristal = f.id_orden_cristal"
      : "";
    const marcaF = buildNamedInFilter("fem.Marca", "marca", marcaFilter);
    const tipoLenteSql = tipoLenteF.sql;
    const marcaSql = marcaF.sql;

    let req = pool
      .request()
      .input("startDate",         startDate)
      .input("endDate",           endDate)
      .input("sucursales",        sucursales)
      .input("allowedSucursales", allowedSucursales);
    for (const [name, value] of tipoLenteF.entries) req = req.input(name, value);
    for (const [name, value] of marcaF.entries)     req = req.input(name, value);

    const res = await req.query(`
      SELECT
        f.tipo_lente_agrupado               AS tipo_lente_agrupado,
        COUNT(f.id_pedido)                   AS volumen_ordenes,
        ISNULL(SUM(f.monto_total_usd), 0)    AS monto_total_usd
      FROM dbo.Fact_Eficiencia_Ordenes f
      ${marcaJoin}
      WHERE CAST(f.fecha_pedido AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
        ${tipoLenteSql}
        ${marcaSql}
        ${buildSucursalFilter("f", sucursales, allowedSucursales)}
      GROUP BY f.tipo_lente_agrupado
      ORDER BY volumen_ordenes DESC
    `);

    return (res.recordset as TipoLenteRow[]).map((r) => ({
      tipo_lente_agrupado: String(r.tipo_lente_agrupado ?? ""),
      volumen_ordenes:      Number(r.volumen_ordenes ?? 0),
      monto_total_usd:      Number(r.monto_total_usd ?? 0),
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
    const { startDate, endDate, sucursales, allowedSucursales, tipoLenteFilter, marcaFilter } = params;
    const pool = await getConnection();

    const tipoLenteF = buildNamedInFilter("f.tipo_lente_agrupado", "tipoLente", tipoLenteFilter);
    const marcaJoin = !isAll(marcaFilter)
      ? "INNER JOIN dbo.Fact_Eficiencia_Ordenes_Marca fem ON fem.id_orden_cristal = f.id_orden_cristal"
      : "";
    const marcaF = buildNamedInFilter("fem.Marca", "marca", marcaFilter);
    const tipoLenteSql = tipoLenteF.sql;
    const marcaSql = marcaF.sql;

    let req = pool
      .request()
      .input("startDate",         startDate)
      .input("endDate",           endDate)
      .input("sucursales",        sucursales)
      .input("allowedSucursales", allowedSucursales);
    for (const [name, value] of tipoLenteF.entries) req = req.input(name, value);
    for (const [name, value] of marcaF.entries)     req = req.input(name, value);

    const res = await req.query(`
      SELECT
        ds.nombre_sucursal,
        COUNT(f.id_pedido) AS volumen_ordenes
      FROM dbo.Fact_Eficiencia_Ordenes f
      LEFT JOIN dbo.Dim_Sucursales ds ON f.id_sucursal = ds.id_sucursal
      ${marcaJoin}
      WHERE CAST(f.fecha_pedido AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
        ${tipoLenteSql}
        ${marcaSql}
        ${buildSucursalFilter("f", sucursales, allowedSucursales)}
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

// ─── 5. Opciones del slicer "Tipo de Lente" ──────────────────────────────────
// Catálogo global (no depende de sucursal/RLS ni de fecha) — mismo criterio que
// getMarcasGrupos de Inventario. N/A se incluye, no se filtra.
const fetchTipoLenteOpciones = unstable_cache(
  async (): Promise<string[]> => {
    const pool = await getConnection();
    const res = await pool.request().query(`
      SELECT DISTINCT tipo_lente_agrupado FROM dbo.Dim_Tipo_Lente ORDER BY tipo_lente_agrupado
    `);
    return (res.recordset as { tipo_lente_agrupado: string }[]).map((r) => String(r.tipo_lente_agrupado ?? ""));
  },
  ["dash-eficiencia-tipo-lente-opciones"],
  { revalidate: 3600, tags: ["dash-eficiencia-tipo-lente-opciones"] },
);

export async function getTipoLenteOpciones(): Promise<{
  success: boolean;
  data?: string[];
  error?: string;
}> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const data = await fetchTipoLenteOpciones();
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTipoLenteOpciones]", err);
    return { success: false, error: "Error al obtener opciones de tipo de lente." };
  }
}

// ─── 6. Opciones del slicer "Marca", con cascada por Tipo de Lente ───────────
// Solo marcas con al menos una orden real (15, vs. 563 del catálogo completo
// Maestro_Marcas) — decisión de producto ya confirmada. Sin RLS, mismo criterio
// que getMarcasGrupos de Inventario (catálogo de filtro, no dato).
export type MarcaOpcion = { idMarca: number; marca: string };

const fetchMarcaOpciones = unstable_cache(
  async (tipoLenteFilter: string | null): Promise<MarcaOpcion[]> => {
    const pool = await getConnection();

    const tipoLenteF = buildNamedInFilter("tipo_lente_agrupado", "tipoLente", tipoLenteFilter);
    const tipoLenteSql = tipoLenteF.entries.length > 0
      ? `WHERE tipo_lente_agrupado IN (${tipoLenteF.entries.map(([name]) => `@${name}`).join(", ")})`
      : "";

    let req = pool.request();
    for (const [name, value] of tipoLenteF.entries) req = req.input(name, value);

    const res = await req.query(`
      SELECT DISTINCT id_marca, Marca AS marca
      FROM dbo.Fact_Eficiencia_Ordenes_Marca
      ${tipoLenteSql}
      ORDER BY Marca
    `);

    return (res.recordset as { id_marca: number; marca: string }[]).map((r) => ({
      idMarca: Number(r.id_marca),
      marca:   String(r.marca ?? ""),
    }));
  },
  ["dash-eficiencia-marca-opciones"],
  { revalidate: 3600, tags: ["dash-eficiencia-marca-opciones"] },
);

export async function getMarcaOpciones(
  tipoLenteFilter: string | null,
): Promise<{ success: boolean; data?: MarcaOpcion[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const data = await fetchMarcaOpciones(tipoLenteFilter);
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getMarcaOpciones]", err);
    return { success: false, error: "Error al obtener opciones de marca." };
  }
}

// ─── 7. Detalle de Órdenes por Marca ──────────────────────────────────────────
// Mismo patrón que fetchTipoLente, pero agrupando por Marca. A diferencia del
// resto de los KPIs del reporte, esta tabla SIEMPRE usa Fact_Eficiencia_Ordenes_Marca
// (el INNER JOIN es inherente a su propósito — el desglose por marca no existe
// sin esa vista) — no aplica la regla de "join solo con selección activa", que es
// para los KPIs generales que hoy no dependen de marca en absoluto.
const fetchDetalleOrdenesPorMarca = unstable_cache(
  async (params: FetchParams): Promise<MarcaDetalle[]> => {
    const { startDate, endDate, sucursales, allowedSucursales, tipoLenteFilter, marcaFilter } = params;
    const pool = await getConnection();

    const tipoLenteF = buildNamedInFilter("fem.tipo_lente_agrupado", "tipoLente", tipoLenteFilter);
    const marcaF = buildNamedInFilter("fem.Marca", "marca", marcaFilter);
    const tipoLenteSql = tipoLenteF.sql;
    const marcaSql = marcaF.sql;

    let req = pool
      .request()
      .input("startDate",         startDate)
      .input("endDate",           endDate)
      .input("sucursales",        sucursales)
      .input("allowedSucursales", allowedSucursales);
    for (const [name, value] of tipoLenteF.entries) req = req.input(name, value);
    for (const [name, value] of marcaF.entries)     req = req.input(name, value);

    const res = await req.query(`
      SELECT
        fem.Marca                            AS marca,
        COUNT(fem.id_pedido)                 AS volumen_ordenes,
        ISNULL(SUM(f.monto_total_usd), 0)    AS monto_total_usd
      FROM dbo.Fact_Eficiencia_Ordenes_Marca fem
      INNER JOIN dbo.Fact_Eficiencia_Ordenes f ON f.id_orden_cristal = fem.id_orden_cristal
      WHERE CAST(fem.fecha_pedido AS DATE) BETWEEN CAST(@startDate AS DATE) AND CAST(@endDate AS DATE)
        ${tipoLenteSql}
        ${marcaSql}
        ${buildSucursalFilter("fem", sucursales, allowedSucursales)}
      GROUP BY fem.Marca
      ORDER BY volumen_ordenes DESC
    `);

    return (res.recordset as MarcaRow[]).map((r) => ({
      marca:           String(r.marca ?? ""),
      volumen_ordenes: Number(r.volumen_ordenes ?? 0),
      monto_total_usd: Number(r.monto_total_usd ?? 0),
    }));
  },
  ["dash-eficiencia-detalle-marca"],
  { revalidate: 3600, tags: ["dash-eficiencia-detalle-marca"] },
);

export async function getDetalleOrdenesPorMarca(
  params: Params,
): Promise<{ success: boolean; data?: MarcaDetalle[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchDetalleOrdenesPorMarca({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getDetalleOrdenesPorMarca]", err);
    return { success: false, error: "Error al obtener detalle de órdenes por marca." };
  }
}
