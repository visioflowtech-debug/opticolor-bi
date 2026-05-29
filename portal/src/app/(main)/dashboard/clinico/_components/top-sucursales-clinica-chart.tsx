"use client";

import { useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  ReferenceLine,
} from "recharts";
import { TooltipProps } from "recharts";
import type { NameType, ValueType, Payload } from "recharts/types/component/DefaultTooltipContent";
import type { SucursalExamen } from "../_actions/get-clinica-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCompactNumber } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

interface Props {
  data: SucursalExamen[];
  error?: string | null;
}

const truncateLabel = (value: string) => {
  if (value.length > 15) {
    return value.substring(0, 15) + "...";
  }
  return value;
};

function ChartTooltip({
  active,
  payload,
}: TooltipProps<ValueType, NameType> & {
  payload?: Payload<ValueType, NameType>[];
}) {
  if (!active || !payload?.length) return null;

  const data = payload[0].payload as SucursalExamen;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm min-w-[200px]">
      <p className="mb-3 text-[12px] font-bold uppercase tracking-wide text-foreground border-b border-border pb-2">
        {data.nombre_sucursal}
      </p>
      <div className="flex flex-col gap-2 text-xs">
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">Exámenes</span>
          <span className="font-semibold tabular-nums text-foreground">
            {new Intl.NumberFormat("en-US").format(data.total_examenes)}
          </span>
        </div>
      </div>
    </div>
  );
}

export function TopSucursalesClinicaChart({ data, error }: Props) {
  const isMobile = useIsMobile();
  const [visibleCount, setVisibleCount] = useState(10);
  const [modalCount, setModalCount] = useState(10);

  if (!data.length) {
    return (
      <Card className="overflow-hidden rounded-2xl shadow-md h-full">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Top Sucursales por Volumen de Exámenes
          </CardTitle>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="text-sm text-destructive pb-2">{error}</div>
          )}
          <SafeChartContainer height="h-[480px]">
            <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
              Sin datos para el período seleccionado
            </div>
          </SafeChartContainer>
        </CardContent>
      </Card>
    );
  }

  // Calcular promedio dinámico
  const total = data.reduce((acc, curr) => acc + curr.total_examenes, 0);
  const promedio = data.length > 0 ? total / data.length : 0;

  const formatLabel = (value: string) => {
    const limit = isMobile ? 10 : 15;
    if (value.length > limit) {
      return value.substring(0, limit) + "...";
    }
    return value;
  };

  const maxExamenes = Math.max(...data.map((item) => item.total_examenes), 1);

  if (isMobile) {
    const displayData = data.slice(0, visibleCount);

    return (
      <Card className="overflow-hidden rounded-2xl shadow-md h-full">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Top Sucursales por Volumen de Exámenes
          </CardTitle>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="text-sm text-destructive pb-2">{error}</div>
          )}
          <div className="w-full h-auto space-y-3 p-1 overflow-visible">
            {displayData.map((item, index) => (
              <div key={index} className="flex items-center gap-3 w-full">
                <span className="w-24 shrink-0 truncate text-[11px] font-semibold text-slate-500 dark:text-slate-400">
                  {item.nombre_sucursal}
                </span>
                <div className="min-w-0 flex-1 h-3 bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-emerald-600 rounded-full transition-all duration-300"
                    style={{ width: `${(item.total_examenes / maxExamenes) * 100}%` }}
                  />
                </div>
                <span className="w-20 shrink-0 text-right text-xs font-bold text-slate-900 dark:text-slate-100 whitespace-nowrap">
                  {item.total_examenes} exáms.
                </span>
              </div>
            ))}
            {/* Botón elástico incremental de 10 en 10 */}
            {(data.length > visibleCount || visibleCount > 10) && (
              <div className="pt-2 flex justify-center gap-2">
                {data.length > visibleCount && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-xs font-semibold text-primary"
                    onClick={() => setVisibleCount((prev) => prev + 10)}
                  >
                    Ver más (+{Math.min(10, data.length - visibleCount)})
                  </Button>
                )}
                {visibleCount > 10 && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-xs font-semibold text-muted-foreground"
                    onClick={() => setVisibleCount(10)}
                  >
                    Colapsar
                  </Button>
                )}
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    );
  }

  // Vista Escritorio/Tableta (Top 10 en gráfico y modal para "Ver todas")
  const top10Data = data.slice(0, 10);
  const showMoreButton = data.length > 10;

  return (
    <Card className="w-full h-auto md:h-[480px] flex flex-col justify-between min-w-0 overflow-hidden rounded-2xl shadow-md">
      <div className="flex flex-col h-full w-full min-h-0 justify-between">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Top Sucursales por Volumen de Exámenes
          </CardTitle>
        </CardHeader>
        <CardContent className="flex-1 flex flex-col min-h-0">
          {error && (
            <div className="text-sm text-destructive pb-2">{error}</div>
          )}
          <div className="flex-1 w-full h-full min-h-0">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={top10Data}
                layout="vertical"
                margin={{ top: 15, right: 30, left: -15, bottom: 15 }}
              >
                <CartesianGrid
                  strokeDasharray="3 3"
                  horizontal={false}
                  vertical={true}
                  stroke="var(--border)"
                  strokeOpacity={0.6}
                />
                <XAxis
                  type="number"
                  tickFormatter={(value) => formatCompactNumber(value)}
                  tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                  tickLine={false}
                  axisLine={false}
                  tickMargin={10}
                />
                <YAxis
                  dataKey="nombre_sucursal"
                  type="category"
                  tickFormatter={formatLabel}
                  tick={{ fontSize: 11, fill: "var(--muted-foreground)", textAnchor: "end", style: { whiteSpace: "nowrap" } }}
                  tickLine={false}
                  axisLine={false}
                  width={120}
                />
                <Tooltip
                  cursor={{ fill: "var(--muted)", opacity: 0.2 }}
                  content={<ChartTooltip />}
                />
                <ReferenceLine
                  x={promedio}
                  stroke="var(--destructive)"
                  strokeDasharray="3 3"
                  strokeOpacity={0.8}
                  label={{
                    position: "top",
                    value: `Promedio: ${formatCompactNumber(promedio)}`,
                    fill: "var(--destructive)",
                    fontSize: 10,
                    fontWeight: 600,
                    dy: -10,
                  }}
                />
                <Bar
                  dataKey="total_examenes"
                  name="Total Exámenes"
                  fill="var(--chart-2)"
                  radius={[0, 4, 4, 0]}
                  barSize={16}
                />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </div>

      {showMoreButton && (
        <Dialog>
          <div className="w-full py-2 flex justify-center mt-auto border-t bg-muted/5">
            <DialogTrigger asChild>
              <Button
                variant="ghost"
                className="text-xs font-semibold text-blue-600 hover:text-blue-700 hover:bg-blue-50/50 transition-colors"
              >
                Ver todas las sucursales (+{data.length - 10})
              </Button>
            </DialogTrigger>
          </div>
          <DialogContent className="w-[95%] md:max-w-3xl lg:max-w-4xl rounded-2xl p-6">
            <DialogHeader>
              <DialogTitle className="text-base font-bold text-foreground">
                Todas las Sucursales - Volumen de Exámenes
              </DialogTitle>
            </DialogHeader>
            <div className="mt-4 max-h-[60vh] overflow-y-auto space-y-3 p-1">
              {data.slice(0, modalCount).map((item, index) => (
                <div key={index} className="flex items-center gap-3 w-full">
                  <span className="w-24 shrink-0 truncate text-[11px] font-semibold text-slate-500 dark:text-slate-400">
                    {item.nombre_sucursal}
                  </span>
                  <div className="min-w-0 flex-1 h-3 bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-emerald-600 rounded-full transition-all duration-300"
                      style={{ width: `${(item.total_examenes / maxExamenes) * 100}%` }}
                    />
                  </div>
                  <span className="w-20 shrink-0 text-right text-xs font-bold text-slate-900 dark:text-slate-100 whitespace-nowrap">
                    {item.total_examenes} exáms.
                  </span>
                </div>
              ))}

              {(data.length > modalCount || modalCount > 10) && (
                <div className="pt-4 flex justify-center gap-2">
                  {data.length > modalCount && (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-xs font-semibold text-primary"
                      onClick={() => setModalCount((prev) => prev + 10)}
                    >
                      Ver más (+{Math.min(10, data.length - modalCount)})
                    </Button>
                  )}
                  {modalCount > 10 && (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-xs font-semibold text-muted-foreground"
                      onClick={() => setModalCount(10)}
                    >
                      Colapsar
                    </Button>
                  )}
                </div>
              )}
            </div>
          </DialogContent>
        </Dialog>
      )}
    </Card>
  );
}
