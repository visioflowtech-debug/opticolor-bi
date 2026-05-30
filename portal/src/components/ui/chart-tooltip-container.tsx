"use client";

interface TooltipPayloadItem {
  name?: string;
  value?: number | string;
  color?: string;
  fill?: string;
  stroke?: string;
}

interface ChartTooltipContainerProps {
  active?: boolean;
  payload?: TooltipPayloadItem[];
  label?: string;
  isCurrency?: boolean;
}

export function ChartTooltipContainer({
  active,
  payload,
  label,
  isCurrency = false,
}: ChartTooltipContainerProps) {
  if (!active || !payload?.length) return null;

  return (
    <div className="rounded-xl border border-border bg-background/95 p-3 shadow-xl backdrop-blur-sm min-w-[180px]">
      <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <div className="flex flex-col gap-1">
        {payload.map((item, index) => {
          const color = item.color ?? item.fill ?? item.stroke;
          const numericValue =
            typeof item.value === "number" ? item.value : Number(item.value ?? 0);
          const formatted = isCurrency
            ? `Bs. ${numericValue.toLocaleString("en-US", {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })}`
            : numericValue.toLocaleString("en-US");

          return (
            <div
              key={index}
              className="flex items-center justify-between gap-4 text-xs font-medium text-foreground"
            >
              <div className="flex items-center gap-1.5">
                {color && (
                  <span
                    className="h-2 w-2 rounded-full"
                    style={{ backgroundColor: color }}
                  />
                )}
                <span className="text-muted-foreground">{item.name ?? "Valor"}:</span>
              </div>
              <span className="font-semibold tabular-nums">{formatted}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
