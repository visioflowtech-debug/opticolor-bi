"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import type { MarcaItem } from "../_actions/get-inventario-data";
import { formatBsCurrency, formatCompactNumber } from "@/lib/utils";

interface Props {
  data: MarcaItem[];
}

const MAX_LABEL_LEN = 18;

function truncate(s: string) {
  return s.length > MAX_LABEL_LEN ? `${s.slice(0, MAX_LABEL_LEN - 1)}…` : s;
}

interface RankingTooltipProps {
  active?: boolean;
  payload?: Array<{
    payload: {
      marca?: string;
      ventaNeta?: number;
      unidadesVendidas?: number;
      stockFisico?: number;
    };
  }>;
}

function RankingTooltip({ active, payload }: RankingTooltipProps) {
  if (!active || !payload?.length) return null;
  const d = payload[0]?.payload;
  if (!d) return null;

  const asp = d.unidadesVendidas && d.unidadesVendidas > 0 
    ? (d.ventaNeta ?? 0) / d.unidadesVendidas 
    : 0;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm">
      <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wide text-foreground">
        {d.marca ?? "SIN MARCA"}
      </p>
      <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
        <span className="text-muted-foreground">Venta Neta Producto:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {formatBsCurrency(d.ventaNeta ?? 0)}
        </span>
        <span className="text-muted-foreground">Unidades Vendidas:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {d.unidadesVendidas?.toLocaleString("en-US") ?? "0"}
        </span>
        <span className="text-muted-foreground">Stock Físico Unidades:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {d.stockFisico?.toLocaleString("en-US") ?? "0"}
        </span>
        <span className="text-muted-foreground">ASP Precio Promedio:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {formatBsCurrency(asp)}
        </span>
      </div>
    </div>
  );
}


export function RankingMarcasChart({ data }: Props) {
  if (!data.length) {
    return (
      <SafeChartContainer height="h-[500px]">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  // Tomar top 20 ordenados por ventaNeta desc para no colapsar el eje Y con demasiadas marcas
  const chartData = [...data]
    .sort((a, b) => b.ventaNeta - a.ventaNeta)
    .slice(0, 20)
    .map((m) => ({
      ...m,
      labelTrunc: truncate(m.marca),
    }));

  return (
    <SafeChartContainer height="h-[500px]">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={chartData}
          layout="vertical"
          margin={{ top: 4, right: 24, left: 0, bottom: 4 }}
        >
          <CartesianGrid
            horizontal={false}
            strokeDasharray="3 3"
            stroke="var(--border)"
            strokeOpacity={0.6}
          />

          {/* Eje Y: nombres de marca (truncados) con 120 px de ancho reservado */}
          <YAxis
            type="category"
            dataKey="labelTrunc"
            width={120}
            tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
            tickLine={false}
            axisLine={false}
          />

          <XAxis
            type="number"
            dataKey="ventaNeta"
            tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
            tickLine={false}
            axisLine={false}
            tickFormatter={(v) => formatCompactNumber(v)}
          />

          {/* Tooltip muestra el nombre completo (desde el campo marca) */}
          <Tooltip
            content={<RankingTooltip />}
            cursor={{ fill: "var(--muted)", opacity: 0.4 }}
          />

          <Bar
            dataKey="ventaNeta"
            fill="var(--chart-1)"
            radius={[0, 4, 4, 0]}
            maxBarSize={22}
            opacity={0.9}
          />
        </BarChart>
      </ResponsiveContainer>
    </SafeChartContainer>
  );
}
