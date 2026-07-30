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
import type { MixVenta } from "../_actions/get-cartera-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCurrency, formatCompactCurrency, formatNumber } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";

interface Props {
  data: MixVenta[];
}

const truncateLabel = (value: string, isMobile: boolean) => {
  const maxLength = isMobile ? 10 : 20; // Limitar a 10 caracteres en smartphone
  if (value.length > maxLength) {
    return value.substring(0, maxLength) + "...";
  }
  return value;
};

function ChartTooltip({
  active,
  payload,
  totalVenta,
}: TooltipProps<ValueType, NameType> & {
  payload?: Payload<ValueType, NameType>[];
  totalVenta: number;
}) {
  if (!active || !payload?.length) return null;

  const data = payload[0].payload as MixVenta;
  const pct = totalVenta > 0 ? (data.venta_neta_usd / totalVenta) * 100 : 0;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm min-w-[220px]">
      <p className="mb-3 text-[12px] font-bold uppercase tracking-wide text-foreground border-b border-border pb-2">
        {data.categoria_agrupada}
      </p>
      <div className="flex flex-col gap-2 text-xs">
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">Venta Neta</span>
          <span className="font-semibold tabular-nums text-foreground">
            {formatCurrency(data.venta_neta_usd, { currency: "USD" })}
          </span>
        </div>
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">Total Facturas</span>
          <span className="font-semibold tabular-nums text-foreground">
            {formatNumber(data.facturas)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-6">
          <span className="text-muted-foreground">% Participación</span>
          <span className="font-semibold tabular-nums text-foreground">
            {formatNumber(pct, { decimals: 1 })}%
          </span>
        </div>
      </div>
    </div>
  );
}

export function MixVentasChart({ data }: Props) {
  const isMobile = useIsMobile();

  if (!data.length) {
    return (
      <SafeChartContainer
        height={isMobile ? "h-[260px]" : "h-full"}
        className={isMobile ? "md:pb-0 md:p-0" : "min-h-[440px] w-full md:pb-0 md:p-0"}
      >
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  const totalVenta = data.reduce((acc, curr) => acc + curr.venta_neta_usd, 0);

  return (
    <SafeChartContainer
      height={isMobile ? "h-[260px]" : "h-full"}
      className={isMobile ? "md:pb-0 md:p-0" : "min-h-[440px] w-full md:pb-0 md:p-0"}
    >
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={data}
          layout="vertical"
          margin={{
            top: 10,
            right: 15,
            left: isMobile ? 15 : 10,
            bottom: 10
          }}
        >
          <CartesianGrid
            strokeDasharray="3 3"
            horizontal={true}
            vertical={false}
            stroke="var(--border)"
            strokeOpacity={0.6}
          />
          <XAxis
            type="number"
            tickFormatter={(v) => formatCompactCurrency(v, { currency: "USD" })}
            tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
            tickLine={false}
            axisLine={false}
          />
          <YAxis
            dataKey="categoria_agrupada"
            type="category"
            tickFormatter={(val) => truncateLabel(val, isMobile)}
            tick={{ fontSize: isMobile ? 10 : 11, fill: "#475569" }}
            tickLine={false}
            axisLine={false}
            width={isMobile ? 65 : 120}
          />
          <Tooltip
            cursor={{ fill: "var(--muted)", opacity: 0.2 }}
            content={<ChartTooltip totalVenta={totalVenta} />}
            trigger={isMobile ? "click" : "hover"}
          />
          <Bar
            dataKey="venta_neta_usd"
            name="Venta Neta"
            fill="var(--chart-1)"
            radius={[0, 4, 4, 0]}
            barSize={24}
          />
        </BarChart>
      </ResponsiveContainer>
    </SafeChartContainer>
  );
}
