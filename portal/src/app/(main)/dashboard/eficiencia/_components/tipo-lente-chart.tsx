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
} from "recharts";
import { TooltipProps } from "recharts";
import type { NameType, ValueType, Payload } from "recharts/types/component/DefaultTooltipContent";
import type { TipoLenteDetalle } from "../_actions/get-eficiencia-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCompactNumber, formatNumber, formatPercent, truncateText } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface Props {
  data: TipoLenteDetalle[];
  error?: string | null;
}

function ChartTooltip({
  active,
  payload,
  totalVolumen,
}: TooltipProps<ValueType, NameType> & {
  payload?: Payload<ValueType, NameType>[];
  totalVolumen: number;
}) {
  if (!active || !payload?.length) return null;

  const data = payload[0].payload as TipoLenteDetalle;
  const pct = totalVolumen > 0 ? (data.volumen_ordenes / totalVolumen) * 100 : 0;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm min-w-[200px]">
      <p className="mb-3 text-[12px] font-bold uppercase tracking-wide text-foreground border-b border-border pb-2">
        {data.tipo_lente_agrupado}
      </p>
      <div className="flex flex-col gap-2 text-xs">
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">Cantidad</span>
          <span className="font-semibold tabular-nums text-foreground">
            {formatNumber(data.volumen_ordenes)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">% Participación</span>
          <span className="font-semibold tabular-nums text-foreground">
            {formatPercent(pct)}
          </span>
        </div>
      </div>
    </div>
  );
}

export function TipoLenteChart({ data, error }: Props) {
  const isMobile = useIsMobile();
  const [visibleCount, setVisibleCount] = useState(10);

  if (!data.length) {
    return (
      <Card className="overflow-hidden rounded-2xl shadow-md h-full">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Detalle de Órdenes por Tipo
          </CardTitle>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="text-sm text-destructive pb-2">{error}</div>
          )}
          <SafeChartContainer height="h-[360px]">
            <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
              Sin datos para el período seleccionado
            </div>
          </SafeChartContainer>
        </CardContent>
      </Card>
    );
  }

  const totalVolumen = data.reduce((acc, curr) => acc + curr.volumen_ordenes, 0);

  if (isMobile) {
    const displayData = data.slice(0, visibleCount);
    const maxVolumen = Math.max(...data.map((item) => item.volumen_ordenes), 1);

    return (
      <Card className="overflow-hidden rounded-2xl shadow-md h-full">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Detalle de Órdenes por Tipo
          </CardTitle>
        </CardHeader>
        <CardContent>
          {error && (
            <div className="text-sm text-destructive pb-2">{error}</div>
          )}
          <div className="w-full h-auto space-y-3 p-1 overflow-visible">
            {displayData.map((item, index) => (
              <div key={index} className="flex items-center gap-3 w-full">
                <span className="w-24 shrink-0 truncate text-[11px] font-semibold text-muted-foreground">
                  {item.tipo_lente_agrupado}
                </span>
                <div className="min-w-0 flex-1 h-3 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full bg-[var(--chart-1)] rounded-full transition-all duration-300"
                    style={{ width: `${(item.volumen_ordenes / maxVolumen) * 100}%` }}
                  />
                </div>
                <span className="w-20 shrink-0 text-right text-xs font-bold text-foreground whitespace-nowrap">
                  {item.volumen_ordenes} órds.
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

  return (
    <Card className="w-full h-auto md:h-[480px] flex flex-col justify-between min-w-0 overflow-hidden rounded-2xl shadow-md">
      <div className="flex-1 flex flex-col min-h-0">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Detalle de Órdenes por Tipo
          </CardTitle>
        </CardHeader>
        <CardContent className="flex-1 flex flex-col min-h-0">
          {error && (
            <div className="text-sm text-destructive pb-2">{error}</div>
          )}
          <div className="flex-1 w-full h-full min-h-0">
            <SafeChartContainer height="h-full" className="h-full w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={data}
                  layout="horizontal"
                  margin={{ top: 20, right: 10, left: -10, bottom: 10 }}
                >
                  <CartesianGrid
                    strokeDasharray="3 3"
                    horizontal={true}
                    vertical={false}
                    stroke="var(--border)"
                    strokeOpacity={0.6}
                  />
                  <XAxis
                    dataKey="tipo_lente_agrupado"
                    type="category"
                    //tickFormatter={truncateText}
                    tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                    angle={-45}
                    textAnchor="end"
                    height={70}
                    interval={0}
                    tickLine={false}
                    axisLine={false}
                  />
                  <YAxis
                    type="number"
                    tickFormatter={(value) => formatCompactNumber(value)}
                    tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                    tickLine={false}
                    axisLine={false}
                    tickMargin={10}
                  />
                  <Tooltip
                    cursor={{ fill: "var(--muted)", opacity: 0.2 }}
                    content={<ChartTooltip totalVolumen={totalVolumen} />}
                  />
                  <Bar
                    dataKey="volumen_ordenes"
                    name="Volumen Órdenes"
                    fill="var(--chart-1)"
                    radius={[4, 4, 0, 0]}
                    barSize={40}
                  />
                </BarChart>
              </ResponsiveContainer>
            </SafeChartContainer>
          </div>
        </CardContent>
      </div>
    </Card>
  );
}
