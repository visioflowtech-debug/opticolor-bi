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
import type { OrdenesSucursal } from "../_actions/get-eficiencia-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { ChartTooltipContainer } from "@/components/ui/chart-tooltip-container";
import { formatCompactNumber, truncateText } from "@/lib/utils";
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
  data: OrdenesSucursal[];
  error?: string | null;
}

export function OrdenesSucursalChart({ data, error }: Props) {
  const isMobile = useIsMobile();
  const [visibleCount, setVisibleCount] = useState(10);
  const [modalCount, setModalCount] = useState(10);

  if (!data.length) {
    return (
      <Card className="overflow-hidden rounded-2xl shadow-md h-full">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Órdenes Ejecutadas por Sucursal
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
  const totalVolumen = data.reduce((acc, curr) => acc + curr.volumen_ordenes, 0);
  const promedio = data.length > 0 ? totalVolumen / data.length : 0;

  const maxVolumen = Math.max(...data.map((item) => item.volumen_ordenes), 1);

  if (isMobile) {
    const displayData = data.slice(0, visibleCount);

    return (
      <Card className="overflow-hidden rounded-2xl shadow-md h-full">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Órdenes Ejecutadas por Sucursal
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
                  {item.nombre_sucursal}
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

  // Vista Escritorio/Tableta (Top 10 en gráfico y modal para "Ver todas")
  const top10Data = data.slice(0, 10);
  const showMoreButton = data.length > 10;

  return (
    <Card className="w-full h-auto md:h-[480px] flex flex-col justify-between min-w-0 overflow-hidden rounded-2xl shadow-md">
      <div className="flex-1 flex flex-col min-h-0">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            Órdenes Ejecutadas por Sucursal
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
                  data={top10Data}
                  layout="vertical"
                  margin={{ top: 25, right: 30, left: -5, bottom: 15 }}
                >
                  <CartesianGrid
                    strokeDasharray="3 3"
                    horizontal={true}
                    vertical={false}
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
                    tickFormatter={(v) => truncateText(v, isMobile ? 10 : 15)}
                    tick={{ fontSize: 11, fill: "var(--muted-foreground)", textAnchor: "end", style: { whiteSpace: "nowrap" } }}
                    tickLine={false}
                    axisLine={false}
                    width={120}
                  />
                  <Tooltip
                    cursor={{ fill: "var(--muted)", opacity: 0.2 }}
                    content={<ChartTooltipContainer />}
                  />
                  <ReferenceLine
                    x={promedio}
                    stroke="var(--destructive)"
                    strokeDasharray="3 3"
                    strokeOpacity={0.8}
                    label={{
                      value: `Promedio: ${formatCompactNumber(promedio)}`,
                      position: "top",
                      dx: 8,
                      dy: -10,
                      fill: "var(--destructive)",
                      fontSize: 10,
                      fontWeight: 600,
                    }}
                  />
                  <Bar
                    dataKey="volumen_ordenes"
                    name="Volumen Órdenes"
                    fill="var(--chart-2)"
                    radius={[0, 4, 4, 0]}
                    barSize={24}
                  />
                </BarChart>
              </ResponsiveContainer>
            </SafeChartContainer>
          </div>
        </CardContent>
      </div>

      {showMoreButton && (
        <Dialog>
          <div className="w-full py-2 flex justify-center mt-auto border-t bg-muted/5">
            <DialogTrigger asChild>
              <Button
                variant="ghost"
                className="text-xs font-semibold text-primary hover:text-primary/90 hover:bg-muted/50 transition-colors w-full h-full py-2.5"
              >
                Ver todas las sucursales (+{data.length - 10})
              </Button>
            </DialogTrigger>
          </div>
          <DialogContent className="max-w-sm sm:max-w-xl md:max-w-3xl lg:max-w-4xl bg-background border border-border shadow-2xl overflow-hidden p-0 gap-0">
            <DialogHeader className="p-6 pb-4 border-b border-border/60 bg-muted/5">
              <DialogTitle className="text-base font-bold text-foreground">
                Todas las Sucursales - Volumen de Órdenes
              </DialogTitle>
            </DialogHeader>
            <div className="overflow-y-auto max-h-[80vh] p-6 pt-2 space-y-3">
              {data.slice(0, modalCount).map((sucursal, index) => (
                <div key={index} className="flex items-center justify-between w-full py-1 gap-3">
                  <div className="flex items-center font-medium text-sm w-40 shrink-0 pr-2">
                    <span className="text-muted-foreground/50 font-normal mr-3 w-6 inline-block text-left shrink-0">
                      {index + 1}
                    </span>
                    <span className="text-foreground font-normal truncate">{sucursal.nombre_sucursal}</span>
                  </div>
                  <div className="min-w-0 flex-1 h-3 bg-muted rounded-full overflow-hidden">
                    <div
                      className="h-full rounded-full transition-all bg-[var(--chart-1)]"
                      style={{ width: `${(sucursal.volumen_ordenes / maxVolumen) * 100}%` }}
                    />
                  </div>
                  <span className="w-20 shrink-0 text-right text-xs font-semibold text-foreground whitespace-nowrap">
                    {sucursal.volumen_ordenes} órds.
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
