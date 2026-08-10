"use client";

import { useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import type { RotacionSucursal } from "../_actions/get-inventario-data";
import { formatNumber, truncateText } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";
import { Button } from "@/components/ui/button";

interface Props {
  data: RotacionSucursal[];
}

interface RotacionTooltipProps {
  active?: boolean;
  payload?: Array<{ payload: RotacionSucursal }>;
}

// Tooltip a medida — no usa ChartTooltipContainer porque su rama sin moneda
// formatea con `.toLocaleString("en-US")`, no con `formatNumber` (convención
// venezolana) como pide explícitamente este gráfico. Mismo criterio ya usado
// en RankingMarcasChart (mismo módulo) para un caso similar.
function RotacionTooltip({ active, payload }: RotacionTooltipProps) {
  if (!active || !payload?.length) return null;
  const d = payload[0]?.payload;
  if (!d) return null;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm min-w-[180px]">
      <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wide text-foreground">
        {d.nombreSucursal}
      </p>
      <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
        <span className="text-muted-foreground">Unidades Vendidas:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {formatNumber(d.unidadesVendidas)}
        </span>
        <span className="text-muted-foreground">Stock Físico (Existencia):</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {formatNumber(d.stockFisico)}
        </span>
        <span className="text-muted-foreground">% Rotación:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {formatNumber(d.pctRotacion, { decimals: 1 })}%
        </span>
      </div>
    </div>
  );
}

export function RotacionSucursalChart({ data }: Props) {
  const isMobile = useIsMobile();
  const [expanded, setExpanded] = useState(false);

  if (!data.length) {
    return (
      <SafeChartContainer height="h-[650px]">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  // data ya viene ordenada desc por pctRotacion y limitada a Top 20 desde la
  // Server Action (fetchRotacionSucursal) — acá solo se decide cuánto de ese
  // arreglo ya cargado se revela, sin fetch adicional.
  const chartData = expanded ? data : data.slice(0, 10);
  const maxRotacion = Math.max(...data.map((d) => d.pctRotacion), 1);
  const showToggle = data.length > 10;

  return (
    <div className="flex flex-col h-full w-full justify-between min-h-0">
      <div className="flex-grow min-h-0 relative">
        <SafeChartContainer height={expanded ? "h-[650px]" : "h-[340px]"}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={chartData}
              layout="vertical"
              margin={{ top: 4, right: 40, left: 0, bottom: 4 }}
            >
              <CartesianGrid
                horizontal={false}
                strokeDasharray="3 3"
                stroke="var(--border)"
                strokeOpacity={0.6}
              />

              <YAxis
                type="category"
                dataKey="nombreSucursal"
                tickFormatter={(v) => truncateText(v, isMobile ? 10 : 15)}
                tick={{ fontSize: 11, fill: "var(--muted-foreground)", textAnchor: "end", style: { whiteSpace: "nowrap" } }}
                tickLine={false}
                axisLine={false}
                width={120}
                interval={0}
              />

              <XAxis
                type="number"
                domain={[0, Math.ceil(maxRotacion * 1.15)]}
                tickFormatter={(v) => `${formatNumber(v)}%`}
                tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                tickLine={false}
                axisLine={false}
              />

              <Tooltip
                content={<RotacionTooltip />}
                cursor={{ fill: "var(--muted)", opacity: 0.3 }}
              />

              <Bar
                dataKey="pctRotacion"
                fill="var(--chart-1)"
                radius={[0, 4, 4, 0]}
                maxBarSize={18}
              >
                <LabelList
                  dataKey="pctRotacion"
                  position="right"
                  formatter={(v: unknown) =>
                    `${formatNumber(Number(v), { decimals: Number(v) < 10 ? 1 : 0 })}%`
                  }
                  style={{ fontSize: 11, fill: "var(--foreground)" }}
                />
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </SafeChartContainer>
      </div>

      {showToggle && (
        <div className="w-full py-2.5 flex justify-center mt-auto border-t bg-muted/30 hover:bg-muted/50 transition-colors">
          <Button
            variant="ghost"
            className="text-xs font-semibold text-primary hover:text-primary/80 w-full h-full py-1.5"
            onClick={() => setExpanded((prev) => !prev)}
          >
            {expanded ? "Ver menos (Colapsar)" : `Ver las ${data.length} sucursales (+${data.length - 10})`}
          </Button>
        </div>
      )}
    </div>
  );
}
