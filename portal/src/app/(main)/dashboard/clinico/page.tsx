import { Suspense } from "react";

import { formatNumber, formatPercent } from "@/lib/utils";
import { getDefaultDateRangeGMT4 } from "@/lib/date-utils";

import { getClinicaKPIs } from "./_actions/get-clinica-data";
import { KpiCard } from "../resumen-comercial/_components/kpi-card";
import { TendenciaExamenesChartWrapper } from "./_components/tendencia-examenes-chart-wrapper";
import { VolumenConversionChartWrapper } from "./_components/volumen-conversion-chart-wrapper";
import { GeneroChartWrapper } from "./_components/genero-chart-wrapper";
import { EdadChartWrapper } from "./_components/edad-chart-wrapper";
import { TopSucursalesClinicaChartWrapper } from "./_components/top-sucursales-clinica-chart-wrapper";
import { ChartSkeleton } from "../_components/skeletons";

type SearchParams = Promise<{ from?: string; to?: string; sucursal?: string }>;

const EMPTY_KPIS = {
  totalExamenes: 0,
  pctConversion: 0,
  examenesHoy: 0,
  promedioDiario: 0,
  convertidos: 0,
  noConvertidos: 0,
};

export default async function ClinicaPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { from, to, sucursal } = await searchParams;

  // `from`/`to` ya llegan en formato "yyyy-MM-dd" desde el date-range-picker —
  // NO se deben reparsear con `new Date(...)`: un string solo-fecha se interpreta
  // como medianoche UTC, y volver a formatearlo con la zona horaria local del
  // servidor puede correr la fecha un día completo hacia atrás (ver Prompt 2-4).
  const defaultRange = getDefaultDateRangeGMT4();
  const startDate = from ?? defaultRange.startDate;
  const endDate = to ?? defaultRange.endDate;
  const sucursales = sucursal && sucursal !== "all" ? sucursal : null;

  const result = await getClinicaKPIs({ startDate, endDate, sucursales });
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
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <KpiCard
          title="Exámenes Hoy"
          value={formatNumber(kpis.examenesHoy)}
          iconName="activity"
          highlight
        />
        <KpiCard
          title="Total Exámenes"
          value={formatNumber(kpis.totalExamenes)}
          iconName="users"
        />
        <KpiCard
          title="% Conversión"
          value={formatPercent(kpis.pctConversion)}
          iconName="check-circle"
        />
        <KpiCard
          title="Promedio Diario"
          value={formatNumber(kpis.promedioDiario)}
          iconName="calendar"
        />
        <KpiCard
          title="Convertidos"
          value={formatNumber(kpis.convertidos)}
          iconName="clipboard"
        />
        <KpiCard
          title="No Convertidos"
          value={formatNumber(kpis.noConvertidos)}
          iconName="x-circle"
        />
      </div>

      {/* ── Fila 4: Tendencia Full Width ────────── */}
      <Suspense fallback={<ChartSkeleton title="Tendencia de Exámenes por Mes" height="h-72" />}>
        <TendenciaExamenesChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
      </Suspense>

      {/* ── Fila 3: Género y Edad ────────── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<ChartSkeleton title="Distribución de Pacientes por Género" height="h-52" />}>
          <GeneroChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Distribución de Pacientes por Rango de Edad" height="h-[350px]" />}>
          <EdadChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>
      </div>

      {/* ── Fila 2: Exámenes: Volumen Total vs. Conversión ────────── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<ChartSkeleton title="Top Sucursales por Volumen de Exámenes" height="h-[500px]" />}>
          <TopSucursalesClinicaChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Exámenes: Volumen Total vs. Conversión" height="h-[350px]" />}>
          <VolumenConversionChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>
      </div>
    </div>
  );
}
