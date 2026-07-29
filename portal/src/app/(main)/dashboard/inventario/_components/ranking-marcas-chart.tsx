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

import { SafeChartContainer } from "@/components/ui/safe-chart-container";
import type { MarcaItem } from "../_actions/get-inventario-data";
import { formatCurrency, formatCompactNumber, truncateText } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

interface Props {
  data: MarcaItem[];
}


interface RankingTooltipProps {
  active?: boolean;
  payload?: Array<{
    payload: {
      marca?: string;
      ventaNetaUsd?: number;
      unidadesVendidas?: number;
      stockFisico?: number;
    };
  }>;
}

function RankingTooltip({ active, payload }: RankingTooltipProps) {
  if (!active || !payload?.length) return null;
  const d = payload[0]?.payload;
  if (!d) return null;

  // ASP por marca — no viene precalculado por la Server Action, se deriva acá
  // de ventaNetaUsd/unidadesVendidas (ya en USD tras la migración).
  const aspUsd = d.unidadesVendidas && d.unidadesVendidas > 0
    ? (d.ventaNetaUsd ?? 0) / d.unidadesVendidas
    : 0;

  return (
    <div className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm">
      <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wide text-foreground">
        {d.marca ?? "SIN MARCA"}
      </p>
      <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
        <span className="text-muted-foreground">Venta Neta Producto:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {formatCurrency(d.ventaNetaUsd ?? 0, { currency: "USD" })}
        </span>
        <span className="text-muted-foreground">Unidades Vendidas:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {d.unidadesVendidas?.toLocaleString("en-US") ?? "0"}
        </span>
        <span className="text-muted-foreground">Stock Físico Unidades:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {d.stockFisico?.toLocaleString("en-US") ?? "0"}
        </span>
        <span className="text-muted-foreground">ASP Precio Promedio:</span>
        <span className="text-right font-medium tabular-nums text-foreground">
          {formatCurrency(aspUsd, { currency: "USD" })}
        </span>
      </div>
    </div>
  );
}

export function RankingMarcasChart({ data }: Props) {
  const isMobile = useIsMobile();
  const [isOpen, setIsOpen] = useState(false);
  const [modalLimit, setModalLimit] = useState(10);
  const [visibleCount, setVisibleCount] = useState(10);

  if (!data.length) {
    return (
      <SafeChartContainer height={isMobile ? "h-[300px]" : "h-[380px]"}>
        <div className="flex h-full items-center justify-center text-sm text-muted-foreground">
          Sin datos para el período seleccionado
        </div>
      </SafeChartContainer>
    );
  }

  const limit = isMobile ? 10 : 18;

  // Ordenar por ventaNetaUsd desc para el ranking
  const sortedData = [...data].sort((a, b) => b.ventaNetaUsd - a.ventaNetaUsd);
  const maxVenta = Math.max(...sortedData.map((d) => d.ventaNetaUsd), 1);

  const incrementLimit = () => setModalLimit((prev) => prev + 10);
  const resetLimit = () => setModalLimit(10);

  const handleOpenChange = (open: boolean) => {
    setIsOpen(open);
    if (!open) {
      resetLimit();
    }
  };

  if (isMobile) {
    const showVerMas = sortedData.length > visibleCount;

    return (
      <div className="flex flex-col h-full w-full justify-between min-h-0">
        <div className="w-full flex flex-col gap-4 py-2 min-h-0 flex-1">
          {sortedData.slice(0, visibleCount).map((brand, index) => {
            const pct = (brand.ventaNetaUsd / maxVenta) * 100;
            return (
              <div key={brand.marca} className="flex flex-col gap-1.5 text-xs">
                <div className="flex items-center justify-between font-medium">
                  <div className="text-sm font-medium flex items-center truncate pr-2">
                    <span className="text-muted-foreground/50 font-normal mr-2 w-5 inline-block text-left">
                      {index + 1}
                    </span>
                    <span className="text-foreground font-normal truncate">{brand.marca}</span>
                  </div>
                  <span className="tabular-nums text-muted-foreground">
                    {formatCurrency(brand.ventaNetaUsd, { currency: "USD" })} ({brand.unidadesVendidas.toLocaleString("en-US")} und)
                  </span>
                </div>
                <div className="w-full h-3 rounded-full bg-secondary overflow-hidden">
                  <div
                    className="bg-[var(--chart-1)] h-full rounded-full transition-all duration-300"
                    style={{ width: `${Math.min(100, Math.max(0, pct))}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>

        <div className="w-full py-3 flex flex-row items-center justify-between gap-4 px-4 border-t bg-muted/30">
          {showVerMas ? (
            <button
              className="text-xs font-semibold text-primary hover:text-primary/80 p-2"
              onClick={() => setVisibleCount((prev) => prev + 10)}
            >
              Ver más marcas (+10)
            </button>
          ) : (
            <div />
          )}
          {visibleCount > 10 && (
            <button
              className="text-xs font-semibold text-muted-foreground hover:text-foreground p-2"
              onClick={() => setVisibleCount(10)}
            >
              Colapsar
            </button>
          )}
        </div>
      </div>
    );
  }

  // Vista Escritorio/Tablet (!isMobile): Limita rígidamente a un Top 10 estricto
  const chartData = sortedData.slice(0, 10).map((m) => ({
    ...m,
    labelTrunc: truncateText(m.marca, limit),
  }));

  return (
    <div className="flex flex-col h-full w-full justify-between min-h-0">
      <div className="flex-grow min-h-0 relative">
        <SafeChartContainer height="h-[330px]">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={chartData}
              layout="vertical"
              margin={{ top: 4, right: 24, left: 0, bottom: 4 }}
            >
              <CartesianGrid
                horizontal={false}
                strokeDasharray="3 3"
                stroke="var(--border)"
                strokeOpacity={0.6}
              />

              <YAxis
                type="category"
                dataKey="labelTrunc"
                width={60}
                tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                tickLine={false}
                axisLine={false}
              />

              <XAxis
                type="number"
                dataKey="ventaNetaUsd"
                tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
                tickLine={false}
                axisLine={false}
                tickFormatter={(v) => formatCompactNumber(v)}
              />

              <Tooltip
                content={<RankingTooltip />}
                cursor={{ fill: "var(--muted)", opacity: 0.4 }}
              />

              <Bar
                dataKey="ventaNetaUsd"
                fill="var(--chart-1)"
                radius={[0, 4, 4, 0]}
                maxBarSize={22}
                opacity={0.9}
              />
            </BarChart>
          </ResponsiveContainer>
        </SafeChartContainer>
      </div>

      {sortedData.length > 10 && (
        <div className="w-full py-2.5 flex justify-center mt-auto border-t bg-muted/30 hover:bg-muted/50 transition-colors">
          <Dialog open={isOpen} onOpenChange={handleOpenChange}>
            <DialogTrigger asChild>
              <Button
                variant="ghost"
                className="text-xs font-semibold text-primary hover:text-primary/80 w-full h-full py-1.5"
              >
                Ver todas las marcas (+{data.length - 10})
              </Button>
            </DialogTrigger>
            <DialogContent className="w-[95%] md:max-w-3xl lg:max-w-4xl max-h-[85vh] flex flex-col">
              <DialogHeader>
                <DialogTitle className="text-base font-semibold">
                  Ranking de Marcas · Todas las marcas
                </DialogTitle>
                <DialogDescription className="sr-only">
                  Listado progresivo de todas las marcas ordenadas por venta neta.
                </DialogDescription>
              </DialogHeader>

              <div className="flex-1 overflow-y-auto pr-1 flex flex-col gap-4 py-4 min-h-0">
                {sortedData.slice(0, modalLimit).map((brand, index) => {
                  const pct = (brand.ventaNetaUsd / maxVenta) * 100;
                  return (
                    <div key={brand.marca} className="flex flex-col gap-1.5 text-xs">
                      <div className="flex items-center justify-between w-full text-sm py-1">
                        {/* Bloque Izquierdo: Índice + Nombre de Marca */}
                        <div className="flex items-center font-medium truncate pr-2">
                          <span className="text-muted-foreground/50 font-normal mr-3 w-6 inline-block text-left shrink-0">
                            {index + 1}
                          </span>
                          <span className="text-foreground font-normal truncate">{brand.marca}</span>
                        </div>

                        {/* Bloque Derecho: Métricas Financieras (USD y Unidades uniformes) */}
                        <div className="text-right font-medium text-muted-foreground shrink-0">
                          {formatCurrency(brand.ventaNetaUsd, { currency: "USD" })}{" "}
                          <span className="text-muted-foreground font-normal text-xs ml-1">
                            ({brand.unidadesVendidas.toLocaleString("en-US")} und)
                          </span>
                        </div>
                      </div>
                      <div className="w-full h-3 rounded-full bg-secondary overflow-hidden">
                        <div
                          className="bg-[var(--chart-1)] h-full rounded-full transition-all duration-300"
                          style={{ width: `${Math.min(100, Math.max(0, pct))}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>

              <div className="w-full pt-4 flex items-center justify-center gap-6 border-t mt-4">
                {sortedData.length > modalLimit && (
                  <Button variant="ghost" className="text-xs text-primary font-medium" onClick={incrementLimit}>
                    Ver más marcas (+10)
                  </Button>
                )}
                {modalLimit > 10 && (
                  <Button variant="ghost" className="text-xs text-muted-foreground font-medium" onClick={resetLimit}>
                    Ver menos (Colapsar)
                  </Button>
                )}
              </div>
            </DialogContent>
          </Dialog>
        </div>
      )}
    </div>
  );
}
