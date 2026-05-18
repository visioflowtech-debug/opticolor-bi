"use client";

import { useEffect, useState } from "react";

interface SafeChartContainerProps {
  /** Tailwind height class like "h-[350px]" or "h-[500px]". Also applied as
   *  inline style so Recharts ResizeObserver always gets a non-zero dimension,
   *  even before Tailwind CSS finishes hydrating. */
  height?: string;
  /** Extra Tailwind classes merged into the outer div (e.g. 'w-52 shrink-0'). */
  className?: string;
  children: React.ReactNode;
}

/** Parses "h-[350px]" → "350px". Returns undefined for non-pixel patterns. */
function toInlineHeight(cls: string): string | undefined {
  const m = cls.match(/h-\[(\d+(?:\.\d+)?(?:px|rem|vh))\]/);
  return m ? m[1] : undefined;
}

export function SafeChartContainer({
  height = "h-[350px]",
  className = "",
  children,
}: SafeChartContainerProps) {
  const [isMounted, setIsMounted] = useState(false);

  useEffect(() => {
    setIsMounted(true);
  }, []);

  const inlineHeight = toInlineHeight(height);
  const heightStyle = inlineHeight ? { height: inlineHeight } : undefined;

  if (!isMounted) {
    return (
      <div
        className={`${height} ${className} animate-pulse rounded-xl bg-muted`}
        style={heightStyle}
        aria-hidden="true"
      />
    );
  }

  return (
    <div
      className={`${height} ${className} transition-opacity duration-300 ease-in`}
      style={heightStyle}
    >
      {children}
    </div>
  );
}
