"use client";

import {
  Line,
  LineChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { TendenciaExamen } from "../_actions/get-clinica-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { ChartTooltipContainer } from "@/components/ui/chart-tooltip-container";
import { formatCompactNumber } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";

interface Props {
  data: TendenciaExamen[];
}

export function TendenciaExamenesChart({ data }: Props) {
  const isMobile = useIsMobile();

  if (!data.length) {
    return (
      <SafeChartContainer height="h-72">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  return (
    <SafeChartContainer height="h-72">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart
          data={data}
          margin={isMobile ? { top: 10, right: 15, left: -20, bottom: 5 } : { top: 20, right: 30, left: 10, bottom: 20 }}
        >
          <CartesianGrid
            strokeDasharray="3 3"
            horizontal={true}
            vertical={false}
            stroke="var(--border)"
            strokeOpacity={0.6}
          />
          <XAxis
            dataKey="mes_examen_nombre"
            tick={{ fontSize: isMobile ? 10 : 11, fill: "var(--muted-foreground)" }}
            angle={isMobile ? 0 : -45}
            textAnchor={isMobile ? "middle" : "end"}
            height={isMobile ? 30 : 70}
            interval={isMobile ? "preserveStartEnd" : 0}
            tickLine={false}
            axisLine={false}
            tickMargin={10}
          />
          <YAxis
            tickFormatter={(value) => formatCompactNumber(value)}
            tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
            tickLine={false}
            axisLine={false}
            tickMargin={10}
          />
          <Tooltip
            cursor={{ stroke: "var(--muted)", strokeWidth: 2 }}
            content={<ChartTooltipContainer />}
          />
          <Line
            type="linear"
            dataKey="total_examenes"
            name="Total Exámenes"
            stroke="var(--chart-1)"
            strokeWidth={3}
            dot={{ r: 4, fill: "var(--background)", strokeWidth: 2 }}
            activeDot={{ r: 6, strokeWidth: 0 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </SafeChartContainer>
  );
}
