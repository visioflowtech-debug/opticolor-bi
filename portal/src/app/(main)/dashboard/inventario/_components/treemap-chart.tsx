"use client";

import { ResponsiveContainer, Tooltip, Treemap } from "recharts";

import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCurrency } from "@/lib/utils";
import type { GrupoMix } from "../_actions/get-inventario-data";

// Tokens semánticos del Design System — var() resuelve el valor OKLCH nativo (Tailwind v4)
const CHART_TOKENS = [
  "var(--chart-1)",
  "var(--chart-2)",
  "var(--chart-3)",
  "var(--chart-4)",
  "var(--chart-5)",
] as const;

interface Props {
  data: GrupoMix[];
}

// Tooltip personalizado para el Treemap
function TreemapTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: Array<{ name: string; value: number; payload: GrupoMix }>;
}) {
  if (!active || !payload?.length) return null;
  const item = payload[0];
  const d = item.payload;
  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm">
      <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wide">
        {item.name ?? d.name}
      </p>
      <div className="space-y-0.5 text-xs">
        <div className="flex items-center justify-between gap-5">
          <span className="text-muted-foreground">Venta Neta</span>
          <span className="font-medium tabular-nums">{formatCurrency(d.size)}</span>
        </div>
        <div className="flex items-center justify-between gap-5">
          <span className="text-muted-foreground">Participación</span>
          <span className="font-medium tabular-nums">{d.porcentaje.toFixed(1)}%</span>
        </div>
      </div>
    </div>
  );
}

// Contenido personalizado para cada celda del Treemap
function TreemapCell(props: {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
  depth?: number;
  name?: string;
  size?: number;
  porcentaje?: number;
  index?: number;
}) {
  const { x = 0, y = 0, width = 0, height = 0, depth = 0, name = "", porcentaje = 0, index = 0 } = props;

  // El nodo raíz (depth=0) no se renderiza
  if (depth === 0) return <g />;

  const color = CHART_TOKENS[index % CHART_TOKENS.length];
  const showLabel = width > 80 && height > 48;
  const showPct   = width > 80 && height > 72;

  return (
    <g>
      <clipPath id={`tc-${index}`}>
        <rect x={x + 4} y={y + 4} width={width - 8} height={height - 8} />
      </clipPath>
      <rect
        x={x + 2}
        y={y + 2}
        width={width - 4}
        height={height - 4}
        rx={6}
        fill={color}
        stroke="var(--background)"
        strokeWidth={2}
      />
      {showLabel && (
        <text
          clipPath={`url(#tc-${index})`}
          x={x + width / 2}
          y={y + height / 2 + (showPct ? -8 : 5)}
          textAnchor="middle"
          fill="var(--primary-foreground)"
          fontSize={10}
          fontWeight={600}
          className="select-none"
        >
          {name.length > 14 ? `${name.slice(0, 13)}…` : name}
        </text>
      )}
      {showPct && (
        <text
          clipPath={`url(#tc-${index})`}
          x={x + width / 2}
          y={y + height / 2 + 10}
          textAnchor="middle"
          fill="var(--primary-foreground)"
          fillOpacity={0.75}
          fontSize={10}
          className="select-none"
        >
          {porcentaje.toFixed(1)}%
        </text>
      )}
    </g>
  );
}

export function TreemapChart({ data }: Props) {
  if (!data.length) {
    return (
      <SafeChartContainer height="h-[500px]">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  return (
    <SafeChartContainer height="h-[500px]">
      <ResponsiveContainer width="100%" height="100%">
        <Treemap
          data={data}
          dataKey="size"
          aspectRatio={4 / 3}
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          content={<TreemapCell />}
        >
          <Tooltip content={<TreemapTooltip />} />
        </Treemap>
      </ResponsiveContainer>
    </SafeChartContainer>
  );
}
