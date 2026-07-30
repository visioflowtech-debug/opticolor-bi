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
    <Card className="overflow-hidden rounded-2xl shadow-md h-full flex flex-col">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Mix de Ventas: Participación y Monto Neto
        </CardTitle>
      </CardHeader>
      <CardContent className="h-full flex-1 flex flex-col min-h-0">
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[320px] md:h-[480px] min-w-0 md:pb-0 flex-1">
          <MixVentasChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
