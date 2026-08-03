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
import type { RotacionSucursal } from "../_actions/get-inventario-data";
import { formatNumber, truncateText } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";

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

// Etiqueta de porcentaje dentro de la barra — fondo oscuro, texto blanco
// centrado, según la captura confirmada. Si la barra es demasiado angosta
// para contener la píldora, la etiqueta se mueve afuera a la derecha para
// no verse cortada ni superpuesta.
interface RotacionBarLabelProps {
  x?: unknown;
  y?: unknown;
  width?: unknown;
  height?: unknown;
  value?: unknown;
}

function RotacionBarLabel(props: RotacionBarLabelProps) {
  const x = Number(props.x ?? 0);
  const y = Number(props.y ?? 0);
  const width = Number(props.width ?? 0);
  const height = Number(props.height ?? 0);
  const value = Number(props.value ?? 0);
  const text = `${formatNumber(value, { decimals: value < 10 ? 1 : 0 })}%`;
  const pillWidth = Math.max(36, text.length * 6.5 + 14);
  const pillHeight = 16;
  const cy = y + height / 2;
  const fitsInside = width > pillWidth + 6;

  const pillX = fitsInside ? x + width - pillWidth - 3 : x + width + 4;
  const textX = pillX + pillWidth / 2;

  return (
    <g>
      <rect
        x={pillX}
        y={cy - pillHeight / 2}
        width={pillWidth}
        height={pillHeight}
        rx={8}
        fill={fitsInside ? "rgba(15, 23, 42, 0.75)" : "transparent"}
      />
      <text
        x={textX}
        y={cy}
        textAnchor="middle"
        dominantBaseline="central"
        fontSize={11}
        fontWeight={600}
        fill={fitsInside ? "#ffffff" : "var(--foreground)"}
      >
        {text}
      </text>
    </g>
  );
}

export function RotacionSucursalChart({ data }: Props) {
  const isMobile = useIsMobile();

  if (!data.length) {
    return (
      <SafeChartContainer height="h-[650px]">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  const maxRotacion = Math.max(...data.map((d) => d.pctRotacion), 1);

  return (
    <SafeChartContainer height="h-[650px]">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={data}
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
            label={(props) => <RotacionBarLabel {...props} />}
          />
        </BarChart>
      </ResponsiveContainer>
    </SafeChartContainer>
  );
}
