import { getTipoLente } from "../_actions/get-eficiencia-data";
import { TipoLenteChart } from "./tipo-lente-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function TipoLenteChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getTipoLente({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Detalle de Órdenes por Tipo de Lente
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[400px] md:h-[500px] min-w-0">
          <TipoLenteChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
