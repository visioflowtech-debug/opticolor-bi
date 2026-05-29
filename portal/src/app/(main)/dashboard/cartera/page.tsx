import { format, startOfMonth } from "date-fns";
import { Suspense } from "react";

import {
  formatCompactCurrency,
  formatCompactNumber,
  formatCurrency,
} from "@/lib/utils";

import { getCarteraKPIs } from "./_actions/get-cartera-data";
import { KpiCard } from "../resumen-comercial/_components/kpi-card";
import { GapCobroChartWrapper } from "./_components/gap-cobro-chart-wrapper";
import { MixVentasChartWrapper } from "./_components/mix-ventas-chart-wrapper";
import { CarteraSucursalChartWrapper } from "./_components/cartera-sucursal-chart-wrapper";
import { ClientesDeudoresTableWrapper } from "./_components/clientes-deudores-table-wrapper";
import { ChartSkeleton, TableSkeleton } from "../_components/skeletons";

type SearchParams = Promise<{ from?: string; to?: string; sucursal?: string }>;

const EMPTY_KPIS = {
  montoPedidos: 0,
  recaudado: 0,
  saldoPendiente: 0,
  pedidosLiquidar: 0,
  pctCobroInmediato: 0,
  pctNivelAbono: 0,
};

export default async function CarteraPage({
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

  const result = await getCarteraKPIs({ startDate, endDate, sucursales });
  const kpis = result.data ?? EMPTY_KPIS;

  return (
    <div className="w-full max-w-full px-4 pb-6 md:px-6 space-y-6 overflow-hidden">
      {/* Banner de error no crítico */}
      {!result.success && (
        <div className="rounded-xl border border-destructive/30 bg-destructive/10 px-4 py-2.5 text-sm text-destructive">
          {result.error ?? "No se pudieron cargar los datos de KPI. Intenta de nuevo."}
        </div>
      )}

      {/* ── Fila 1: KPIs ────────── */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <KpiCard
          title="Monto Ordenes"
          value={formatCompactCurrency(kpis.montoPedidos)}
          fullValue={formatCurrency(kpis.montoPedidos)}
          iconName="dollar-sign"
        />
        <KpiCard
          title="Recaudado en Ordenes"
          value={formatCompactCurrency(kpis.recaudado)}
          fullValue={formatCurrency(kpis.recaudado)}
          iconName="wallet"
        />
        <KpiCard
          title="Monto Saldo Pendiente"
          value={formatCompactCurrency(kpis.saldoPendiente)}
          fullValue={formatCurrency(kpis.saldoPendiente)}
          iconName="alert-triangle"
          highlight
        />
        <KpiCard
          title="Ordenes por Liquidar"
          value={formatCompactNumber(kpis.pedidosLiquidar)}
          fullValue={kpis.pedidosLiquidar.toLocaleString("en-US")}
          iconName="clipboard-list"
        />
        <KpiCard
          title="% Primer Abono"
          value={`${kpis.pctCobroInmediato.toFixed(1)}%`}
          fullValue={`${kpis.pctCobroInmediato.toFixed(2)}%`}
          iconName="percent"
        />
        <KpiCard
          title="% Pago Total"
          value={`${kpis.pctNivelAbono.toFixed(1)}%`}
          fullValue={`${kpis.pctNivelAbono.toFixed(2)}%`}
          iconName="percent"
        />
      </div>

      {/* ── Fila 2: GAP de Cobro ────────── */}
      <Suspense fallback={<ChartSkeleton title="Tendencia de la Cartera · GAP de Cobro" height="h-72" />}>
        <GapCobroChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
      </Suspense>

      {/* ── Fila 3: Mix de Ventas y Cartera por Sucursal ────────── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<ChartSkeleton title="Mix de Ventas · Participación y Monto Neto" height="h-64" />}>
          <MixVentasChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Cartera Pendiente por Sucursal" height="h-64" />}>
          <CarteraSucursalChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>
      </div>

      {/* ── Fila 4: Clientes Deudores ────────── */}
      <Suspense fallback={<TableSkeleton title="Clientes Deudores" rows={10} />}>
        <ClientesDeudoresTableWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
      </Suspense>
    </div>
  );
}
