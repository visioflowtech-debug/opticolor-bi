import { format, startOfMonth } from "date-fns";
import { Suspense } from "react";

import {
  formatCompactCurrency,
  formatCompactNumber,
  formatCurrency,
} from "@/lib/utils";

import { getResumenKPIs } from "./_actions/get-resumen-data";
import { KpiCard } from "./_components/kpi-card";
import { MediosPagoChartWrapper } from "./_components/medios-pago-chart-wrapper";
import { SucursalesChartWrapper } from "./_components/sucursales-chart-wrapper";
import { VentasChartWrapper } from "./_components/ventas-chart-wrapper";
import { ChartSkeleton } from "../_components/skeletons";

type SearchParams = Promise<{ from?: string; to?: string; sucursal?: string }>;

const EMPTY_KPIS = {
  ventaNetaYTD: 0,
  ventaNeta: 0,
  proyeccion: 0,
  totalCobrado: 0,
  ticketPromedio: 0,
  cantidadPedidos: 0,
  totalExamenes: 0,
  clientesNuevos: 0,
};

export default async function ResumenComercialPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { from, to, sucursal } = await searchParams;

  const startDate = from
    ? format(new Date(from), "yyyy-MM-dd")
    : format(startOfMonth(new Date()), "yyyy-MM-dd");
  const endDate = to
    ? format(new Date(to), "yyyy-MM-dd")
    : format(new Date(), "yyyy-MM-dd");
  const sucursales = sucursal && sucursal !== "all" ? sucursal : null;

  const result = await getResumenKPIs({ startDate, endDate, sucursales });
  const kpis = result.data ?? EMPTY_KPIS;

  // proyeccionPct: compara venta real del período filtrado vs su proyección al cierre
  const proyeccionPct =
    kpis.proyeccion > 0 ? Math.round((kpis.ventaNeta / kpis.proyeccion) * 100) : 0;

  const pendienteCobro = kpis.ventaNeta - kpis.totalCobrado;

  return (
    <div className="w-full max-w-full px-4 pb-6 md:px-6 space-y-6 overflow-hidden">
      {/* Banner de error no crítico */}
      {!result.success && (
        <div className="rounded-xl border border-destructive/30 bg-destructive/10 px-4 py-2.5 text-sm text-destructive">
          {result.error ?? "No se pudieron cargar los datos de KPI. Intenta de nuevo."}
        </div>
      )}

      {/* ── KPIs Principales (8 Tarjetas) ────────── */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
        <KpiCard
          title="Venta Neta"
          value={formatCompactCurrency(kpis.ventaNeta)}
          fullValue={formatCurrency(kpis.ventaNeta)}
          iconName="dollar-sign"
          highlight
        />
        <KpiCard
          title="Proyección Cierre"
          value={formatCompactCurrency(kpis.proyeccion)}
          fullValue={formatCurrency(kpis.proyeccion)}
          subtitle={`${proyeccionPct}% del objetivo alcanzado`}
          iconName="trending-up"
        />
        <KpiCard
          title="Total Cobrado"
          value={formatCompactCurrency(kpis.totalCobrado)}
          fullValue={formatCurrency(kpis.totalCobrado)}
          subtitle={
            pendienteCobro > 0
              ? `${formatCompactCurrency(pendienteCobro)} pendiente de cobro`
              : "Sin pendientes"
          }
          iconName="credit-card"
        />
        <KpiCard
          title="Ticket Promedio"
          value={formatCompactCurrency(kpis.ticketPromedio)}
          fullValue={formatCurrency(kpis.ticketPromedio)}
          iconName="bar-chart-3"
        />
        <KpiCard
          title="Venta Neta YTD"
          value={formatCompactCurrency(kpis.ventaNetaYTD)}
          fullValue={formatCurrency(kpis.ventaNetaYTD)}
          iconName="dollar-sign"
        />
        <KpiCard
          title="Ordenes Facturadas"
          value={formatCompactNumber(kpis.cantidadPedidos)}
          fullValue={kpis.cantidadPedidos.toLocaleString("en-US")}
          iconName="shopping-cart"
        />
        <KpiCard
          title="Total Exámenes"
          value={formatCompactNumber(kpis.totalExamenes)}
          fullValue={kpis.totalExamenes.toLocaleString("en-US")}
          iconName="eye"
        />
        <KpiCard
          title="Clientes Nuevos"
          value={formatCompactNumber(kpis.clientesNuevos)}
          fullValue={kpis.clientesNuevos.toLocaleString("en-US")}
          iconName="user-plus"
        />
      </div>

      {/* ── Fila 3: Distribución — Top Sucursales | Medios de Pago ──────────── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<ChartSkeleton title="Top 10 Sucursales · Venta Neta" height="h-64" />}>
          <SucursalesChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Distribución · Medios de Pago" height="h-52" />}>
          <MediosPagoChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>
      </div>

      {/* ── Fila 4: Tendencia anual YTD — ancho completo ────────────────────── */}
      <Suspense fallback={<ChartSkeleton title="Tendencia Anual · Ventas y Tráfico" height="h-[350px]" />}>
        <VentasChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
      </Suspense>
    </div>
  );
}
