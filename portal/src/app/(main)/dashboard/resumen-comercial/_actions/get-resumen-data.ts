"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type KpiData = {
  ventaNetaYTD: number;   // siempre Ene-1 → hoy (independiente del filtro)
  ventaNeta: number;      // período filtrado (se usa internamente para proyeccionPct)
  proyeccion: number;
  totalCobrado: number;
  ticketPromedio: number;
  cantidadPedidos: number;
  totalExamenes: number;
  clientesNuevos: number;
};

export type MonthlyTrendData = {
  periodo: string;  // "YYYY-MM"
  label: string;    // "Ene", "Feb", ...
  ventaNeta: number;
  cantidadFacturas: number;
};

export type VentaSucursal = {
  idSucursal: number;
  nombreSucursal: string;
  ventaNeta: number;
  estimadoCierre: number;
};

export type MedioPago = {
  medioPago: string;
  monto: number;
  porcentaje: number; // con 1 decimal (ej: 45.2)
};

type Params = {
  startDate: string; // "YYYY-MM-DD"
  endDate: string;   // "YYYY-MM-DD"
  sucursales: string | null; // IDs separados por coma, null = todas
};

type FetchParams = Params & {
  allowedSucursales: string;
  isSupervisor: boolean;
};

export type TrendParams = {
  sucursales: string | null; // IDs separados por coma, null = todas
};

type FetchTrendParams = TrendParams & {
  allowedSucursales: string;
  isSupervisor: boolean;
};

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type VentasKpiRow       = { anio: number; mes_nro: number; periodo: string; ventaMensual: number; trafico: number };
type ValorRow           = { valor: number };
type PedidosClientesRow = { cantidadPedidos: number; clientesNuevos: number };
type TopSucursalRow     = { idSucursal: number; nombreSucursal: string; ventaNeta: number; estimadoCierre: number };
type MedioPagoRow       = { medioPago: string; monto: number };

// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchResumenKPIs = unstable_cache(
  async (params: FetchParams): Promise<KpiData> => {
    const { startDate, endDate, sucursales, allowedSucursales, isSupervisor } = params;
    const pool = await getConnection();

    // Fecha Venezuela GMT-4 — new Date() es UTC, restar 4 h para obtener la fecha local real
    const nowGMT4  = new Date(Date.now() - 4 * 60 * 60 * 1000);
    const ytdStart = `${nowGMT4.getUTCFullYear()}-01-01`;
    const ytdEnd   = [
      nowGMT4.getUTCFullYear(),
      String(nowGMT4.getUTCMonth() + 1).padStart(2, "0"),
      String(nowGMT4.getUTCDate()).padStart(2, "0"),
    ].join("-");

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("ytdStart",          ytdStart)
        .input("ytdEnd",            ytdEnd)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales);

    const [
      ventaNetaRes,
      ventaNetaYtdRes,
      proyeccionRes,
      cobradoRes,
      pedidosClientesRes,
      examenesRes,
    ] = await Promise.all([

      // C-1.1 — Venta Neta: período filtrado exacto, con ROUND para paridad DAX
      req().query(`
        SELECT ISNULL(ROUND(SUM(monto_neto), 2), 0) AS valor
        FROM dbo.KPI_Inf1_Venta_Neta
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("")}
      `),

      // C-1.6 — Venta Neta YTD: query independiente — año en curso GMT-4, sin OR contaminante
      req().query(`
        SELECT ISNULL(ROUND(SUM(monto_neto), 2), 0) AS valor
        FROM dbo.KPI_Inf1_Venta_Neta
        WHERE fecha_factura BETWEEN @ytdStart AND @ytdEnd
          ${buildSucursalFilter("")}
      `),

      // C-1.2 — Proyección: condicional mes histórico (→ venta real) vs mes en curso (→ extrapolación)
      // Los días transcurridos y el último día del mes se calculan en tiempo real con GMT-4
      req().query(`
        DECLARE @DiaHoyGMT4  INT = DAY(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
        DECLARE @MesHoyGMT4  INT = MONTH(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
        DECLARE @AnioHoyGMT4 INT = YEAR(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
        DECLARE @DiasTranscurridos INT = CASE WHEN @DiaHoyGMT4 = 1 THEN 1 ELSE @DiaHoyGMT4 - 1 END;
        DECLARE @UltimoDiaMes      INT = DAY(EOMONTH(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE)));
        DECLARE @MesStart  INT = MONTH(CAST(@startDate AS DATE));
        DECLARE @AnioStart INT = YEAR(CAST(@startDate AS DATE));
        SELECT CASE
          WHEN @AnioStart < @AnioHoyGMT4
            OR (@AnioStart = @AnioHoyGMT4 AND @MesStart < @MesHoyGMT4)
            THEN ISNULL(ROUND(SUM(monto_neto), 2), 0)
          ELSE ISNULL(ROUND(
            SUM(CAST(monto_neto AS DECIMAL(18,4)))
            / NULLIF(CAST(@DiasTranscurridos AS DECIMAL(18,4)), 0)
            * CAST(@UltimoDiaMes AS DECIMAL(18,4))
          , 2), 0)
        END AS valor
        FROM dbo.KPI_Inf1_Proyeccion_Venta_Neta
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("")}
      `),

      // C-1.3 — Total Cobrado: Dash_Recaudo_Agregado (pre-calculado por el ETL)
      req().query(`
        SELECT ISNULL(ROUND(SUM(monto_total), 2), 0) AS valor
        FROM dbo.Dash_Recaudo_Agregado
        WHERE fecha_recaudo BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("")}
      `),

      // C-1.5 + C-1.8 — Órdenes (DISTINCT id_pedido) y Clientes Nuevos
      req().query(`
        WITH pedidos_periodo AS (
          SELECT DISTINCT
            fp.id_pedido,
            fp.id_cliente,
            CASE WHEN NOT EXISTS (
              SELECT 1 FROM dbo.Fact_Pedidos fp2
              WHERE fp2.id_cliente = fp.id_cliente
                AND CAST(fp2.fecha_pedido_completa AS DATE) < @startDate
            ) THEN 1 ELSE 0 END AS es_nuevo
          FROM dbo.Fact_Pedidos fp
          WHERE CAST(fp.fecha_pedido_completa AS DATE) BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("fp")}
        )
        SELECT
          COUNT(DISTINCT id_pedido)                                   AS cantidadPedidos,
          COUNT(DISTINCT CASE WHEN es_nuevo = 1 THEN id_cliente END)  AS clientesNuevos
        FROM pedidos_periodo
      `),

      // C-1.7 — Total Exámenes: Fact_Examenes usando COUNT(DISTINCT id_examen)
      req().query(`
        SELECT COUNT(DISTINCT id_examen) AS valor
        FROM dbo.Fact_Examenes
        WHERE fecha_examen_completa BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("")}
      `),
    ]);

    const ventaNeta       = Number((ventaNetaRes.recordset    as ValorRow[])[0]?.valor ?? 0);
    const ventaNetaYTD    = Number((ventaNetaYtdRes.recordset as ValorRow[])[0]?.valor ?? 0);
    const proyeccion      = Number((proyeccionRes.recordset   as ValorRow[])[0]?.valor ?? 0);
    const totalCobrado    = Number((cobradoRes.recordset      as ValorRow[])[0]?.valor ?? 0);
    const pedidosRow      = pedidosClientesRes.recordset[0]   as PedidosClientesRow;
    const cantidadPedidos = Number(pedidosRow?.cantidadPedidos ?? 0);

    // C-1.4 — Ticket Promedio: derivado de ventaNeta y cantidadPedidos ya corregidos
    // Equivalente exacto al DAX: DIVIDE([Venta Neta], [Cantidad Pedidos], 0)
    const ticketPromedio = cantidadPedidos > 0
      ? Math.round((ventaNeta / cantidadPedidos) * 100) / 100
      : 0;

    return {
      ventaNetaYTD,
      ventaNeta,
      proyeccion,
      totalCobrado,
      ticketPromedio,
      cantidadPedidos,
      totalExamenes:  Number((examenesRes.recordset as ValorRow[])[0]?.valor ?? 0),
      clientesNuevos: Number(pedidosRow?.clientesNuevos ?? 0),
    };
  },
  ["dash-ventas-kpis"],
  { revalidate: 3600, tags: ["dash-ventas-kpis"] }
);

export async function getResumenKPIs(
  params: Params,
): Promise<{ success: boolean; data?: KpiData; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchResumenKPIs({
      ...params,
      allowedSucursales,
      isSupervisor: auth.isSupervisor,
    });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getResumenKPIs]", err);
    return { success: false, error: "Error al obtener KPIs del resumen comercial." };
  }
}

// ─── 2. Ventas Diarias ────────────────────────────────────────────────────────

const fetchVentasDiarias = unstable_cache(
  async (params: FetchTrendParams): Promise<MonthlyTrendData[]> => {
    const { sucursales, allowedSucursales, isSupervisor } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("sucursales", sucursales)
        .input("allowedSucursales", allowedSucursales);

    const res = await req().query(`
      SELECT
        anio_factura                                                                  AS anio,
        mes_factura_nro                                                               AS mes_nro,
        periodo_factura                                                               AS periodo,
        ISNULL(SUM(monto_neto), 0)                                                   AS ventaMensual,
        COUNT(DISTINCT id_factura)                                                    AS trafico
      FROM dbo.KPI_Inf1_Venta_Neta
      WHERE anio_factura = YEAR(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00'))
        ${buildSucursalFilter("")}
      GROUP BY anio_factura, mes_factura_nro, periodo_factura
      ORDER BY anio_factura, mes_factura_nro ASC
    `);

    const MESES_SHORT = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"];
    return (res.recordset as VentasKpiRow[]).map((r) => {
      const mesNum = Number(r.mes_nro ?? 1);
      return {
        periodo:          String(r.periodo ?? `${r.anio}-${String(mesNum).padStart(2, "0")}`),
        label:            MESES_SHORT[mesNum - 1] ?? String(mesNum),
        ventaNeta:        Number(r.ventaMensual ?? 0),
        cantidadFacturas: Number(r.trafico ?? 0),
      };
    });
  },
  ["dash-ventas-diarias"],
  { revalidate: 3600, tags: ["dash-ventas-diarias"] }
);

export async function getVentasDiarias(
  params: TrendParams,
): Promise<{ success: boolean; data?: MonthlyTrendData[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchVentasDiarias({
      ...params,
      allowedSucursales,
      isSupervisor: auth.isSupervisor,
    });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getVentasDiarias]", err);
    return { success: false, error: "Error al obtener histórico de ventas." };
  }
}

// ─── 3. Top Sucursales ────────────────────────────────────────────────────────

const fetchTopSucursales = unstable_cache(
  async (params: FetchParams): Promise<VentaSucursal[]> => {
    const { startDate, endDate, sucursales, allowedSucursales, isSupervisor } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate", startDate)
        .input("endDate", endDate)
        .input("sucursales", sucursales)
        .input("allowedSucursales", allowedSucursales);

    const res = await req().query(`
      DECLARE @DiaHoyGMT4  INT = DAY(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
      DECLARE @MesHoyGMT4  INT = MONTH(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
      DECLARE @AnioHoyGMT4 INT = YEAR(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
      DECLARE @DiasTranscurridos INT = CASE WHEN @DiaHoyGMT4 = 1 THEN 1 ELSE @DiaHoyGMT4 - 1 END;
      DECLARE @UltimoDiaMes      INT = DAY(EOMONTH(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE)));
      DECLARE @MesStart  INT = MONTH(CAST(@startDate AS DATE));
      DECLARE @AnioStart INT = YEAR(CAST(@startDate AS DATE));

      SELECT TOP 10
        vn.idSucursal,
        ds.nombre_sucursal              AS nombreSucursal,
        vn.ventaNeta,
        ISNULL(pv.estimado, 0)         AS estimadoCierre
      FROM (
        SELECT
          id_sucursal                  AS idSucursal,
          ISNULL(ROUND(SUM(monto_neto), 2), 0)  AS ventaNeta
        FROM dbo.KPI_Inf1_Venta_Neta
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("")}
        GROUP BY id_sucursal
      ) vn
      INNER JOIN dbo.Dim_Sucursales ds ON ds.id_sucursal = vn.idSucursal
      LEFT JOIN (
        SELECT
          id_sucursal,
          ISNULL(ROUND(CASE
            WHEN @AnioStart < @AnioHoyGMT4 OR (@AnioStart = @AnioHoyGMT4 AND @MesStart < @MesHoyGMT4)
              THEN SUM(monto_neto)
            ELSE SUM(CAST(monto_neto AS DECIMAL(18,4))) / NULLIF(CAST(@DiasTranscurridos AS DECIMAL(18,4)), 0) * CAST(@UltimoDiaMes AS DECIMAL(18,4))
          END, 2), 0) AS estimado
        FROM dbo.KPI_Inf1_Proyeccion_Venta_Neta
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("")}
        GROUP BY id_sucursal
      ) pv ON pv.id_sucursal = vn.idSucursal
      ORDER BY vn.ventaNeta DESC
    `);

    return (res.recordset as TopSucursalRow[]).map((r) => ({
      idSucursal:     Number(r.idSucursal),
      nombreSucursal: String(r.nombreSucursal ?? ""),
      ventaNeta:      Number(r.ventaNeta ?? 0),
      estimadoCierre: Number(r.estimadoCierre ?? 0),
    }));
  },
  ["dash-ventas-top-sucursales"],
  { revalidate: 3600, tags: ["dash-ventas-top-sucursales"] }
);

export async function getTopSucursales(
  params: Params,
): Promise<{ success: boolean; data?: VentaSucursal[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchTopSucursales({
      ...params,
      allowedSucursales,
      isSupervisor: auth.isSupervisor,
    });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getTopSucursales]", err);
    return { success: false, error: "Error al obtener top sucursales." };
  }
}

// ─── 4. Medios de Pago ────────────────────────────────────────────────────────

const fetchMediosPago = unstable_cache(
  async (params: FetchParams): Promise<MedioPago[]> => {
    const { startDate, endDate, sucursales, allowedSucursales, isSupervisor } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate", startDate)
        .input("endDate", endDate)
        .input("sucursales", sucursales)
        .input("allowedSucursales", allowedSucursales);

    const res = await req().query(`
      SELECT
        metodo_pago                       AS medioPago,
        ISNULL(SUM(monto_total), 0)       AS monto
      FROM dbo.Dash_Recaudo_Agregado
      WHERE fecha_recaudo BETWEEN @startDate AND @endDate
        ${buildSucursalFilter("")}
      GROUP BY metodo_pago
      ORDER BY monto DESC
    `);

    const rawMedios = (res.recordset as MedioPagoRow[]).map((r) => ({
      medioPago: r.medioPago ?? "",
      monto:     Number(r.monto ?? 0),
    }));
    const totalMonto = rawMedios.reduce((acc, r) => acc + r.monto, 0);
    return rawMedios.map((r) => ({
      ...r,
      porcentaje:
        totalMonto > 0 ? Math.round((r.monto / totalMonto) * 10000) / 100 : 0,
    }));
  },
  ["dash-ventas-medios-pago"],
  { revalidate: 3600, tags: ["dash-ventas-medios-pago"] }
);

export async function getMediosPago(
  params: Params,
): Promise<{ success: boolean; data?: MedioPago[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchMediosPago({
      ...params,
      allowedSucursales,
      isSupervisor: auth.isSupervisor,
    });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getMediosPago]", err);
    return { success: false, error: "Error al obtener medios de pago." };
  }
}
