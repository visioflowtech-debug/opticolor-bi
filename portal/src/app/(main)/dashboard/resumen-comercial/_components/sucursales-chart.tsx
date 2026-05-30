"use client";

import { useState } from "react";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { formatCurrency, formatCompactCurrency } from "@/lib/utils";
import type { VentaSucursal } from "../_actions/get-resumen-data";
import { useIsMobile } from "@/hooks/use-mobile";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

interface Props {
  data: VentaSucursal[];
}

function SucursalesList({
  items,
  maxValue,
  hasEstimado,
  isMobile,
  openId,
  setOpenId,
  startRank = 0,
}: {
  items: VentaSucursal[];
  maxValue: number;
  hasEstimado: boolean;
  isMobile: boolean;
  openId: number | null;
  setOpenId: (id: number | null) => void;
  startRank?: number;
}) {
  return (
    <div className="flex flex-col gap-2.5 w-full">
      {items.map((item, i) => {
        const ventaPct = maxValue > 0 ? (item.ventaNeta / maxValue) * 100 : 0;
        const estimadoPct =
          hasEstimado && maxValue > 0 ? (item.estimadoCierre / maxValue) * 100 : 0;

        return (
          <Tooltip
            key={item.idSucursal}
            open={isMobile ? openId === item.idSucursal : undefined}
            onOpenChange={(open) => {
              if (!isMobile) return;
              if (open) {
                setOpenId(item.idSucursal);
              } else {
                setOpenId(null);
              }
            }}
          >
            <TooltipTrigger asChild>
              <div className="flex cursor-default items-center gap-3 py-1 hover:bg-muted/50 rounded-lg px-1.5 transition-colors">
                {/* Rank */}
                <span className="w-4 shrink-0 text-right text-[11px] tabular-nums text-muted-foreground">
                  {startRank + i + 1}
                </span>

                {/* Name */}
                <span
                  className="w-28 shrink-0 truncate text-xs font-medium sm:w-36"
                  title={item.nombreSucursal}
                >
                  {item.nombreSucursal}
                </span>

                {/* Progress bars */}
                <div className="min-w-0 flex-1 space-y-0.5">
                  <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
                    <div
                      className="h-full rounded-full bg-primary transition-all duration-500"
                      style={{ width: `${ventaPct}%` }}
                    />
                  </div>
                  {hasEstimado && (
                    <div className="h-1.5 w-full overflow-hidden rounded-full bg-muted">
                      <div
                        className="h-full rounded-full bg-primary/30 transition-all duration-500"
                        style={{ width: `${estimadoPct}%` }}
                      />
                    </div>
                  )}
                </div>

                {/* Value */}
                <span className="w-20 shrink-0 text-right text-xs font-semibold tabular-nums sm:w-24">
                  {formatCompactCurrency(item.ventaNeta)}
                </span>
              </div>
            </TooltipTrigger>

            <TooltipContent
              side="top"
              align="start"
              className="rounded-xl border bg-background/95 p-3 shadow-xl backdrop-blur-sm"
            >
              <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wide text-foreground">
                {item.nombreSucursal}
              </p>
              <div className="space-y-0.5 text-xs">
                <div className="flex items-center justify-between gap-5">
                  <span className="text-muted-foreground">Venta Neta</span>
                  <span className="font-medium tabular-nums text-foreground">
                    {formatCurrency(item.ventaNeta)}
                  </span>
                </div>
                {item.estimadoCierre > 0 && (
                  <div className="flex items-center justify-between gap-5">
                    <span className="text-muted-foreground">Proyección Cierre</span>
                    <span className="font-medium tabular-nums text-foreground">
                      {formatCurrency(item.estimadoCierre)}
                    </span>
                  </div>
                )}
              </div>
            </TooltipContent>
          </Tooltip>
        );
      })}
    </div>
  );
}

export function SucursalesChart({ data }: Props) {
  const isMobile = useIsMobile();
  const [visibleCount, setVisibleCount] = useState(10);
  const [modalCount, setModalCount] = useState(10);
  const [openId, setOpenId] = useState<number | null>(null);

  if (!data.length) {
    return (
      <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">
        Sin datos para el período seleccionado
      </div>
    );
  }

  const sortedData = [...data].sort((a, b) => b.ventaNeta - a.ventaNeta);
  const maxValue = Math.max(...sortedData.map((d) => Math.max(d.ventaNeta, d.estimadoCierre)));
  const hasEstimado = sortedData.some((d) => d.estimadoCierre > 0);

  const displayData = isMobile ? sortedData.slice(0, visibleCount) : sortedData.slice(0, 10);

  return (
    <TooltipProvider delayDuration={120}>
      <div className="flex flex-col gap-3">
        <SucursalesList
          items={displayData}
          maxValue={maxValue}
          hasEstimado={hasEstimado}
          isMobile={isMobile}
          openId={openId}
          setOpenId={setOpenId}
        />

        {/* Móvil: Controles de Carga Incremental In-Card */}
        {isMobile && (
          <div className="mt-2 flex items-center justify-center gap-2 border-t pt-2">
            {visibleCount < sortedData.length && (
              <Button
                variant="ghost"
                size="sm"
                className="text-xs font-semibold text-primary hover:bg-muted/50"
                onClick={() => setVisibleCount((prev) => prev + 10)}
              >
                Ver más sucursales (+{Math.min(10, sortedData.length - visibleCount)})
              </Button>
            )}
            {visibleCount > 10 && (
              <Button
                variant="ghost"
                size="sm"
                className="text-xs font-semibold text-muted-foreground ml-2"
                onClick={() => setVisibleCount(10)}
              >
                Ver menos (Colapsar)
              </Button>
            )}
          </div>
        )}

        {/* Desktop/Tablet: Controles de Modal Completo */}
        {!isMobile && sortedData.length > 10 && (
          <div className="mt-2 flex items-center justify-center border-t pt-2">
            <Dialog onOpenChange={(open) => { if (!open) setModalCount(10); }}>
              <DialogTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-xs font-semibold text-primary hover:bg-muted/50 w-full"
                >
                  Ver todas las sucursales ({sortedData.length})
                </Button>
              </DialogTrigger>
              <DialogContent className="w-[95%] max-w-sm sm:max-w-xl md:max-w-3xl lg:max-w-4xl rounded-2xl p-6 bg-background border shadow-2xl max-h-[85vh] flex flex-col">
                <DialogHeader className="pb-3 border-b">
                  <DialogTitle className="text-base font-bold text-foreground">
                    Ventas Netas por Sucursal
                  </DialogTitle>
                </DialogHeader>
                <div className="flex-1 overflow-y-auto py-4 pr-1">
                  <SucursalesList
                    items={sortedData.slice(0, modalCount)}
                    maxValue={maxValue}
                    hasEstimado={hasEstimado}
                    isMobile={isMobile}
                    openId={openId}
                    setOpenId={setOpenId}
                  />
                </div>
                <div className="pt-3 border-t flex items-center justify-center gap-2">
                  {modalCount < sortedData.length && (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-xs font-semibold text-primary hover:bg-muted/50"
                      onClick={() => setModalCount((prev) => prev + 10)}
                    >
                      Ver más sucursales (+{Math.min(10, sortedData.length - modalCount)})
                    </Button>
                  )}
                  {modalCount > 10 && (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-xs font-semibold text-muted-foreground ml-2"
                      onClick={() => setModalCount(10)}
                    >
                      Ver menos (Colapsar)
                    </Button>
                  )}
                </div>
              </DialogContent>
            </Dialog>
          </div>
        )}

        {hasEstimado && (
          <div className="mt-1 flex items-center gap-4 border-t pt-2 text-[11px] text-muted-foreground">
            <div className="flex items-center gap-1.5">
              <div className="h-2 w-4 rounded-full bg-primary" />
              <span>Venta Neta</span>
            </div>
            <div className="flex items-center gap-1.5">
              <div className="h-1.5 w-4 rounded-full bg-primary/30" />
              <span>Proyección Cierre</span>
            </div>
          </div>
        )}
      </div>
    </TooltipProvider>
  );
}
