"use client";

import * as React from "react";
import { format, subDays, parse, isValid } from "date-fns";
import type { DateRange } from "react-day-picker";

import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Input } from "@/components/ui/input";
import { Calendar as LucideCalendar } from "lucide-react";

interface DateRangePickerProps {
  value?: DateRange;
  onChange?: (value: DateRange | undefined) => void;
}

export function DateRangePicker({ value, onChange }: DateRangePickerProps) {
  const [internalDateRange, setInternalDateRange] = React.useState<DateRange | undefined>(() => {
    const to = new Date();
    const from = subDays(to, 29);
    return { from, to };
  });

  const dateRange = value ?? internalDateRange;
  const fromDate = dateRange?.from;
  const toDate = dateRange?.to;

  const [fromInput, setFromInput] = React.useState("");
  const [toInput, setToInput] = React.useState("");

  // Sincronizar estados locales con los valores reales de fecha
  React.useEffect(() => {
    if (fromDate) {
      setFromInput(format(fromDate, "dd/MM/yyyy"));
    } else {
      setFromInput("");
    }
  }, [fromDate]);

  React.useEffect(() => {
    if (toDate) {
      setToInput(format(toDate, "dd/MM/yyyy"));
    } else {
      setToInput("");
    }
  }, [toDate]);

  const handleFromBlur = () => {
    if (!fromInput) {
      const nextRange: DateRange = {
        from: undefined,
        to: dateRange?.to
      };
      if (!value) setInternalDateRange(nextRange);
      onChange?.(nextRange);
      return;
    }
    const parsed = parse(fromInput, "dd/MM/yyyy", new Date());
    if (isValid(parsed)) {
      const nextRange: DateRange = {
        from: parsed,
        to: dateRange?.to
      };
      if (!value) setInternalDateRange(nextRange);
      onChange?.(nextRange);
    } else if (fromDate) {
      // Revertir a fecha válida previa
      setFromInput(format(fromDate, "dd/MM/yyyy"));
    }
  };

  const handleToBlur = () => {
    if (!toInput) {
      const nextRange: DateRange = {
        from: dateRange?.from,
        to: undefined
      };
      if (!value) setInternalDateRange(nextRange);
      onChange?.(nextRange);
      return;
    }
    const parsed = parse(toInput, "dd/MM/yyyy", new Date());
    if (isValid(parsed)) {
      const nextRange: DateRange = {
        from: dateRange?.from,
        to: parsed
      };
      if (!value) setInternalDateRange(nextRange);
      onChange?.(nextRange);
    } else if (toDate) {
      // Revertir a fecha válida previa
      setToInput(format(toDate, "dd/MM/yyyy"));
    }
  };

  const handleFromDateSelect = (date: Date | undefined) => {
    const nextRange: DateRange = {
      from: date,
      to: dateRange?.to
    };
    if (!value) setInternalDateRange(nextRange);
    onChange?.(nextRange);
  };

  const handleToDateSelect = (date: Date | undefined) => {
    const nextRange: DateRange = {
      from: dateRange?.from,
      to: date
    };
    if (!value) setInternalDateRange(nextRange);
    onChange?.(nextRange);
  };

  return (
    <div className="flex items-center gap-2 w-full sm:w-auto min-w-[280px] md:min-w-[320px] xl:min-w-[400px]">
      {/* Entrada Desde */}
      <div className="flex items-center flex-1 min-w-0">
        <label className="text-xs text-muted-foreground mr-1 shrink-0">Desde</label>
        <div className="relative flex-1 min-w-0 flex items-center">
          <Popover>
            <PopoverTrigger asChild>
              <button
                type="button"
                className="absolute left-2.5 z-10 text-muted-foreground hover:text-foreground cursor-pointer focus:outline-none flex items-center animate-none"
              >
                <LucideCalendar className="h-3.5 w-3.5" />
              </button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="start">
              <Calendar
                mode="single"
                selected={fromDate}
                onSelect={handleFromDateSelect}
                initialFocus
              />
            </PopoverContent>
          </Popover>
          <Input
            type="text"
            className="pl-8 h-9 text-xs w-full bg-background"
            placeholder="DD/MM/YYYY"
            value={fromInput}
            onChange={(e) => setFromInput(e.target.value)}
            onBlur={handleFromBlur}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleFromBlur();
            }}
          />
        </div>
      </div>

      {/* Entrada Hasta */}
      <div className="flex items-center flex-1 min-w-0">
        <label className="text-xs text-muted-foreground mr-1 shrink-0">Hasta</label>
        <div className="relative flex-1 min-w-0 flex items-center">
          <Popover>
            <PopoverTrigger asChild>
              <button
                type="button"
                className="absolute left-2.5 z-10 text-muted-foreground hover:text-foreground cursor-pointer focus:outline-none flex items-center animate-none"
              >
                <LucideCalendar className="h-3.5 w-3.5" />
              </button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="start">
              <Calendar
                mode="single"
                selected={toDate}
                onSelect={handleToDateSelect}
                initialFocus
              />
            </PopoverContent>
          </Popover>
          <Input
            type="text"
            className="pl-8 h-9 text-xs w-full bg-background"
            placeholder="DD/MM/YYYY"
            value={toInput}
            onChange={(e) => setToInput(e.target.value)}
            onBlur={handleToBlur}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleToBlur();
            }}
          />
        </div>
      </div>
    </div>
  );
}
