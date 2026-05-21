import { format, startOfMonth } from "date-fns";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  formatCompactCurrency,
  formatCompactNumber,
  formatCurrency,
} from "@/lib/utils";

import { getResumenData } from "./_actions/get-resumen-data";
import { KpiCard } from "./_components/kpi-card";
import { MediosPagoChart } from "./_components/medios-pago-chart";
import { SucursalesChart } from "./_components/sucursales-chart";
import { VentasChart } from "./_components/ventas-chart";

type SearchParams = Promise<{ from?: string; to?: string; sucursal?: string }>;

const EMPTY_DATA = {
  kpis: {
    ventaNetaYTD: 0,
    ventaNeta: 0,
    proyeccion: 0,
    totalCobrado: 0,
    ticketPromedio: 0,
    cantidadPedidos: 0,
    totalExamenes: 0,
    clientesNuevos: 0,
  },
  ventasDiarias: [],
  topSucursales: [],
  mediosPago: [],
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

  const result = await getResumenData({ startDate, endDate, sucursales });
  const data = result.data ?? EMPTY_DATA;
  const { kpis } = data;

  // proyeccionPct: compara venta real del período filtrado vs su proyección al cierre
  const proyeccionPct =
    kpis.proyeccion > 0 ? Math.round((kpis.ventaNeta / kpis.proyeccion) * 100) : 0;

  const pendienteCobro = kpis.ventaNeta - kpis.totalCobrado;

  return (
    <div className="w-full max-w-full px-4 pb-6 md:px-6 space-y-6 overflow-hidden">
      {/* Banner de error no crítico */}
      {!result.success && (
        <div className="rounded-xl border border-destructive/30 bg-destructive/10 px-4 py-2.5 text-sm text-destructive">
          {result.error ?? "No se pudieron cargar los datos. Intenta de nuevo."}
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
        <Card className="overflow-hidden rounded-2xl shadow-md">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-semibold text-muted-foreground">
              Top 10 Sucursales · Venta Neta
            </CardTitle>
          </CardHeader>
          <CardContent>
            <SucursalesChart data={data.topSucursales} />
          </CardContent>
        </Card>

        <Card className="overflow-hidden rounded-2xl shadow-md">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-semibold text-muted-foreground">
              Distribución · Medios de Pago
            </CardTitle>
          </CardHeader>
          <CardContent>
            <MediosPagoChart data={data.mediosPago} />
          </CardContent>
        </Card>
      </div>

      {/* ── Fila 4: Tendencia anual YTD — ancho completo ────────────────────── */}
      <Card className="overflow-hidden rounded-2xl shadow-md">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Tendencia Anual · Ventas y Tráfico
          </CardTitle>
        </CardHeader>
        <CardContent>
          <VentasChart data={data.ventasDiarias} />
        </CardContent>
      </Card>
    </div>
  );
}
