import { getVolumenConversion } from "../_actions/get-clinica-data";
import { VolumenConversionChart } from "./volumen-conversion-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function VolumenConversionChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getVolumenConversion({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="w-full h-auto md:h-[480px] flex flex-col justify-between min-w-0 overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Volumen vs Conversión
        </CardTitle>
      </CardHeader>
      <CardContent className="flex-grow flex flex-col min-h-0 p-4 md:p-6 pt-0">
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-full min-h-0 flex-grow relative">
          <VolumenConversionChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
