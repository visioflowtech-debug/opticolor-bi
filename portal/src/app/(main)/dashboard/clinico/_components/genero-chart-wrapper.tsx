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
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Distribución por Género
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full min-h-[208px] min-w-0">
          <GeneroChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
