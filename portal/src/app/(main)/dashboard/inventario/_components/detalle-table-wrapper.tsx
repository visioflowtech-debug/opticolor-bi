import { getMarcasDetalleData } from "../_actions/get-inventario-data";
import { DetalleTable } from "./detalle-table";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  marcaFilter: string | null;
  grupoFilter: string | null;
}

export async function DetalleTableWrapper({ startDate, endDate, sucursales, marcaFilter, grupoFilter }: WrapperProps) {
  const result = await getMarcasDetalleData({ startDate, endDate, sucursales, marcaFilter, grupoFilter });
  const data = result.data ?? [];

  return (
    <Card className="flex flex-col overflow-hidden rounded-2xl shadow-md lg:h-[572px]">
      <CardHeader className="shrink-0 pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Detalle por Marca
        </CardTitle>
      </CardHeader>
      <CardContent className="min-h-0 flex-1 overflow-y-auto px-6 py-0 pb-4">
        {result.error && (
          <div className="text-sm text-destructive pb-2 px-1">{result.error}</div>
        )}
        <DetalleTable data={data} />
      </CardContent>
    </Card>
  );
}
