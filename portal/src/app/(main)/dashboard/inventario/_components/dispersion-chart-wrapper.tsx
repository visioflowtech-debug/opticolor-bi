import { getMarcasDetalleData } from "../_actions/get-inventario-data";
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
  const result = await getMarcasDetalleData({ startDate, endDate, sucursales, marcaFilter, grupoFilter });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Eficiencia de Inventario · Stock vs Ventas
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[400px] md:h-[500px] min-w-0">
          <DispersionChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
