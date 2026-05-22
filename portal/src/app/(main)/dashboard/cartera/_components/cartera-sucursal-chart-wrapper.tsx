import { getCarteraSucursalData } from "../_actions/get-cartera-data";
import { CarteraSucursalChart } from "./cartera-sucursal-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function CarteraSucursalChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getCarteraSucursalData({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Cartera Pendiente por Sucursal
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[400px] md:h-[500px] min-w-0">
          <CarteraSucursalChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
