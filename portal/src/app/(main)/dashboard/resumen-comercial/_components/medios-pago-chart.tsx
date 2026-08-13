"use client";

import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";

import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCurrency, formatPercent } from "@/lib/utils";
import type { MedioPago } from "../_actions/get-resumen-data";

// Rampa usando los tokens del sistema de diseño (Light/Dark mode compatible)
const PALETTE = [
  "var(--chart-1)",
  "var(--chart-2)",
  "var(--chart-3)",
  "var(--chart-4)",
  "var(--chart-5)",
  "var(--primary)",
  "var(--accent)",
];

interface Props {
  data: MedioPago[];
}

// Tooltip personalizado para el donut
function DonutTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: Array<{ name: string; value: number; payload: MedioPago }>;
}) {
  if (!active || !payload?.length) return null;
  const { name, value, payload: item } = payload[0];
  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm">
      <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wide">
        {name}
      </p>
      <div className="space-y-0.5 text-xs">
        <div className="flex items-center justify-between gap-5">
          <span className="text-muted-foreground">Total cobrado</span>
          <span className="font-medium tabular-nums">{formatCurrency(value, { currency: "USD" })}</span>
        </div>
        <div className="flex items-center justify-between gap-5">
          <span className="text-muted-foreground">Participación</span>
          <span className="font-medium tabular-nums">{formatPercent(item.porcentaje)}</span>
        </div>
      </div>
    </div>
  );
}

// Leyenda: solo nombre + porcentaje (sin montos)
function LegendList({ data }: { data: MedioPago[] }) {
  return (
    <ul className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-x-6 gap-y-2 w-full max-w-xl mx-auto pt-4 border-t border-border">
      {data.map((item, i) => (
        <li key={i} className="flex items-center justify-between text-xs font-medium text-muted-foreground w-full whitespace-nowrap">
          <div className="flex items-center gap-2 min-w-0">
            <span
              className="h-2.5 w-2.5 shrink-0 rounded-full"
              style={{ backgroundColor: PALETTE[i % PALETTE.length] }}
            />
            <span
              className="min-w-0 truncate text-muted-foreground"
              title={item.medioPago}
            >
              {item.medioPago}
            </span>
          </div>
          <span className="shrink-0 font-semibold tabular-nums ml-2">
            {formatPercent(item.porcentaje)}
          </span>
        </li>
      ))}
    </ul>
  );
}

export function MediosPagoChart({ data }: Props) {
  if (!data.length) {
    return (
      <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">
        Sin datos para el período seleccionado
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center gap-6 w-full">
      {/* Donut — anillo más grueso y prominente */}
      <SafeChartContainer height="h-64 md:h-72" className="w-64 h-64 shrink-0 md:w-72 md:h-72">
        <ResponsiveContainer width="100%" height="100%" minHeight={180}>
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              innerRadius="32%"
              outerRadius="82%"
              dataKey="montoUsd"
              nameKey="medioPago"
              paddingAngle={2}
              strokeWidth={0}
            >
              {data.map((_, idx) => (
                <Cell key={idx} fill={PALETTE[idx % PALETTE.length]} />
              ))}
            </Pie>
            <Tooltip
              content={<DonutTooltip />}
              cursor={false}
            />
          </PieChart>
        </ResponsiveContainer>
      </SafeChartContainer>

      {/* Leyenda: nombre + porcentaje */}
      <div className="w-full">
        <LegendList data={data} />
      </div>
    </div>
  );
}
