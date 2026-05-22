import { getOrdenesSucursal } from "../_actions/get-eficiencia-data";
import { OrdenesSucursalChart } from "./ordenes-sucursal-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function OrdenesSucursalChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getOrdenesSucursal({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Órdenes Ejecutadas por Sucursal
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[400px] md:h-[500px] min-w-0">
          <OrdenesSucursalChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
