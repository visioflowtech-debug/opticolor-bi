"use client";

/**
 * Ejemplo de uso:
 *
 * import { DualKpiCard } from "@/app/(main)/dashboard/_components/dual-kpi-card";
 *
 * <DualKpiCard
 *   title="Venta Neta"
 *   iconName="dollar-sign"
 *   primary={{ label: "Con Impuesto", value: 125430.55 }}
 *   secondary={{ label: "Sin Impuesto", value: 108190.02 }}
 *   subtitle="Periodo seleccionado"
 *   highlight
 * />
 *
 * Nota: `iconName` es un string (no la referencia cruda al componente de
 * lucide-react) porque este componente se renderiza desde Server Components
 * (ej. resumen-comercial/page.tsx) — React no puede serializar una referencia
 * de función/componente en el límite Server→Client, solo datos planos o JSX
 * ya renderizado. Mismo patrón que ya usa `KpiCard` en todo el portal.
 */

import {
  DollarSign,
  type LucideIcon,
} from "lucide-react";

import { cn, formatCurrency } from "@/lib/utils";

const ICON_MAP: Record<string, LucideIcon> = {
  "dollar-sign": DollarSign,
};

interface DualKpiValue {
  label: string;
  value: number;
}

interface DualKpiCardProps {
  title: string;
  primary: DualKpiValue;
  secondary: DualKpiValue;
  iconName?: string;
  subtitle?: string;
  className?: string;
  highlight?: boolean;
  currencyOptions?: Parameters<typeof formatCurrency>[1];
}

export function DualKpiCard({
  title,
  primary,
  secondary,
  iconName,
  subtitle,
  className,
  highlight = false,
  currencyOptions,
}: DualKpiCardProps) {
  const Icon = iconName ? ICON_MAP[iconName] : undefined;
  const iconClass = highlight
    ? "bg-primary text-primary-foreground"
    : "bg-secondary text-secondary-foreground";

  return (
    <div
      className={cn(
        "overflow-hidden rounded-2xl border bg-card p-5 shadow-sm transition-all hover:shadow-md hover:border-primary/50",
        highlight && "border-primary/50 bg-primary/5 shadow-md",
        className,
      )}
    >
      {/* Cabecera: título + ícono circular — idéntica a KpiCard */}
      <div className="flex items-start justify-between gap-3">
        <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground leading-none">
          {title}
        </p>
        {Icon && (
          <div className={cn("flex h-9 w-9 shrink-0 items-center justify-center rounded-full", iconClass)}>
            <Icon className="h-4 w-4" />
          </div>
        )}
      </div>

      {/* Par de valores: apilados en mobile, lado a lado desde sm: */}
      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div>
          <p className="text-[10px] font-medium uppercase tracking-wide text-muted-foreground/80 leading-none">
            {primary.label}
          </p>
          <p className="mt-1.5 text-xl md:text-2xl font-bold tabular-nums leading-none text-foreground">
            {formatCurrency(primary.value, currencyOptions)}
          </p>
        </div>
        <div className="sm:border-l sm:pl-3">
          <p className="text-[10px] font-medium uppercase tracking-wide text-muted-foreground/80 leading-none">
            {secondary.label}
          </p>
          <p className="mt-1.5 text-xl md:text-2xl font-bold tabular-nums leading-none text-foreground/80">
            {formatCurrency(secondary.value, currencyOptions)}
          </p>
        </div>
      </div>

      {subtitle && (
        <p className="mt-3 text-[11px] text-muted-foreground">{subtitle}</p>
      )}
    </div>
  );
}
