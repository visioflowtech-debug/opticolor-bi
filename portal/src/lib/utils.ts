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

// Locale venezolano — punto de miles, coma decimal (ej. 1.234,56). Confirmado con
// ejecución real: `Intl.NumberFormat('es-VE', { style: 'currency', currency: 'USD' })`
// antepone "USD" en vez de "$" (da "USD 1.234,56"); con `currencyDisplay:
// 'narrowSymbol'` sí da el símbolo limpio esperado ("$1.234,56"). Ver
// docs/DOLARIZACION-CONTEXTO.md, sección "Formato numérico venezolano".
const VE_LOCALE = "es-VE";

// ── Formateo compacto financiero ──────────────────────────────────────────────
// Ejemplo: 271_811_337.91 → "271,8 M"
export function formatCompactNumber(value: number): string {
  const abs = Math.abs(value);
  const sign = value < 0 ? "-" : "";
  const oneDecimal = (n: number) =>
    new Intl.NumberFormat(VE_LOCALE, { minimumFractionDigits: 1, maximumFractionDigits: 1 }).format(n);
  if (abs >= 1_000_000_000) return `${sign}${oneDecimal(abs / 1_000_000_000)} B`;
  if (abs >= 1_000_000)     return `${sign}${oneDecimal(abs / 1_000_000)} M`;
  if (abs >= 1_000)         return `${sign}${oneDecimal(abs / 1_000)} K`;
  return `${sign}${abs.toFixed(0)}`;
}

// Formateo de números enteros/conteos (no monetarios), con separador de miles
// venezolano. Ejemplo: 60112 → "60.112". Acepta cantidad fija de decimales para
// valores no enteros (promedios, porcentajes, UPT) — ej.
// formatNumber(4.2857, { decimals: 1 }) → "4,3".
export function formatNumber(
  value: number,
  options?: { decimals?: number },
): string {
  const decimals = options?.decimals;
  return new Intl.NumberFormat(VE_LOCALE, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
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
  const { currency, locale = VE_LOCALE, minimumFractionDigits, maximumFractionDigits, noDecimals } =
    options ?? {};

  if (!currency) {
    const decimalOptions: Intl.NumberFormatOptions = {
      minimumFractionDigits: noDecimals ? 0 : (minimumFractionDigits ?? 2),
      maximumFractionDigits: noDecimals ? 0 : (maximumFractionDigits ?? 2),
    };
    return `Bs. ${new Intl.NumberFormat(locale, decimalOptions).format(amount)}`;
  }

  // Montos en USD: se truncan a entero, nunca se redondean (decisión del
  // cliente — ej. 3.815.996,94 debe mostrar 3.815.996, no 3.815.997).
  // Intl.NumberFormat con maximumFractionDigits redondea por defecto, así
  // que la parte decimal se descarta con Math.trunc ANTES de formatear, en
  // vez de confiar en eso. El `|| 0` evita el caso borde `-0` (ej. -0.5
  // truncaría a -0 y se vería como "$-0").
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
    style: "currency",
    currency,
    currencyDisplay: "narrowSymbol",
  }).format(Math.trunc(amount) || 0);
}

// Versión compacta de formatCurrency: 271_811_337.91 → "Bs. 271,8 M" (o
// "$271,8 M" con { currency: "USD" }, mismo default transitorio que formatCurrency).
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
  const isUsd = currencyOptions?.currency === "USD";
  const prefix = isUsd ? "$" : "Bs. ";
  // USD trunca el decimal de la abreviación (mismo criterio que
  // formatCurrency: ej. 2,359 M no sube a 2,4 M). Bs. (formato transitorio
  // Fase 1, fuera del alcance de este cambio) sigue redondeando como antes.
  const oneDecimal = (n: number) => {
    const truncated = isUsd ? Math.trunc(n * 10) / 10 : n;
    return new Intl.NumberFormat(VE_LOCALE, { minimumFractionDigits: 1, maximumFractionDigits: 1 }).format(truncated || 0);
  };
  if (abs >= 1_000_000_000) return `${sign}${prefix}${oneDecimal(abs / 1_000_000_000)} B`;
  if (abs >= 1_000_000)     return `${sign}${prefix}${oneDecimal(abs / 1_000_000)} M`;
  if (abs >= 1_000)         return `${sign}${prefix}${oneDecimal(abs / 1_000)} K`;
  return formatCurrency(value, currencyOptions);
}

export function truncateText(value: string, limit: number = 15): string {
  if (!value) return "";
  return value.length > limit ? `${value.substring(0, limit)}...` : value;
}

