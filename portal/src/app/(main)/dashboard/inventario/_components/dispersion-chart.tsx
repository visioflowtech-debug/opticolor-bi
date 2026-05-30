"use client";

import {
  CartesianGrid,
  ResponsiveContainer,
  Scatter,
  ScatterChart,
  Tooltip,
  XAxis,
  YAxis,
  ZAxis,
} from "recharts";

import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import type { DispersionItem } from "../_actions/get-inventario-data";
import { formatBsCurrency, formatCompactNumber } from "@/lib/utils";

import { useIsMobile } from "@/hooks/use-mobile";

// Tokens semánticos del Design System — var() resuelve el valor OKLCH nativo (Tailwind v4)
const CHART_TOKENS = [
  "var(--chart-1)",
  "var(--chart-2)",
  "var(--chart-3)",
  "var(--chart-4)",
  "var(--chart-5)",
] as const;

interface Props {
  data: DispersionItem[];
}

interface CustomTooltipProps {
  active?: boolean;
  payload?: Array<{
    payload: {
      grupo?: string;
      unidadesVendidas?: number;
      stockFisico?: number;
      ventaNeta?: number;
    };
  }>;
}

function CustomTooltip({ active, payload }: CustomTooltipProps) {
  if (!active || !payload?.length) return null;
  const d = payload[0]?.payload;
  if (!d) return null;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm">
      <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wide text-foreground">
        {d.grupo ?? "SIN GRUPO"}
      </p>
      <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
        <span className="text-muted-foreground">Unidades Vendidas:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {d.unidadesVendidas?.toLocaleString("en-US") ?? "0"}
        </span>
        <span className="text-muted-foreground">Stock Físico Unidades:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {d.stockFisico?.toLocaleString("en-US") ?? "0"}
        </span>
        <span className="text-muted-foreground">Venta Neta Producto:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {formatBsCurrency(d.ventaNeta ?? 0)}
        </span>
      </div>
    </div>
  );
}

export function DispersionChart({ data }: Props) {
  const isMobile = useIsMobile();

  if (!data.length) {
    return (
      <SafeChartContainer height={isMobile ? "h-[300px]" : "h-full"} className="w-full flex-grow min-h-0 flex flex-col">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  const scatterData = data.map((m, idx) => ({
    grupo: m.grupo,
    unidadesVendidas: m.unidadesVendidas,
    stockFisico: m.stockFisico,
    ventaNeta: m.ventaNeta,
    idx,
  }));

  return (
    <SafeChartContainer height={isMobile ? "h-[300px]" : "h-full"} className="w-full flex-grow min-h-0 flex flex-col">
      <div className="flex-1 w-full h-full min-h-0">
        <ResponsiveContainer width="100%" height={isMobile ? 300 : "100%"}>
          <ScatterChart
            margin={
              isMobile
                ? { top: 15, right: 15, left: -10, bottom: 15 }
                : { top: 25, right: 25, left: 15, bottom: 20 }
            }
          >
            <CartesianGrid
              strokeDasharray="3 3"
              stroke="var(--border)"
              strokeOpacity={0.6}
            />

            <XAxis
              type="number"
              dataKey="unidadesVendidas"
              name="Unidades Vendidas"
              tick={{ fontSize: isMobile ? 9 : 11, fill: "var(--muted-foreground)" }}
              tickLine={false}
              axisLine={false}
              tickFormatter={(v) => formatCompactNumber(v)}
              label={
                isMobile
                  ? undefined
                  : {
                      value: "Unidades Vendidas",
                      position: "insideBottom",
                      offset: -16,
                      fontSize: 11,
                      fill: "var(--muted-foreground)",
                    }
              }
            />

            <YAxis
              type="number"
              dataKey="stockFisico"
              name="Stock Físico"
              tick={{ fontSize: 10, fill: "var(--muted-foreground)" }}
              tickLine={false}
              axisLine={false}
              width={isMobile ? 45 : 70}
              tickFormatter={(v) => formatCompactNumber(v)}
              label={
                !isMobile
                  ? {
                      value: "Stock Físico (unidades)",
                      angle: -90,
                      position: "insideLeft",
                      offset: -2,
                      style: { textAnchor: "middle", fill: "var(--muted-foreground)", fontSize: 11, fontWeight: 500 }
                    }
                  : undefined
              }
            />

            <ZAxis range={isMobile ? [16, 16] : [72, 72]} />

            <Tooltip
              content={<CustomTooltip />}
              cursor={{ strokeDasharray: "4 4", stroke: "var(--border)" }}
            />

            <Scatter
              data={scatterData}
              shape={(props: {
                cx?: number;
                cy?: number;
                payload?: { idx: number };
              }) => {
                const { cx = 0, cy = 0, payload } = props;
                const color = CHART_TOKENS[(payload?.idx ?? 0) % CHART_TOKENS.length];
                const radius = isMobile ? 4 : 9; // fixed radio ~4px on mobile, 9 on desktop
                return (
                  <circle
                    cx={cx}
                    cy={cy}
                    r={radius}
                    fill={color}
                    fillOpacity={0.85}
                    stroke={color}
                    strokeWidth={0}
                  />
                );
              }}
            />
          </ScatterChart>
        </ResponsiveContainer>
      </div>
    </SafeChartContainer>
  );
}
