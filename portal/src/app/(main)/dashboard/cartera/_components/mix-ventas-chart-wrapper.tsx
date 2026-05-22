import { getMixVentasData } from "../_actions/get-cartera-data";
import { MixVentasChart } from "./mix-ventas-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function MixVentasChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getMixVentasData({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Mix de Ventas · Participación y Monto Neto
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[400px] md:h-[500px] min-w-0">
          <MixVentasChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
