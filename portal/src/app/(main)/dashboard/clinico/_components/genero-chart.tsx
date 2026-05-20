"use client";

import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Tooltip,
} from "recharts";
import type { GeneroExamen } from "../_actions/get-clinica-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";

interface Props {
  data: GeneroExamen[];
}

const COLORS = [
  "var(--chart-1)",
  "var(--chart-2)",
  "hsl(var(--muted-foreground)/0.4)",
  "hsl(var(--muted-foreground)/0.8)",
];

function ChartTooltip({
  active,
  payload,
  total,
}: {
  active?: boolean;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  payload?: any[];
  total: number;
}) {
  if (!active || !payload?.length) return null;

  const item = payload[0].payload;
  const pct = total > 0 ? (item.total_examenes / total) * 100 : 0;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm min-w-[180px]">
      <p className="mb-3 text-[12px] font-bold uppercase tracking-wide text-foreground border-b border-border pb-2">
        {item.genero_label}
      </p>
      <div className="flex flex-col gap-2 text-xs">
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">Cantidad</span>
          <span className="font-semibold tabular-nums text-foreground">
            {new Intl.NumberFormat("en-US").format(item.total_examenes)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">% del Total</span>
          <span className="font-semibold tabular-nums text-foreground">
            {pct.toFixed(1)}%
          </span>
        </div>
      </div>
    </div>
  );
}

function GeneroLegend({ data }: { data: GeneroExamen[] }) {
  const total = data.reduce((acc, curr) => acc + curr.total_examenes, 0);
  return (
    <ul className="flex w-full flex-col gap-2">
      {data.map((item, i) => {
        const pct = total > 0 ? (item.total_examenes / total) * 100 : 0;
        return (
          <li key={i} className="flex min-w-0 items-center gap-2 text-xs">
            <span
              className="h-2.5 w-2.5 shrink-0 rounded-full"
              style={{ backgroundColor: COLORS[i % COLORS.length] }}
            />
            <span
              className="min-w-0 flex-1 truncate text-muted-foreground"
              title={item.genero_label}
            >
              {item.genero_label}
            </span>
            <span className="shrink-0 font-semibold tabular-nums">
              {pct.toFixed(1)}%
            </span>
          </li>
        );
      })}
    </ul>
  );
}

export function GeneroChart({ data }: Props) {
  if (!data.length) {
    return (
      <div className="flex h-52 items-center justify-center text-sm text-muted-foreground">
        Sin datos para el período seleccionado
      </div>
    );
  }

  const total = data.reduce((acc, curr) => acc + curr.total_examenes, 0);

  return (
    <div className="flex flex-col items-center gap-5 sm:flex-row sm:items-center">
      <SafeChartContainer height="h-52" className="w-52 shrink-0">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              innerRadius="32%"
              outerRadius="82%"
              paddingAngle={2}
              dataKey="total_examenes"
              nameKey="genero_label"
              strokeWidth={0}
            >
              {data.map((_entry, index) => (
                <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip content={<ChartTooltip total={total} />} cursor={false} />
          </PieChart>
        </ResponsiveContainer>
      </SafeChartContainer>

      <div className="min-w-0 flex-1">
        <GeneroLegend data={data} />
      </div>
    </div>
  );
}
