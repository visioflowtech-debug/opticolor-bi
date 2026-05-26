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
import { formatBsCurrency } from "@/lib/utils";

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
  if (!data.length) {
    return (
      <SafeChartContainer height="h-[500px]">
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
    <SafeChartContainer height="h-[500px]">
      <ResponsiveContainer width="100%" height="100%">
        <ScatterChart margin={{ top: 12, right: 20, left: 8, bottom: 32 }}>
          <CartesianGrid
            strokeDasharray="3 3"
            stroke="var(--border)"
            strokeOpacity={0.6}
          />

          <XAxis
            type="number"
            dataKey="unidadesVendidas"
            name="Unidades Vendidas"
            tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
            tickLine={false}
            axisLine={false}
            tickFormatter={(v: number) =>
              v.toLocaleString("en-US", { notation: "compact" })
            }
            label={{
              value: "Unidades Vendidas",
              position: "insideBottom",
              offset: -16,
              fontSize: 11,
              fill: "var(--muted-foreground)",
            }}
          />

          <YAxis
            type="number"
            dataKey="stockFisico"
            name="Stock Físico"
            tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
            tickLine={false}
            axisLine={false}
            width={52}
            tickFormatter={(v: number) =>
              v.toLocaleString("en-US", { notation: "compact" })
            }
            label={{
              value: "Stock Físico (unidades)",
              angle: -90,
              position: "insideLeft",
              offset: 12,
              fontSize: 11,
              fill: "var(--muted-foreground)",
            }}
          />

          <ZAxis range={[72, 72]} />

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
              return (
                <circle
                  cx={cx}
                  cy={cy}
                  r={9}
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
    </SafeChartContainer>
  );
}
