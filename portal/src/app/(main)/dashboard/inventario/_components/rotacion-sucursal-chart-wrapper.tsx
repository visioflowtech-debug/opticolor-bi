import { getRotacionSucursal } from "../_actions/get-inventario-data";
import { RotacionSucursalChart } from "./rotacion-sucursal-chart";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  marcaFilter: string | null;
  grupoFilter: string | null;
}

export async function RotacionSucursalChartWrapper({ startDate, endDate, sucursales, marcaFilter, grupoFilter }: WrapperProps) {
  const result = await getRotacionSucursal({ startDate, endDate, sucursales, marcaFilter, grupoFilter });
  const data = result.data ?? [];

  return (
    <Card className="w-full h-full flex flex-col justify-between min-w-0 overflow-hidden rounded-2xl shadow-md border border-slate-100 dark:border-slate-800 bg-white dark:bg-slate-900">
      <CardHeader className="shrink-0 pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Ranking de Rotación por Sucursal
        </CardTitle>
        <CardDescription className="text-xs">
          Top 20 tiendas con mayor rotación - unidades vendidas, existencia y % de rotación
        </CardDescription>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col min-h-0 pb-4">
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-full min-h-0 flex-grow relative">
          <RotacionSucursalChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
