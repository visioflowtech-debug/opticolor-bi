import { format, startOfMonth } from "date-fns";
import { Suspense } from "react";

import {
  formatCompactCurrency,
  formatCompactNumber,
  formatCurrency,
} from "@/lib/utils";

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
  capitalInvertido: 0,
  unidadesVendidas: 0,
  ventaNetaProducto: 0,
  upt: 0,
  asp: 0,
  volumenUnidades: 0,
};

export default async function InventarioPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { from, to, sucursal, marca, grupo } = await searchParams;

  const startDate = from
    ? format(new Date(from), "yyyy-MM-dd")
    : format(startOfMonth(new Date()), "yyyy-MM-dd");
  const endDate = to
    ? format(new Date(to), "yyyy-MM-dd")
    : format(new Date(), "yyyy-MM-dd");
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

      {/* ── Fila 1: 6 KPI Cards ──────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <KpiCard
          title="Stock Físico"
          value={formatCompactNumber(kpis.stockFisico)}
          fullValue={kpis.stockFisico.toLocaleString("en-US")}
          subtitle="Snapshot · hasta hoy"
          iconName="archive"
          highlight
        />
        <KpiCard
          title="Capital Invertido"
          value={formatCompactCurrency(kpis.capitalInvertido)}
          fullValue={formatCurrency(kpis.capitalInvertido)}
          subtitle="Snapshot · hasta hoy"
          iconName="dollar-sign"
        />
        <KpiCard
          title="Unidades Vendidas"
          value={formatCompactNumber(kpis.unidadesVendidas)}
          fullValue={kpis.unidadesVendidas.toLocaleString("en-US")}
          iconName="trending-up"
        />
        <KpiCard
          title="UPT"
          value={kpis.upt.toFixed(2)}
          subtitle="Unidades por ticket"
          iconName="bar-chart-2"
        />
        <KpiCard
          title="ASP"
          value={formatCompactCurrency(kpis.asp)}
          fullValue={formatCurrency(kpis.asp)}
          subtitle="Precio promedio de venta"
          iconName="tag"
        />
        <KpiCard
          title="Volumen Total"
          value={formatCompactNumber(kpis.volumenUnidades)}
          fullValue={kpis.volumenUnidades.toLocaleString("en-US")}
          subtitle="Control analítico · sin exclusiones"
          iconName="layers"
        />
      </div>

      {/* ── Fila 2: Tabla Detalle (izq) | Dispersión (der) ────────────────────── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<TableSkeleton title="Detalle por Marca" rows={8} />}>
          <DetalleTableWrapper
            startDate={startDate}
            endDate={endDate}
            sucursales={sucursales}
            marcaFilter={marcaFilter}
            grupoFilter={grupoFilter}
          />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Eficiencia de Inventario · Stock vs Ventas" height="h-[500px]" />}>
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
        <Suspense fallback={<ChartSkeleton title="Ranking de Marcas · Unidades Vendidas" height="h-[500px]" />}>
          <RankingMarcasChartWrapper
            startDate={startDate}
            endDate={endDate}
            sucursales={sucursales}
            marcaFilter={marcaFilter}
            grupoFilter={grupoFilter}
          />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Mix de Venta · Por Grupo Comercial" height="h-[500px]" />}>
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
