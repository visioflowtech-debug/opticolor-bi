"use client";

import { useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { CarteraSucursal } from "../_actions/get-cartera-data";
import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import { formatCurrency, formatCompactCurrency } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";
import { Button } from "@/components/ui/button";

interface Props {
  data: CarteraSucursal[];
}

function ChartTooltip({
  active,
  payload,
  label,
}: {
  active?: boolean;
  payload?: Array<{ name: string; value: number; color: string }>;
  label?: string;
}) {
  if (!active || !payload?.length) return null;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm">
      <p className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
        {label}
      </p>
      {payload.map((p) => (
        <div key={p.name} className="flex items-center justify-between gap-6 text-xs">
          <div className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-full" style={{ backgroundColor: p.color }} />
            <span className="text-muted-foreground">Saldo Pendiente</span>
          </div>
          <span className="font-semibold tabular-nums">
            {formatCurrency(p.value)}
          </span>
        </div>
      ))}
    </div>
  );
}

export function CarteraSucursalChart({ data }: Props) {
  const isMobile = useIsMobile();
  const [visibleCount, setVisibleCount] = useState(10);

  if (!data.length) {
    return (
      <SafeChartContainer height="h-[500px]">
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  if (isMobile) {
    // Ordena el arreglo de datos de forma descendente por saldo_pendiente
    const sortedData = [...data].sort((a, b) => b.saldo_pendiente - a.saldo_pendiente);
    
    // Obtener el valor máximo para calcular la participación relativa en barra de progreso
    const maxSaldo = Math.max(...data.map((d) => d.saldo_pendiente), 0);

    // Calcular el porcentaje de participación relativo al máximo
    const dataWithPct = sortedData.map((item) => ({
      ...item,
      porcentaje_participacion: maxSaldo > 0 ? (item.saldo_pendiente / maxSaldo) * 100 : 0,
    }));

    // Carga incremental segmentada por bloques de 10
    const displayData = dataWithPct.slice(0, visibleCount);

    return (
      <div className="w-full space-y-3 p-1">
        {displayData.map((item, index) => (
          <div key={index} className="flex items-center gap-3 w-full">
            {/* Identificador de Categoría/Sucursal con truncado seguro */}
            <span className="w-24 shrink-0 truncate text-[11px] font-semibold text-slate-500">
              {item.nombre_sucursal}
            </span>
            {/* Barra de Progreso CSS Elástica Nativa */}
            <div className="min-w-0 flex-1 h-3 bg-slate-100 rounded-full overflow-hidden">
              <div 
                className="h-full bg-red-500 rounded-full transition-all duration-300" 
                style={{ width: `${item.porcentaje_participacion}%` }}
              />
            </div>
            {/* Exposición directa del dato (Moneda Local Bs.) */}
            <span className="w-28 shrink-0 text-right text-xs font-bold text-slate-900 whitespace-nowrap">
              {formatCurrency(item.saldo_pendiente)}
            </span>
          </div>
        ))}

        {(visibleCount < data.length || visibleCount > 10) && (
          <div className="pt-2 flex items-center justify-center gap-2">
            {visibleCount < data.length && (
              <Button
                variant="ghost"
                size="sm"
                className="text-xs font-semibold text-primary hover:bg-slate-50"
                onClick={() => setVisibleCount((prev) => prev + 10)}
              >
                Ver más sucursales (+{Math.min(10, data.length - visibleCount)})
              </Button>
            )}
            {visibleCount > 10 && (
              <Button
                variant="ghost"
                size="sm"
                className="text-xs font-semibold text-muted-foreground ml-2"
                onClick={() => setVisibleCount(10)} // Resetear al Top 10 inicial de golpe
              >
                Ver menos (Colapsar)
              </Button>
            )}
          </div>
        )}
      </div>
    );
  }

  return (
    <SafeChartContainer height="h-[500px]">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={data}
          layout="horizontal"
          margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
        >
          <CartesianGrid
            strokeDasharray="3 3"
            horizontal={true}
            vertical={false}
            stroke="var(--border)"
            strokeOpacity={0.6}
          />
          <XAxis
            dataKey="nombre_sucursal"
            type="category"
            tick={false}
            tickLine={false}
            axisLine={false}
            height={0}
          />
          <YAxis
            type="number"
            tickFormatter={formatCompactCurrency}
            tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
            tickLine={false}
            axisLine={false}
            width={60}
          />
          <Tooltip cursor={{ fill: "var(--muted)", opacity: 0.2 }} content={<ChartTooltip />} />
          <Bar
            dataKey="saldo_pendiente"
            name="Saldo Pendiente"
            fill="var(--destructive)"
            radius={[4, 4, 0, 0]}
            barSize={24}
          />
        </BarChart>
      </ResponsiveContainer>
    </SafeChartContainer>
  );
}
