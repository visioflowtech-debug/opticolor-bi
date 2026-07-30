import { getTendenciaOrden } from "../_actions/get-eficiencia-data";
import { TendenciaOrdenesChart } from "./tendencia-ordenes-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function TendenciaOrdenesChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getTendenciaOrden({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Tendencia de Órdenes
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[288px] min-w-0">
          <TendenciaOrdenesChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
