import { getGeneroExamen } from "../_actions/get-clinica-data";
import { GeneroChart } from "./genero-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function GeneroChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getGeneroExamen({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md flex flex-col w-full h-auto md:h-[480px] min-w-0">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Distribución por Género
        </CardTitle>
      </CardHeader>
      <CardContent className="flex-grow flex flex-col min-h-0 pt-0 pb-4">
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-full min-h-0 flex-grow relative">
          <GeneroChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
