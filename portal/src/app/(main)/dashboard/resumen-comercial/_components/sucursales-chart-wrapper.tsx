import { getTopSucursales } from "../_actions/get-resumen-data";
import { SucursalesChart } from "./sucursales-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function SucursalesChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getTopSucursales({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Top Sucursales: Venta Real vs. Estimados Cierre
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <SucursalesChart data={data} />
      </CardContent>
    </Card>
  );
}
