import { getDispersionData } from "../_actions/get-inventario-data";
import { DispersionChart } from "./dispersion-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  marcaFilter: string | null;
  grupoFilter: string | null;
}

export async function DispersionChartWrapper({ startDate, endDate, sucursales, marcaFilter, grupoFilter }: WrapperProps) {
  const result = await getDispersionData({ startDate, endDate, sucursales, marcaFilter, grupoFilter });
  const data = result.data ?? [];

  return (
    <Card className="w-full h-full flex flex-col justify-between min-w-0 overflow-hidden rounded-2xl shadow-md border border-slate-100 dark:border-slate-800 bg-white dark:bg-slate-900">
      <CardHeader className="shrink-0 pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Eficiencia de Inventario: Ventas vs. Stock
        </CardTitle>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col min-h-0 pb-4">
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-full min-h-0 flex-grow relative">
          <DispersionChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
