"use client";

import { ResponsiveContainer, Tooltip, Treemap } from "recharts";

import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCurrency } from "@/lib/utils";
import type { GrupoMix } from "../_actions/get-inventario-data";

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
          <span className="font-medium tabular-nums">{formatCurrency(d.size, { currency: "USD" })}</span>
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
  const isMobile = useIsMobile();

  if (!data.length) {
    return (
      <SafeChartContainer height="h-[380px]">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  // Si isMobile es verdadero, agrupamos a partir del Top 6 en "OTROS"
  let processedData = data;
  if (isMobile && data.length > 6) {
    const top6 = data.slice(0, 6);
    const residuo = data.slice(6);
    const sumaDelResiduo = residuo.reduce((sum, item) => sum + item.size, 0);
    const sumaPorcentaje = residuo.reduce((sum, item) => sum + item.porcentaje, 0);

    const otrosGrupo: GrupoMix & { grupo: string; ventaNeta: number } = {
      name: "OTROS",
      grupo: "OTROS",
      size: sumaDelResiduo,
      ventaNeta: sumaDelResiduo,
      porcentaje: Number(sumaPorcentaje.toFixed(1)),
    };
    processedData = [...top6, otrosGrupo];
  }

  return (
    <div className="flex flex-col w-full h-full min-h-0 justify-between">
      <div className="flex-grow min-h-0 relative">
        <SafeChartContainer height={isMobile ? "h-[260px]" : "h-[380px]"}>
          <ResponsiveContainer width="100%" height="100%">
            <Treemap
              data={processedData}
              dataKey="size"
              aspectRatio={4 / 3}
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              content={<TreemapCell />}
            >
              <Tooltip content={<TreemapTooltip />} />
            </Treemap>
          </ResponsiveContainer>
        </SafeChartContainer>
      </div>

      {isMobile && (
        <div className="w-full mt-4 border-t pt-3 grid grid-cols-2 gap-x-4 gap-y-2 px-2 text-xs font-medium">
          {processedData.map((item, index) => {
            const color = CHART_TOKENS[index % CHART_TOKENS.length]; 
            return (
              <div key={item.name} className="flex items-center justify-between w-full">
                <div className="flex items-center min-w-0">
                  <span 
                    className="w-3 h-3 rounded-sm mr-2 flex-shrink-0" 
                    style={{ backgroundColor: color }} 
                  />
                  <span className="truncate text-foreground uppercase font-semibold text-[10px]">{item.name}</span>
                </div>
                <span className="text-muted-foreground ml-1 font-bold">{item.porcentaje}%</span>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
