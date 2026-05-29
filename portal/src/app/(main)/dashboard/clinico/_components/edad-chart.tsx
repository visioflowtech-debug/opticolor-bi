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
import { TooltipProps } from "recharts";
import type { NameType, ValueType, Payload } from "recharts/types/component/DefaultTooltipContent";
import type { EdadExamen } from "../_actions/get-clinica-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCompactNumber } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";

interface Props {
  data: EdadExamen[];
}

function ChartTooltip({
  active,
  payload,
  total,
}: TooltipProps<ValueType, NameType> & {
  payload?: Payload<ValueType, NameType>[];
  total: number;
}) {
  if (!active || !payload?.length) return null;

  const data = payload[0].payload as EdadExamen;
  const pct = total > 0 ? (data.total_examenes / total) * 100 : 0;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm min-w-[200px]">
      <p className="mb-3 text-[12px] font-bold uppercase tracking-wide text-foreground border-b border-border pb-2">
        Rango: {data.rango_edad_descripcion}
      </p>
      <div className="flex flex-col gap-2 text-xs">
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">Pacientes</span>
          <span className="font-semibold tabular-nums text-foreground">
            {new Intl.NumberFormat("en-US").format(data.total_examenes)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">% Participación</span>
          <span className="font-semibold tabular-nums text-foreground">
            {pct.toFixed(1)}%
          </span>
        </div>
      </div>
    </div>
  );
}

export function EdadChart({ data }: Props) {
  const isMobile = useIsMobile();

  if (!data.length) {
    return (
      <div className="flex h-full items-center justify-center text-sm text-muted-foreground min-h-[300px]">
        Sin datos para el período seleccionado
      </div>
    );
  }

  const total = data.reduce((acc, curr) => acc + curr.total_examenes, 0);

  return (
    <div className="flex flex-col h-full w-full min-h-0 justify-between">
      <SafeChartContainer height={isMobile ? "h-[300px]" : "h-[380px]"} className="w-full relative">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart
            data={data}
            layout="horizontal"
            margin={
              isMobile
                ? { top: 10, right: 10, left: -10, bottom: 20 }
                : { top: 15, right: 20, left: 10, bottom: 30 }
            }
          >
            <CartesianGrid
              strokeDasharray="3 3"
              horizontal={true}
              vertical={false}
              stroke="var(--border)"
              strokeOpacity={0.6}
            />
            <XAxis
              dataKey="rango_edad_descripcion"
              type="category"
              tick={{ fontSize: isMobile ? 10 : 11, fill: "var(--muted-foreground)" }}
              angle={isMobile ? 0 : -45}
              textAnchor={isMobile ? "middle" : "end"}
              height={isMobile ? 30 : 60}
              interval={isMobile ? "preserveStartEnd" : 0}
              tickLine={false}
              axisLine={false}
            />
            <YAxis
              type="number"
              tickFormatter={(value) => formatCompactNumber(value)}
              tick={{ fontSize: isMobile ? 10 : 11, fill: "var(--muted-foreground)" }}
              tickLine={false}
              axisLine={false}
              tickMargin={10}
            />
            <Tooltip
              cursor={{ fill: "var(--muted)", opacity: 0.2 }}
              content={<ChartTooltip total={total} />}
            />
            <Bar
              dataKey="total_examenes"
              name="Total Exámenes"
              fill="var(--chart-1)"
              radius={[4, 4, 0, 0]}
              barSize={isMobile ? 16 : 40}
            />
          </BarChart>
        </ResponsiveContainer>
      </SafeChartContainer>
    </div>
  );
}
