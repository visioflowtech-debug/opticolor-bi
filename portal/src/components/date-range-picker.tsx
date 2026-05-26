"use client";

import * as React from "react";
import { format, startOfMonth } from "date-fns";
import type { DateRange } from "react-day-picker";
import { Calendar as LucideCalendar } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export function DateRangePicker() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const fromParam = searchParams.get("from");
  const toParam = searchParams.get("to");

  // Rango activo real (desde la URL o el mes actual por defecto)
  const appliedRange = React.useMemo<DateRange>(() => {
    return {
      from: fromParam ? new Date(fromParam + "T00:00:00") : startOfMonth(new Date()),
      to: toParam ? new Date(toParam + "T00:00:00") : new Date(),
    };
  }, [fromParam, toParam]);

  // Estados locales independientes primitivos
  const [tempFrom, setTempFrom] = React.useState<Date | undefined>(appliedRange.from);
  const [tempTo, setTempTo] = React.useState<Date | undefined>(appliedRange.to);
  const [isOpen, setIsOpen] = React.useState(false);

  // Sincronizar estados locales cuando cambia el rango aplicado o al abrir/cerrar el popover
  React.useEffect(() => {
    setTempFrom(appliedRange.from);
    setTempTo(appliedRange.to);
  }, [appliedRange, isOpen]);

  const handleOpenChange = (open: boolean) => {
    setIsOpen(open);
    if (!open) {
      // Revertir estados locales si se cierra el popover sin aplicar
      setTempFrom(appliedRange.from);
      setTempTo(appliedRange.to);
    }
  };

  const handleApply = () => {
    if (!tempFrom || !tempTo) return;

    // Formatear estrictamente como YYYY-MM-DD para evitar problemas de huso horario
    const fromStr = format(tempFrom, "yyyy-MM-dd");
    const toStr = format(tempTo, "yyyy-MM-dd");

    const params = new URLSearchParams(searchParams.toString());
    params.set("from", fromStr);
    params.set("to", toStr);

    router.push(`${pathname}?${params.toString()}`);
    setIsOpen(false);
  };

  const handleClear = () => {
    const defaultFrom = startOfMonth(new Date());
    const defaultTo = new Date();

    const params = new URLSearchParams(searchParams.toString());
    params.delete("from");
    params.delete("to");

    router.push(`${pathname}?${params.toString()}`);
    setTempFrom(defaultFrom);
    setTempTo(defaultTo);
    setIsOpen(false);
  };

  const formatDisplayDate = (date: Date) => {
    return format(date, "dd MMM, yyyy");
  };

  const isRangeInvalid = !tempFrom || !tempTo || tempFrom > tempTo;

  return (
    <div className="flex items-center gap-2">
      <Popover open={isOpen} onOpenChange={handleOpenChange}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            className={cn(
              "h-9 justify-start text-left font-normal px-3 py-2 bg-background border-input hover:bg-accent hover:text-accent-foreground select-none flex items-center min-w-[240px] md:min-w-[280px] text-xs transition-colors",
              (!appliedRange.from || !appliedRange.to) && "text-muted-foreground"
            )}
          >
            <LucideCalendar className="mr-2 h-3.5 w-3.5 text-muted-foreground shrink-0" />
            <span className="truncate">
              {appliedRange.from && appliedRange.to ? (
                <>
                  {formatDisplayDate(appliedRange.from)} - {formatDisplayDate(appliedRange.to)}
                </>
              ) : (
                "Seleccionar fechas"
              )}
            </span>
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-auto p-0" align="start">
          <div className="flex flex-col">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 divide-y md:divide-y-0 md:divide-x divide-border p-4">
              
              {/* Columna Izquierda: Desde */}
              <div className="flex flex-col">
                <span className="font-medium text-sm text-muted-foreground mb-1 select-none">
                  Desde
                </span>
                <Calendar
                  initialFocus
                  mode="single"
                  selected={tempFrom}
                  onSelect={setTempFrom}
                  defaultMonth={tempFrom}
                  disabled={{ after: new Date() }}
                  className="p-0"
                />
              </div>

              {/* Columna Derecha: Hasta */}
              <div className="flex flex-col pt-4 md:pt-0 md:pl-4">
                <span className="font-medium text-sm text-muted-foreground mb-1 select-none md:pl-4">
                  Hasta
                </span>
                <div className="md:pl-4">
                  <Calendar
                    mode="single"
                    selected={tempTo}
                    onSelect={setTempTo}
                    defaultMonth={tempTo}
                    disabled={
                      tempFrom
                        ? [{ after: new Date() }, { before: tempFrom }]
                        : { after: new Date() }
                    }
                    className="p-0"
                  />
                </div>
              </div>

            </div>

            {/* Fila de Acciones / Pie */}
            <div className="flex items-center justify-between border-t border-border p-3 bg-muted/40 gap-2">
              <div className="flex items-center gap-2">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handleClear}
                  className="text-xs hover:bg-destructive/10 hover:text-destructive text-muted-foreground h-8 px-3 transition-colors shrink-0"
                >
                  Limpiar
                </Button>
                {tempFrom && tempTo && tempFrom > tempTo && (
                  <span className="text-xs font-medium text-destructive animate-pulse truncate max-w-[150px] sm:max-w-none">
                    La fecha "Hasta" debe ser posterior a "Desde"
                  </span>
                )}
              </div>
              <Button
                size="sm"
                disabled={isRangeInvalid}
                onClick={handleApply}
                className="text-xs h-8 px-3 transition-colors font-medium bg-primary text-primary-foreground hover:bg-primary/95 active:scale-95 disabled:pointer-events-none disabled:opacity-50 shrink-0"
              >
                Aplicar
              </Button>
            </div>
          </div>
        </PopoverContent>
      </Popover>
    </div>
  );
}
