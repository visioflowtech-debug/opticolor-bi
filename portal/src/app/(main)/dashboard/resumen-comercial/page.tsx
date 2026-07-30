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
  ventaNetaYTDUsd: 0,
  ventaNetaYTDSinIvaUsd: 0,
  ventaNetaUsd: 0,
  ventaNetaSinIvaUsd: 0,
  proyeccionUsd: 0,
  totalCobradoUsd: 0,
  ticketPromedioUsd: 0,
  cantidadPedidos: 0,
  cantidadFacturas: 0,
  clientesNuevos: 0,
};

export default async function ResumenComercialPage({
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

  const result = await getResumenKPIs({ startDate, endDate, sucursales });
  const kpis = result.data ?? EMPTY_KPIS;

  // proyeccionPct: compara venta real del período filtrado vs su proyección al cierre
  // Usa la Venta Neta con IVA (ventaNetaUsd) — mismo concepto que ya usaba este
  // cálculo antes de la migración.
  const proyeccionPct =
    kpis.proyeccionUsd > 0 ? Math.round((kpis.ventaNetaUsd / kpis.proyeccionUsd) * 100) : 0;

  const pendienteCobro = kpis.ventaNetaUsd - kpis.totalCobradoUsd;

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
          title="Venta Neta USD"
          value={formatCompactCurrency(kpis.ventaNetaUsd, { currency: "USD" })}
          fullValue={formatCurrency(kpis.ventaNetaUsd, { currency: "USD" })}
          iconName="dollar-sign"
          highlight
        />
        <KpiCard
          title="Venta Neta Sin Impuesto USD"
          value={formatCompactCurrency(kpis.ventaNetaSinIvaUsd, { currency: "USD" })}
          fullValue={formatCurrency(kpis.ventaNetaSinIvaUsd, { currency: "USD" })}
          iconName="wallet"
        />
        <KpiCard
          title="Proyección Venta Neta USD"
          value={formatCompactCurrency(kpis.proyeccionUsd, { currency: "USD" })}
          fullValue={formatCurrency(kpis.proyeccionUsd, { currency: "USD" })}
          subtitle={`${proyeccionPct}% del objetivo alcanzado`}
          iconName="trending-up"
        />
        <KpiCard
          title="Total Cobrado USD"
          value={formatCompactCurrency(kpis.totalCobradoUsd, { currency: "USD" })}
          fullValue={formatCurrency(kpis.totalCobradoUsd, { currency: "USD" })}
          subtitle={
            pendienteCobro > 0
              ? `${formatCompactCurrency(pendienteCobro, { currency: "USD" })} pendiente de cobro`
              : "Sin pendientes"
          }
          iconName="credit-card"
        />
        <KpiCard
          title="Ticket Promedio USD"
          value={formatCompactCurrency(kpis.ticketPromedioUsd, { currency: "USD" })}
          fullValue={formatCurrency(kpis.ticketPromedioUsd, { currency: "USD" })}
          iconName="bar-chart-3"
        />
        <KpiCard
          title="Venta Neta YTD USD"
          value={formatCompactCurrency(kpis.ventaNetaYTDUsd, { currency: "USD" })}
          fullValue={formatCurrency(kpis.ventaNetaYTDUsd, { currency: "USD" })}
          iconName="dollar-sign"
        />
        <KpiCard
          title="Ordenes Facturadas"
          value={formatCompactNumber(kpis.cantidadFacturas)}
          fullValue={kpis.cantidadFacturas.toLocaleString("en-US")}
          iconName="shopping-cart"
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
        <Suspense fallback={<ChartSkeleton title="Top  Sucursales: Venta Real vs. Estimados Cierre" height="h-64" />}>
          <SucursalesChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>

        <Suspense fallback={<ChartSkeleton title="Distribución por Medios de Pago" height="h-52" />}>
          <MediosPagoChartWrapper startDate={startDate} endDate={endDate} sucursales={sucursales} />
        </Suspense>
      </div>

      {/* ── Fila 4: Tendencia anual YTD — ancho completo ────────────────────── */}
      <Suspense fallback={<ChartSkeleton title="Relaciòn de Ventas Neta y Tràfico de Ventas" height="h-[350px]" />}>
        <VentasChartWrapper sucursales={sucursales} />
      </Suspense>
    </div>
  );
}
