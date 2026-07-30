import { getMediosPago } from "../_actions/get-resumen-data";
import { MediosPagoChart } from "./medios-pago-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function MediosPagoChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getMediosPago({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Distribución por Medios de Pago
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full min-h-[208px] min-w-0">
          <MediosPagoChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
