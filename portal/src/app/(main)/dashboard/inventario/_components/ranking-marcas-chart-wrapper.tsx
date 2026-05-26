import { getMarcasDetalleData } from "../_actions/get-inventario-data";
import { RankingMarcasChart } from "./ranking-marcas-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  marcaFilter: string | null;
  grupoFilter: string | null;
}

export async function RankingMarcasChartWrapper({ startDate, endDate, sucursales, marcaFilter, grupoFilter }: WrapperProps) {
  const result = await getMarcasDetalleData({ startDate, endDate, sucursales, marcaFilter, grupoFilter });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Ranking de Marcas · Venta Neta
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-[400px] md:h-[500px] min-w-0">
          <RankingMarcasChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
