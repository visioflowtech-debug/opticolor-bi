import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const getInitials = (str: string): string => {
  if (typeof str !== "string" || !str.trim()) return "?";

  return (
    str
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .map((word) => word[0])
      .join("")
      .toUpperCase() || "?"
  );
};

// ── Formateo compacto financiero ──────────────────────────────────────────────
// Ejemplo: 271_811_337.91 → "271.8 M"
export function formatCompactNumber(value: number): string {
  const abs = Math.abs(value);
  const sign = value < 0 ? "-" : "";
  if (abs >= 1_000_000_000) return `${sign}${(abs / 1_000_000_000).toFixed(1)} B`;
  if (abs >= 1_000_000)     return `${sign}${(abs / 1_000_000).toFixed(1)} M`;
  if (abs >= 1_000)         return `${sign}${(abs / 1_000).toFixed(1)} K`;
  return `${sign}${abs.toFixed(0)}`;
}

// Formateo centralizado de moneda del portal. Ver docs/DOLARIZACION-CONTEXTO.md
// (sección "Estado transitorio"): sin `currency` explícito, el default refleja
// el estado real de los datos hoy (Bs) — no se adelanta a una migración de
// Server Action que todavía no ocurrió. Un reporte pasa a USD recién cuando su
// propio código pide `formatCurrency(valor, { currency: "USD" })` a propósito.
export function formatCurrency(
  amount: number,
  options?: {
    currency?: string;
    locale?: string;
    minimumFractionDigits?: number;
    maximumFractionDigits?: number;
    noDecimals?: boolean;
  },
): string {
  const { currency, locale = "en-US", minimumFractionDigits, maximumFractionDigits, noDecimals } =
    options ?? {};

  const decimalOptions: Intl.NumberFormatOptions = {
    minimumFractionDigits: noDecimals ? 0 : (minimumFractionDigits ?? 2),
    maximumFractionDigits: noDecimals ? 0 : (maximumFractionDigits ?? 2),
  };

  if (!currency) {
    return `Bs. ${new Intl.NumberFormat(locale, decimalOptions).format(amount)}`;
  }

  return new Intl.NumberFormat(locale, { ...decimalOptions, style: "currency", currency }).format(amount);
}

// Versión compacta de formatCurrency: 271_811_337.91 → "Bs. 271.8 M" (o
// "$271.8 M" con { currency: "USD" }, mismo default transitorio que formatCurrency).
// El segundo parámetro también acepta `number` porque varios charts (Cartera,
// Resumen Comercial) pasan esta función directamente como `tickFormatter` de
// Recharts, que la invoca como (value, index) — ese `index` numérico se ignora.
export function formatCompactCurrency(
  value: number,
  options?: { currency?: string } | number,
): string {
  const abs = Math.abs(value);
  const sign = value < 0 ? "-" : "";
  const currencyOptions = typeof options === "object" ? options : undefined;
  const prefix = currencyOptions?.currency === "USD" ? "$" : "Bs. ";
  if (abs >= 1_000_000_000) return `${sign}${prefix}${(abs / 1_000_000_000).toFixed(1)} B`;
  if (abs >= 1_000_000)     return `${sign}${prefix}${(abs / 1_000_000).toFixed(1)} M`;
  if (abs >= 1_000)         return `${sign}${prefix}${(abs / 1_000).toFixed(1)} K`;
  return formatCurrency(value, currencyOptions);
}

export function truncateText(value: string, limit: number = 15): string {
  if (!value) return "";
  return value.length > limit ? `${value.substring(0, limit)}...` : value;
}

/**
 * @deprecated Alias temporal de formatCurrency. Los componentes de Inventario
 * todavía la importan directamente; se elimina cuando ese reporte se migre a
 * USD (ver docs/DOLARIZACION-CONTEXTO.md) y sus call sites pasen a formatCurrency.
 */
export function formatBsCurrency(value: number): string {
  return formatCurrency(value);
}

