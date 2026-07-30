"use server";

import { unstable_cache } from "next/cache";

import { getConnection } from "@/lib/db";
import { buildSucursalFilter } from "@/lib/sql-helpers";
import { getAuthContext } from "@/lib/get-auth-context";
import { getUserAllowedSucursales } from "@/lib/security";

// ─── Tipos exportados ─────────────────────────────────────────────────────────

export type CarteraKpiData = {
  montoPedidosUsd: number;
  recaudadoUsd: number;
  saldoPendienteUsd: number;
  pedidosLiquidar: number;
};

export type GapCobro = {
  mes_pedido_nombre: string;
  monto_total_usd: number;
  saldo_pendiente_usd: number;
};

export type MixVenta = {
  categoria_agrupada: string;
  venta_neta_usd: number;
  facturas: number;
};

export type CarteraSucursal = {
  nombre_sucursal: string;
  saldo_pendiente_usd: number;
};

export type ClienteDeudor = {
  nombre_sucursal: string;
  nombre_completo: string;
  monto_total_usd: number;
  monto_pagado_usd: number;
  saldo_pendiente_usd: number;
};

import { ReportParams } from "@/types/dashboard";

export type Params = ReportParams;

type FetchParams = Params & { allowedSucursales: string };

// ─── Tipos de fila DB (privados) ─────────────────────────────────────────────

type ValorRow         = { valor: number };
type GapCobroRow      = { mes_pedido_nombre: string; monto_total_usd: number; saldo_pendiente_usd: number };
type MixVentaRow      = { categoria_agrupada: string; venta_neta_usd: number; facturas: number };
type CarteraSucRow    = { nombre_sucursal: string; saldo_pendiente_usd: number };
type ClienteDeudorRow = { nombre_sucursal: string; nombre_completo: string; monto_total_usd: number; monto_pagado_usd: number; saldo_pendiente_usd: number };

// ─── Cache & Actions ─────────────────────────────────────────────────────────

// 1. KPIs
const fetchCarteraKPIs = unstable_cache(
  async (params: FetchParams): Promise<CarteraKpiData> => {
    const { startDate, endDate, sucursales, allowedSucursales } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("startDate",         startDate)
        .input("endDate",           endDate)
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales);

    const [
      montoPedidosRes,
      recaudadoRes,
      saldoPendienteRes,
      pedidosLiquidarRes,
    ] = await Promise.all([
      // C-2.1 Monto Pedidos
      req().query(`
        SELECT ISNULL(SUM(monto_total_usd), 0) AS valor
        FROM dbo.KPI_Inf3_Monto_Pedidos
        WHERE CAST(fecha_pedido_completa AS DATE) BETWEEN @startDate AND @endDate
          ${buildSucursalFilter()}
      `),

      // C-2.2 Recaudado en Pedidos — dinero abonado sobre órdenes nacidas en el período
      req().query(`
        SELECT ISNULL(SUM(monto_pagado_usd), 0) AS valor
        FROM dbo.KPI_Inf3_Recaudado_Pedidos
        WHERE CAST(fecha_pedido_completa AS DATE) BETWEEN @startDate AND @endDate
          ${buildSucursalFilter()}
      `),

      // C-2.3 Saldo Pendiente — histórico total vigente de la sucursal, SIN filtro de
      // fecha (paridad con la medida DAX de Power BI: esta tarjeta no está conectada
      // al slicer de fecha, solo al de sucursal). Lee directo de Fact_Pedidos, NO de
      // la vista KPI_Inf3_Saldo_Pendiente — esa vista filtra WHERE saldo_pendiente > 0
      // (columna en Bs), lo que excluye filas con saldo_pendiente_usd > 0 pero cuyo
      // equivalente en Bs es <= 0 (confirmado con evidencia: 14 filas, $294.41 USD
      // excluidas indebidamente). El DAX real suma sin ningún filtro.
      req().query(`
        SELECT ROUND(COALESCE(SUM(saldo_pendiente_usd), 0), 2) AS valor
        FROM dbo.Fact_Pedidos
        WHERE 1=1
          ${buildSucursalFilter()}
      `),

      // C-2.4 Pedidos por Liquidar — histórico total vigente de la sucursal, SIN
      // filtro de fecha (misma paridad con Power BI que Saldo Pendiente). Lee directo
      // de Fact_Pedidos filtrando por saldo_pendiente_usd > 0, NO de la vista
      // KPI_Inf3_Pedidos_Liquidar (mismo filtro en Bs que Saldo Pendiente — confirmado
      // con evidencia: el error es bidireccional, 14 filas con saldo Bs<=0 pero
      // saldo_pendiente_usd>0 que la vista excluía indebidamente, y ~72-104 filas con
      // saldo Bs>0 residual/redondeo pero saldo_pendiente_usd<=0 que la vista incluía
      // indebidamente — el efecto neto es una reducción del conteo, no un aumento).
      req().query(`
        SELECT COUNT(DISTINCT id_pedido) AS valor
        FROM dbo.Fact_Pedidos
        WHERE saldo_pendiente_usd > 0
          ${buildSucursalFilter()}
      `),
    ]);

    return {
      montoPedidosUsd:   Number((montoPedidosRes.recordset    as ValorRow[])[0]?.valor ?? 0),
      recaudadoUsd:      Number((recaudadoRes.recordset        as ValorRow[])[0]?.valor ?? 0),
      saldoPendienteUsd: Number((saldoPendienteRes.recordset   as ValorRow[])[0]?.valor ?? 0),
      pedidosLiquidar:   Number((pedidosLiquidarRes.recordset  as ValorRow[])[0]?.valor ?? 0),
    };
  },
  ["dash-cartera-kpis"],
  { revalidate: 3600, tags: ["dash-cartera-kpis"] }
);

export async function getCarteraKPIs(
  params: Params,
): Promise<{ success: boolean; data?: CarteraKpiData; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchCarteraKPIs({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getCarteraKPIs]", err);
    return { success: false, error: "Error al obtener KPIs de cartera." };
  }
}

// 2. GAP Cobro — 3 series: Monto Pedidos, Saldo Pendiente, Recaudado
// Tendencia de los últimos 12 meses, SIN vínculo al slicer de fecha (paridad con
// Power BI: confirmado por Edit Interactions/Performance Analyzer que este gráfico
// no reacciona al filtro de fecha, solo al de sucursal). La ventana se ancla a
// GETDATE() — antes usaba @endDate, lo que hacía que el gráfico se vaciara por
// completo si el usuario seleccionaba un rango fuera de los últimos 12 meses.
const fetchGapCobro = unstable_cache(
  async (params: FetchParams): Promise<GapCobro[]> => {
    const { sucursales, allowedSucursales } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales);

    const res = await req().query(`
      SELECT
        mes_pedido_nombre,
        anio_pedido,
        mes_pedido_nro,
        ISNULL(SUM(monto_total_usd),     0) AS monto_total_usd,
        ISNULL(SUM(saldo_pendiente_usd), 0) AS saldo_pendiente_usd
      FROM dbo.KPI_Inf3_Monto_Pedidos
      WHERE CAST(fecha_pedido_completa AS DATE) >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
        ${buildSucursalFilter()}
      GROUP BY mes_pedido_nombre, anio_pedido, mes_pedido_nro
      ORDER BY anio_pedido ASC, mes_pedido_nro ASC
    `);

    return (res.recordset as GapCobroRow[]).map((r) => ({
      mes_pedido_nombre:   String(r.mes_pedido_nombre ?? ""),
      monto_total_usd:     Number(r.monto_total_usd ?? 0),
      saldo_pendiente_usd: Number(r.saldo_pendiente_usd ?? 0),
    }));
  },
  ["dash-cartera-gap-cobro"],
  { revalidate: 3600, tags: ["dash-cartera-gap-cobro"] }
);

export async function getGapCobroData(
  params: Params,
): Promise<{ success: boolean; data?: GapCobro[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchGapCobro({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getGapCobroData]", err);
    return { success: false, error: "Error al obtener tendencia de cartera." };
  }
}

// 3. Mix Ventas
const fetchMixVentas = unstable_cache(
  async (params: FetchParams): Promise<MixVenta[]> => {
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
        categoria_agrupada,
        ISNULL(SUM(venta_neta_usd), 0)   AS venta_neta_usd,
        COUNT(DISTINCT id_factura)        AS facturas
      FROM dbo.Fact_Ventas_por_Categoria
      WHERE CAST(fecha_factura AS DATE) BETWEEN @startDate AND @endDate
        ${buildSucursalFilter()}
      GROUP BY categoria_agrupada
      ORDER BY venta_neta_usd DESC
    `);

    return (res.recordset as MixVentaRow[]).map((r) => ({
      categoria_agrupada: String(r.categoria_agrupada ?? ""),
      venta_neta_usd:     Number(r.venta_neta_usd ?? 0),
      facturas:           Number(r.facturas ?? 0),
    }));
  },
  ["dash-cartera-mix-ventas"],
  { revalidate: 3600, tags: ["dash-cartera-mix-ventas"] }
);

export async function getMixVentasData(
  params: Params,
): Promise<{ success: boolean; data?: MixVenta[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchMixVentas({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getMixVentasData]", err);
    return { success: false, error: "Error al obtener mix de ventas." };
  }
}

// 4. Cartera Sucursal
const fetchCarteraSucursal = unstable_cache(
  async (params: FetchParams): Promise<CarteraSucursal[]> => {
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
        ds.nombre_sucursal,
        ROUND(COALESCE(SUM(k.saldo_pendiente_usd), 0), 2) AS saldo_pendiente_usd
      FROM dbo.KPI_Inf3_Saldo_Pendiente k
      LEFT JOIN dbo.Dim_Sucursales ds ON k.id_sucursal = ds.id_sucursal
      WHERE CAST(k.fecha_pedido_completa AS DATE) <= @endDate
        ${buildSucursalFilter("k")}
      GROUP BY ds.nombre_sucursal
      ORDER BY saldo_pendiente_usd DESC
    `);

    return (res.recordset as CarteraSucRow[]).map((r) => ({
      nombre_sucursal:     String(r.nombre_sucursal ?? ""),
      saldo_pendiente_usd: Number(r.saldo_pendiente_usd ?? 0),
    }));
  },
  ["dash-cartera-sucursal"],
  { revalidate: 3600, tags: ["dash-cartera-sucursal"] }
);

export async function getCarteraSucursalData(
  params: Params,
): Promise<{ success: boolean; data?: CarteraSucursal[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchCarteraSucursal({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getCarteraSucursalData]", err);
    return { success: false, error: "Error al obtener cartera por sucursal." };
  }
}

// 5. Clientes Deudores — histórico total vigente de la sucursal, SIN filtro de
// fecha (paridad con Power BI: confirmado que la tabla "Top de Clientes
// Deudores" tampoco está vinculada al slicer de fecha, solo al de sucursal —
// misma lógica que Saldo Pendiente/Pedidos por Liquidar). Con este cambio, la
// suma de esta tabla vuelve a cuadrar con la tarjeta "Monto Saldo Pendiente".
const fetchClientesDeudores = unstable_cache(
  async (params: FetchParams): Promise<ClienteDeudor[]> => {
    const { sucursales, allowedSucursales } = params;
    const pool = await getConnection();

    const req = () =>
      pool
        .request()
        .input("sucursales",        sucursales)
        .input("allowedSucursales", allowedSucursales);

    const res = await req().query(`
      SELECT
        ds.nombre_sucursal,
        ISNULL(dc.nombre_completo, 'CLIENTE NO CATALOGADO') AS nombre_completo,
        ISNULL(SUM(fp.monto_total_usd),     0) AS monto_total_usd,
        ISNULL(SUM(fp.monto_pagado_usd),    0) AS monto_pagado_usd,
        ISNULL(SUM(fp.saldo_pendiente_usd), 0) AS saldo_pendiente_usd
      FROM dbo.Fact_Pedidos fp
      LEFT JOIN dbo.Dim_Clientes     dc ON fp.id_cliente   = dc.id_cliente
      INNER JOIN dbo.Dim_Sucursales  ds ON fp.id_sucursal  = ds.id_sucursal
      WHERE 1=1
        ${buildSucursalFilter("fp")}
      GROUP BY ds.nombre_sucursal, dc.nombre_completo
      HAVING ISNULL(SUM(fp.saldo_pendiente_usd), 0) > 0
      ORDER BY saldo_pendiente_usd DESC
    `);

    return (res.recordset as ClienteDeudorRow[]).map((r) => ({
      nombre_sucursal:     String(r.nombre_sucursal ?? ""),
      nombre_completo:     String(r.nombre_completo ?? ""),
      monto_total_usd:     Number(r.monto_total_usd ?? 0),
      monto_pagado_usd:    Number(r.monto_pagado_usd ?? 0),
      saldo_pendiente_usd: Number(r.saldo_pendiente_usd ?? 0),
    }));
  },
  ["dash-cartera-clientes-deudores"],
  { revalidate: 3600, tags: ["dash-cartera-clientes-deudores"] }
);

export async function getClientesDeudoresTabla(
  params: Params,
): Promise<{ success: boolean; data?: ClienteDeudor[]; error?: string }> {
  try {
    const auth = await getAuthContext();
    if (!auth) return { success: false, error: "No autorizado" };
    const allowedSucursales = await getUserAllowedSucursales(auth.userId);
    const data = await fetchClientesDeudores({ ...params, allowedSucursales });
    return { success: true, data };
  } catch (err) {
    console.error("[ERROR][getClientesDeudoresTabla]", err);
    return { success: false, error: "Error al obtener clientes deudores." };
  }
}
