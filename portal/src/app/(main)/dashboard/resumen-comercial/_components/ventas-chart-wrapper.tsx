import { getVentasDiarias } from "../_actions/get-resumen-data";
import { VentasChart } from "./ventas-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function VentasChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getVentasDiarias({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Tendencia Anual · Ventas y Tráfico
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[300px] md:h-[350px] min-w-0">
          <VentasChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
