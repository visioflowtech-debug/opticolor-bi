import { getGapCobroData } from "../_actions/get-cartera-data";
import { GapCobroChart } from "./gap-cobro-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function GapCobroChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getGapCobroData({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Tendencia de la Cartera (GAP de Cobro)
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[288px] min-w-0">
          <GapCobroChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
