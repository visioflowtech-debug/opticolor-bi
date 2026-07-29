import { getTendenciaExamen } from "../_actions/get-clinica-data";
import { TendenciaExamenesChart } from "./tendencia-examenes-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function TendenciaExamenesChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getTendenciaExamen({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Tendencia de Exámenes por Mes
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[288px] min-w-0">
          <TendenciaExamenesChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
