"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";
import { ReportParams } from "@/types/dashboard";
import { MAP_MES_NUM_TO_ABBR as MES_ABBR } from "@/lib/date-utils";

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type KpiData = {
  ventaNetaYTDUsd: number;         // siempre Ene-1 → hoy (independiente del filtro)
  ventaNetaYTDSinIvaUsd: number;
  ventaNetaUsd: number;            // período filtrado (con IVA — se usa internamente para proyeccionPct)
  ventaNetaSinIvaUsd: number;
  proyeccionUsd: number;
  totalCobradoUsd: number;
  ticketPromedioUsd: number;
  cantidadPedidos: number;
  cantidadFacturas: number;
  clientesNuevos: number;
};

export type MonthlyTrendData = {
  periodo: string;  // "YYYY-MM"
  label: string;    // "Ene", "Feb", ...
  ventaNetaUsd: number;
  cantidadFacturas: number;
};

export type VentaSucursal = {
  idSucursal: number;
  nombreSucursal: string;
  ventaNetaUsd: number;
  estimadoCierreUsd: number;
};

export type MedioPago = {
  medioPago: string;
  montoUsd: number;
  porcentaje: number; // con 1 decimal (ej: 45.2)
};

export type Params = ReportParams;

type FetchParams = Params & {
  allowedSucursales: string;
};

export type TrendParams = {
  sucursales: string | null; // IDs separados por coma, null = todas
};

type FetchTrendParams = TrendParams & {
  allowedSucursales: string;
};

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type VentasKpiRow       = { anio: number; mes_nro: number; periodo: string; ventaMensualUsd: number; trafico: number };
type ValorRow           = { valor: number };
type VentaNetaRow       = { ventaNetaUsd: number; ventaNetaSinIvaUsd: number };
type PedidosRow         = { cantidadPedidos: number };
type TopSucursalRow     = { idSucursal: number; nombreSucursal: string; ventaNetaUsd: number; estimadoCierreUsd: number };
type MedioPagoRow       = { medioPago: string; montoUsd: number };

// ─── 1. KPIs ─────────────────────────────────────────────────────────────────

const fetchResumenKPIs = unstable_cache(
  async (params: FetchParams): Promise<KpiData> => {
    const { startDate, endDate, sucursales, allowedSucursales } = params;
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
      pedidosRes,
      facturasRes,
      clientesNuevosRes,
    ] = await Promise.all([

      // C-1.1 — Venta Neta: período filtrado exacto, con ROUND para paridad DAX
      // Trae ambas variantes (con y sin IVA) — monto_neto_usd/monto_neto_sin_iva_usd
      // ya vienen precalculadas 1:1 con la fórmula DAX (validado: Venta Bruta USD -
      // Devoluciones USD == monto_neto_usd, en agregado y en caso puntual).
      req().query(`
        SELECT
          ISNULL(ROUND(SUM(monto_neto_usd), 2), 0)         AS ventaNetaUsd,
          ISNULL(ROUND(SUM(monto_neto_sin_iva_usd), 2), 0) AS ventaNetaSinIvaUsd
        FROM dbo.KPI_Inf1_Venta_Neta
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
      `),

      // C-1.6 — Venta Neta YTD: query independiente — año en curso GMT-4, sin OR contaminante
      req().query(`
        SELECT
          ISNULL(ROUND(SUM(monto_neto_usd), 2), 0)         AS ventaNetaUsd,
          ISNULL(ROUND(SUM(monto_neto_sin_iva_usd), 2), 0) AS ventaNetaSinIvaUsd
        FROM dbo.KPI_Inf1_Venta_Neta
        WHERE fecha_factura BETWEEN @ytdStart AND @ytdEnd
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
      `),

      // C-1.2 — Proyección: regla de negocio confirmada con el autor del DAX —
      // el cálculo NUNCA depende del rango seleccionado, siempre extrapola el mes
      // calendario actual completo. El rango elegido solo decide si esa proyección
      // se muestra (el mes actual cae dentro del rango) o se muestra 0 (el rango
      // son solo meses ya cerrados, sin tocar el mes en curso).
      req().query(`
        DECLARE @DiaHoyGMT4  INT = DAY(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
        DECLARE @MesHoyGMT4  INT = MONTH(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
        DECLARE @AnioHoyGMT4 INT = YEAR(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE));
        DECLARE @DiasTranscurridos INT = CASE WHEN @DiaHoyGMT4 = 1 THEN 1 ELSE @DiaHoyGMT4 - 1 END;
        DECLARE @UltimoDiaMes      INT = DAY(EOMONTH(CAST(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS DATE)));

        -- "Periodo" como año*12+mes para comparar rangos de mes calendario sin ambigüedad
        DECLARE @PeriodoHoy   INT = @AnioHoyGMT4 * 12 + @MesHoyGMT4;
        DECLARE @PeriodoStart INT = YEAR(CAST(@startDate AS DATE)) * 12 + MONTH(CAST(@startDate AS DATE));
        DECLARE @PeriodoEnd   INT = YEAR(CAST(@endDate AS DATE))   * 12 + MONTH(CAST(@endDate AS DATE));

        SELECT CASE
          WHEN @PeriodoHoy NOT BETWEEN @PeriodoStart AND @PeriodoEnd THEN 0
          ELSE ISNULL(ROUND(
            SUM(CAST(monto_neto_usd AS DECIMAL(18,4)))
            / NULLIF(CAST(@DiasTranscurridos AS DECIMAL(18,4)), 0)
            * CAST(@UltimoDiaMes AS DECIMAL(18,4))
          , 2), 0)
        END AS valor
        FROM dbo.KPI_Inf1_Proyeccion_Venta_Neta
        WHERE anio_factura = @AnioHoyGMT4 AND mes_factura_nro = @MesHoyGMT4
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
      `),

      // C-1.3 — Total Cobrado: Fact_Recaudo (reemplaza Dash_Recaudo_Agregado, sin columna _usd)
      req().query(`
        SELECT ISNULL(ROUND(SUM(importe_neto_usd), 2), 0) AS valor
        FROM dbo.Fact_Recaudo
        WHERE fecha_completa BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
      `),

      // C-1.5 — Órdenes: DISTINCT id_pedido en el rango (Fact_Pedidos)
      req().query(`
        SELECT COUNT(DISTINCT id_pedido) AS cantidadPedidos
        FROM dbo.Fact_Pedidos
        WHERE CAST(fecha_pedido_completa AS DATE) BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
      `),

      // C-1.4 — Cantidad Facturas: DISTINCTCOUNT(Fact_Ventas[id_factura]) — alimenta
      // tanto el denominador de Ticket Promedio como la tarjeta "Órdenes Facturadas"
      // (Fact_Ventas es una tabla distinta de Fact_Pedidos: una factura no es lo
      // mismo que un pedido/orden de laboratorio).
      req().query(`
        SELECT COUNT(DISTINCT id_factura) AS valor
        FROM dbo.Fact_Ventas
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
      `),

      // C-1.8 — Clientes Nuevos: KPI_Inf1_Clientes_Nuevos (DAX real) — UNION de
      // fecha de registro (Dim_Clientes) + fecha de primera actividad (Fact_Ventas
      // UNION Fact_Pedidos). Paridad exacta con Power BI, incluyendo el artefacto de
      // backfill de junio 2026 (reportado aparte a VisioFlow, no se corrige acá).
      req().query(`
        SELECT COUNT(DISTINCT id_cliente) AS valor
        FROM dbo.KPI_Inf1_Clientes_Nuevos
        WHERE fecha_evento BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
      `),
    ]);

    const ventaNetaRow      = (ventaNetaRes.recordset    as VentaNetaRow[])[0];
    const ventaNetaYtdRow   = (ventaNetaYtdRes.recordset as VentaNetaRow[])[0];
    const ventaNetaUsd         = Number(ventaNetaRow?.ventaNetaUsd ?? 0);
    const ventaNetaSinIvaUsd   = Number(ventaNetaRow?.ventaNetaSinIvaUsd ?? 0);
    const ventaNetaYTDUsd      = Number(ventaNetaYtdRow?.ventaNetaUsd ?? 0);
    const ventaNetaYTDSinIvaUsd = Number(ventaNetaYtdRow?.ventaNetaSinIvaUsd ?? 0);
    const proyeccionUsd     = Number((proyeccionRes.recordset as ValorRow[])[0]?.valor ?? 0);
    const totalCobradoUsd   = Number((cobradoRes.recordset    as ValorRow[])[0]?.valor ?? 0);
    const cantidadPedidos   = Number((pedidosRes.recordset as PedidosRow[])[0]?.cantidadPedidos ?? 0);
    const cantidadFacturas  = Number((facturasRes.recordset as ValorRow[])[0]?.valor ?? 0);
    const clientesNuevos    = Number((clientesNuevosRes.recordset as ValorRow[])[0]?.valor ?? 0);

    // C-1.4 — Ticket Promedio: DIVIDE([Venta Neta USD], [Cantidad Facturas], 0) —
    // el denominador real del DAX es Fact_Ventas.id_factura, NO Fact_Pedidos.id_pedido
    // (confirmado con evidencia: son tablas distintas, factura ≠ pedido/orden de lab).
    const ticketPromedioUsd = cantidadFacturas > 0
      ? Math.round((ventaNetaUsd / cantidadFacturas) * 100) / 100
      : 0;

    return {
      ventaNetaYTDUsd,
      ventaNetaYTDSinIvaUsd,
      ventaNetaUsd,
      ventaNetaSinIvaUsd,
      proyeccionUsd,
      totalCobradoUsd,
      ticketPromedioUsd,
      cantidadPedidos,
      cantidadFacturas,
      clientesNuevos,
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
    const { sucursales, allowedSucursales } = params;
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
        ISNULL(SUM(monto_neto_usd), 0)                                               AS ventaMensualUsd,
        COUNT(DISTINCT id_factura)                                                    AS trafico
      FROM dbo.KPI_Inf1_Venta_Neta
      WHERE anio_factura = YEAR(SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00'))
        ${buildSucursalFilter("", sucursales, allowedSucursales)}
      GROUP BY anio_factura, mes_factura_nro, periodo_factura
      ORDER BY anio_factura, mes_factura_nro ASC
    `);

    return (res.recordset as VentasKpiRow[]).map((r) => {
      const mesNum = Number(r.mes_nro ?? 1);
      return {
        periodo:          String(r.periodo ?? `${r.anio}-${String(mesNum).padStart(2, "0")}`),
        label:            `${MES_ABBR[String(mesNum).padStart(2, "0")] ?? String(mesNum)} '${String(r.anio).slice(-2)}`,
        ventaNetaUsd:     Number(r.ventaMensualUsd ?? 0),
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
    const { startDate, endDate, sucursales, allowedSucursales } = params;
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

      SELECT
        vn.idSucursal,
        ds.nombre_sucursal              AS nombreSucursal,
        vn.ventaNetaUsd,
        ISNULL(pv.estimado, 0)         AS estimadoCierreUsd
      FROM (
        SELECT
          id_sucursal                  AS idSucursal,
          ISNULL(ROUND(SUM(monto_neto_usd), 2), 0)  AS ventaNetaUsd
        FROM dbo.KPI_Inf1_Venta_Neta
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
        GROUP BY id_sucursal
      ) vn
      INNER JOIN dbo.Dim_Sucursales ds ON ds.id_sucursal = vn.idSucursal
      LEFT JOIN (
        SELECT
          id_sucursal,
          ISNULL(ROUND(CASE
            WHEN @AnioStart < @AnioHoyGMT4 OR (@AnioStart = @AnioHoyGMT4 AND @MesStart < @MesHoyGMT4)
              THEN SUM(monto_neto_usd)
            ELSE SUM(CAST(monto_neto_usd AS DECIMAL(18,4))) / NULLIF(CAST(@DiasTranscurridos AS DECIMAL(18,4)), 0) * CAST(@UltimoDiaMes AS DECIMAL(18,4))
          END, 2), 0) AS estimado
        FROM dbo.KPI_Inf1_Proyeccion_Venta_Neta
        WHERE fecha_factura BETWEEN @startDate AND @endDate
          ${buildSucursalFilter("", sucursales, allowedSucursales)}
        GROUP BY id_sucursal
      ) pv ON pv.id_sucursal = vn.idSucursal
      ORDER BY vn.ventaNetaUsd DESC
    `);

    return (res.recordset as TopSucursalRow[]).map((r) => ({
      idSucursal:        Number(r.idSucursal),
      nombreSucursal:    String(r.nombreSucursal ?? ""),
      ventaNetaUsd:      Number(r.ventaNetaUsd ?? 0),
      estimadoCierreUsd: Number(r.estimadoCierreUsd ?? 0),
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
    const { startDate, endDate, sucursales, allowedSucursales } = params;
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
        metodo_pago                          AS medioPago,
        ISNULL(SUM(importe_neto_usd), 0)     AS montoUsd
      FROM dbo.Fact_Recaudo
      WHERE fecha_completa BETWEEN @startDate AND @endDate
        ${buildSucursalFilter("", sucursales, allowedSucursales)}
      GROUP BY metodo_pago
      ORDER BY montoUsd DESC
    `);

    const rawMedios = (res.recordset as MedioPagoRow[]).map((r) => ({
      medioPago: r.medioPago ?? "",
      montoUsd:  Number(r.montoUsd ?? 0),
    }));
    const totalMonto = rawMedios.reduce((acc, r) => acc + r.montoUsd, 0);
    return rawMedios.map((r) => ({
      ...r,
      porcentaje:
        totalMonto > 0 ? Math.round((r.montoUsd / totalMonto) * 10000) / 100 : 0,
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
    });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getMediosPago]", err);
    return { success: false, error: "Error al obtener medios de pago." };
  }
}
