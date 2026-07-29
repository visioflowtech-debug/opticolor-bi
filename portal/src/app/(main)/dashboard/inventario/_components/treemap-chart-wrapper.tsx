import { getGruposMixData } from "../_actions/get-inventario-data";
import { TreemapChart } from "./treemap-chart";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  marcaFilter: string | null;
  grupoFilter: string | null;
}

export async function TreemapChartWrapper({ startDate, endDate, sucursales, marcaFilter, grupoFilter }: WrapperProps) {
  const result = await getGruposMixData({ startDate, endDate, sucursales, marcaFilter, grupoFilter });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md flex flex-col h-auto md:h-[480px] w-full min-w-0 justify-between">
      <CardHeader className="shrink-0 pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Mix de Venta por Grupo Comercial
        </CardTitle>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col min-h-0 pb-4">
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <div className="w-full h-full min-h-0 flex-grow relative">
          <TreemapChart data={data} />
        </div>
      </CardContent>
    </Card>
  );
}
