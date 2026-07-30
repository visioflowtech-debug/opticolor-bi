import { format, startOfMonth } from "date-fns";
import { Suspense } from "react";

import {
  formatCompactCurrency,
  formatCompactNumber,
  formatCurrency,
} from "@/lib/utils";

import { getEficienciaKPIs } from "./_actions/get-eficiencia-data";
import { KpiCard } from "../resumen-comercial/_components/kpi-card";
import { TendenciaOrdenesChartWrapper } from "./_components/tendencia-ordenes-chart-wrapper";
import { TipoLenteChartWrapper } from "./_components/tipo-lente-chart-wrapper";
import { OrdenesSucursalChartWrapper } from "./_components/ordenes-sucursal-chart-wrapper";
import { DetalleCristalesTableWrapper } from "./_components/detalle-cristales-table-wrapper";
import { ChartSkeleton, TableSkeleton } from "../_components/skeletons";

type SearchParams = Promise<{ from?: string; to?: string; sucursal?: string }>;

const EMPTY_KPIS = {
  ordenesHoy: 0,
  volumenOrdenes: 0,
  promedioDiario: 0,
  montoTotalUsd: 0,
};

export default async function EficienciaPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { from, to, sucursal } = await searchParams;

  // `from`/`to` ya llegan en formato "yyyy-MM-dd" desde el date-range-picker —
  // NO se deben reparsear con `new Date(...)`: un string solo-fecha se interpreta
  // como medianoche UTC, y volver a formatearlo con la zona horaria local del
  // servidor puede correr la fecha un día completo hacia atrás (ver Prompt 2-4).
  const startDate = from ?? format(startOfMonth(new Date()), "yyyy-MM-dd");
  const endDate = to ?? format(new Date(), "yyyy-MM-dd");
  const sucursales = sucursal && sucursal !== "all" ? sucursal : null;

  const result = await getEficienciaKPIs({ startDate, endDate, sucursales });
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
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          title="Órdenes Hoy"
          value={kpis.ordenesHoy.toLocaleString("en-US")}
          fullValue={kpis.ordenesHoy.toLocaleString("en-US")}
          iconName="shopping-cart"
          highlight
        />
        <KpiCard
          title="Volumen de Órdenes"
          value={formatCompactNumber(kpis.volumenOrdenes)}
          fullValue={kpis.volumenOrdenes.toLocaleString("en-US")}
          iconName="package"
        />
        <KpiCard
          title="Promedio Órdenes Diario"
          value={kpis.promedioDiario.toFixed(1)}
          fullValue={kpis.promedioDiario.toFixed(2)}
          iconName="trending-up"
        />
        <KpiCard
          title="Monto Total Órdenes"
          value={formatCompactCurrency(kpis.montoTotalUsd, { currency: "USD" })}
          fullValue={formatCurrency(kpis.montoTotalUsd, { currency: "USD" })}
          iconName="dollar-sign"
        />
      </div>

      {/* ── Fila 2: Tendencia de Órdenes ────────── */}
      <Suspense fallback={<ChartSkeleton title="Tendencia de Órdenes" height="h-72" />}>
        <TendenciaOrdenesChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
      </Suspense>

      {/* ── Fila 3: Detalle por Tipo y Órdenes por Sucursal ────────── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<ChartSkeleton title="Detalle de Órdenes por Tipo" height="h-[500px]" />}>
          <TipoLenteChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Órdenes Ejecutadas por Sucursal" height="h-[500px]" />}>
          <OrdenesSucursalChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>
      </div>

      {/* ── Fila 4: Detalle de Cristales ────────── */}
      <Suspense fallback={<TableSkeleton title="Detalle de Órdenes de Cristales por Tipo" rows={5} />}>
        <DetalleCristalesTableWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
      </Suspense>
    </div>
  );
}
