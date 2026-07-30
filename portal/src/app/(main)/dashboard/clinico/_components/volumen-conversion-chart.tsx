"use client";

import {
  ComposedChart,
  Bar,
  Line,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  Legend,
} from "recharts";
import { TooltipProps } from "recharts";
import type { NameType, ValueType, Payload } from "recharts/types/component/DefaultTooltipContent";
import type { VolumenConversion } from "../_actions/get-clinica-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCompactNumber, formatNumber } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";

interface Props {
  data: VolumenConversion[];
}

function ChartTooltip({
  active,
  payload,
}: TooltipProps<ValueType, NameType> & {
  payload?: Payload<ValueType, NameType>[];
}) {
  if (!active || !payload?.length) return null;

  const data = payload[0].payload as VolumenConversion;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm min-w-[220px]">
      <p className="mb-3 text-[12px] font-bold uppercase tracking-wide text-foreground border-b border-border pb-2">
        {data.mes_examen_nombre}
      </p>
      <div className="flex flex-col gap-2 text-xs">
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">Convertidos</span>
          <span className="font-semibold tabular-nums text-primary">
            {formatNumber(data.convertidos)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">No Convertidos</span>
          <span className="font-semibold tabular-nums text-destructive">
            {formatNumber(data.no_convertidos)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">Total Exámenes</span>
          <span className="font-semibold tabular-nums text-foreground">
            {formatNumber(data.total_examenes)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-6 mt-1 border-t border-border pt-2">
          <span className="text-muted-foreground">% Conversión</span>
          <span className="font-semibold tabular-nums text-foreground">
            {formatNumber(data.pct_conversion, { decimals: 1 })}%
          </span>
        </div>
      </div>
    </div>
  );
}

export function VolumenConversionChart({ data }: Props) {
  const isMobile = useIsMobile();

  if (!data.length) {
    return (
      <SafeChartContainer height="h-[350px]">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  const tickFontSize = isMobile ? 10 : 11;
  const barSizeVal = isMobile ? 16 : 40;

  return (
    <div className="flex flex-col h-full w-full min-h-0 justify-between">
      <SafeChartContainer height={isMobile ? "h-[300px]" : "h-[395px]"} className="w-full relative">
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart
            data={data}
            margin={
              isMobile
                ? { top: 15, right: 5, left: -10, bottom: 15 }
                : { top: 15, right: 20, left: -10, bottom: 15 }
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
              dataKey="mes_examen_nombre"
              tick={{ fontSize: tickFontSize, fill: "var(--muted-foreground)" }}
              angle={isMobile ? 0 : -45}
              textAnchor={isMobile ? "middle" : "end"}
              height={isMobile ? 30 : 70}
              interval={isMobile ? "preserveStartEnd" : 0}
              tickLine={false}
              axisLine={false}
              tickMargin={10}
            />
            <YAxis
              yAxisId="left"
              tickFormatter={(value) => formatCompactNumber(value)}
              tick={{ fontSize: tickFontSize, fill: "var(--muted-foreground)" }}
              tickLine={false}
              axisLine={false}
              tickMargin={10}
            />
            <YAxis
              yAxisId="right"
              orientation="right"
              domain={[0, 100]}
              tickFormatter={(value) => `${value}%`}
              tick={{ fontSize: tickFontSize, fill: "var(--muted-foreground)" }}
              tickLine={false}
              axisLine={false}
              tickMargin={10}
              hide={isMobile}
            />
            <Tooltip
              cursor={{ fill: "var(--muted)", opacity: 0.2 }}
              content={<ChartTooltip />}
            />
            <Legend
              align="center"
              verticalAlign="top"
              height={36}
              iconType="circle"
              wrapperStyle={
                isMobile
                  ? { fontSize: "12px", paddingTop: "10px", paddingBottom: 10, left: 5, width: "100%" }
                  : { fontSize: "12px", paddingTop: "10px" }
              }
            />

            {/* Barras Apiladas */}
            <Bar
              yAxisId="left"
              dataKey="convertidos"
              name="Convertidos"
              stackId="a"
              fill="var(--chart-2)"
              radius={[0, 0, 4, 4]}
              barSize={barSizeVal}
            />
            <Bar
              yAxisId="left"
              dataKey="no_convertidos"
              name="No Convertidos"
              stackId="a"
              fill="var(--chart-1)"
              radius={[4, 4, 0, 0]}
              barSize={barSizeVal}
            />

            {/* Línea de Conversión */}
            <Line
              yAxisId="right"
              type="monotone"
              dataKey="pct_conversion"
              name="% Conversión"
              stroke="var(--chart-5)"
              strokeWidth={3}
              dot={{ r: 4, fill: "var(--background)", strokeWidth: 2 }}
              activeDot={{ r: 6, strokeWidth: 0 }}
            />
          </ComposedChart>
        </ResponsiveContainer>
      </SafeChartContainer>
    </div>
  );
}
