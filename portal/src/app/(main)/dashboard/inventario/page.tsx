import { AlertTriangle } from "lucide-react";
import { Suspense } from "react";

import {
  formatCurrency,
  formatNumber,
} from "@/lib/utils";
import { getDefaultDateRangeGMT4 } from "@/lib/date-utils";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

import { getInventarioKPIs } from "./_actions/get-inventario-data";
import { KpiCard } from "./_components/kpi-card";
import { DetalleTableWrapper } from "./_components/detalle-table-wrapper";
import { DispersionChartWrapper } from "./_components/dispersion-chart-wrapper";
import { RankingMarcasChartWrapper } from "./_components/ranking-marcas-chart-wrapper";
import { TreemapChartWrapper } from "./_components/treemap-chart-wrapper";
import { ChartSkeleton, TableSkeleton } from "../_components/skeletons";

type SearchParams = Promise<{
  from?: string;
  to?: string;
  sucursal?: string;
  marca?: string;
  grupo?: string;
}>;

const EMPTY_KPIS = {
  stockFisico: 0,
  capitalInvertidoUsd: 0,
  unidadesVendidas: 0,
  ventaNetaProducto: 0,
  upt: 0,
};

export default async function InventarioPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { from, to, sucursal, marca, grupo } = await searchParams;

  // `from`/`to` ya llegan en formato "yyyy-MM-dd" desde el date-range-picker —
  // NO se deben reparsear con `new Date(...)`: un string solo-fecha se interpreta
  // como medianoche UTC, y volver a formatearlo con la zona horaria local del
  // servidor puede correr la fecha un día completo hacia atrás (ver Prompt 2-4).
  const defaultRange = getDefaultDateRangeGMT4();
  const startDate = from ?? defaultRange.startDate;
  const endDate = to ?? defaultRange.endDate;
  const sucursales = sucursal && sucursal !== "all" ? sucursal : null;
  const marcaFilter = marca && marca !== "all" ? marca : null;
  const grupoFilter = grupo && grupo !== "all" ? grupo : null;

  const result = await getInventarioKPIs({
    startDate,
    endDate,
    sucursales,
    marcaFilter,
    grupoFilter,
  });
  const kpis = result.data ?? EMPTY_KPIS;

  return (
    <div className="w-full max-w-full px-4 pb-6 md:px-6 space-y-6 overflow-hidden">
      {/* Banner de error no crítico */}
      {!result.success && (
        <div className="rounded-xl border border-destructive/30 bg-destructive/10 px-4 py-2.5 text-sm text-destructive">
          {result.error ?? "No se pudieron cargar los datos de KPI. Intenta de nuevo."}
        </div>
      )}

      {/* ── Fila 1: 4 KPI Cards ──────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          title="Stock Físico"
          value={formatNumber(kpis.stockFisico)}
          subtitle="Snapshot · hasta hoy"
          iconName="archive"
          highlight
        />
        <KpiCard
          title="Capital Invertido"
          value={formatCurrency(kpis.capitalInvertidoUsd, { currency: "USD" })}
          subtitle="Snapshot · hasta hoy"
          iconName="dollar-sign"
        />
        <KpiCard
          title="Unidades Vendidas"
          value={formatNumber(kpis.unidadesVendidas)}
          iconName="trending-up"
        />
        <div className="relative">
          <KpiCard
            title="UPT"
            value={formatNumber(kpis.upt, { decimals: 2 })}
            subtitle="Unidades por ticket"
            iconName="bar-chart-2"
          />
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="absolute bottom-3 right-3 cursor-default text-amber-500">
                  <AlertTriangle className="h-3.5 w-3.5" />
                </span>
              </TooltipTrigger>
              <TooltipContent side="top" className="text-xs">
                Pendiente de validación contra Gesvision
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
      </div>

      {/* ── Fila 2: Tabla Detalle (izq) | Dispersión (der) ────────────────────── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<TableSkeleton title="Detalle Operativo de cobertura de inventario" rows={8} />}>
          <DetalleTableWrapper
            startDate={startDate}
            endDate={endDate}
            sucursales={sucursales}
            marcaFilter={marcaFilter}
            grupoFilter={grupoFilter}
          />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Eficiencia de Inventario: Ventas vs. Stock" height="h-[500px]" />}>
          <DispersionChartWrapper
            startDate={startDate}
            endDate={endDate}
            sucursales={sucursales}
            marcaFilter={marcaFilter}
            grupoFilter={grupoFilter}
          />
        </Suspense>
      </div>

      {/* ── Fila 3: Ranking Marcas (izq) | Mix Grupos (der) ───────────────────── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<ChartSkeleton title="Ranking de Ventas por Marca" height="h-[500px]" />}>
          <RankingMarcasChartWrapper
            startDate={startDate}
            endDate={endDate}
            sucursales={sucursales}
            marcaFilter={marcaFilter}
            grupoFilter={grupoFilter}
          />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Mix de Venta por Grupo Comercial" height="h-[500px]" />}>
          <TreemapChartWrapper
            startDate={startDate}
            endDate={endDate}
            sucursales={sucursales}
            marcaFilter={marcaFilter}
            grupoFilter={grupoFilter}
          />
        </Suspense>
      </div>
    </div>
  );
}
