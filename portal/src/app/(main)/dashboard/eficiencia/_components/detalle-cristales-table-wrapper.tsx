import { getTipoLente } from "../_actions/get-eficiencia-data";
import { DetalleCristalesTable } from "./detalle-cristales-table";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function DetalleCristalesTableWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getTipoLente({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Detalle de Órdenes de Cristales por Tipo
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <DetalleCristalesTable data={data} />
      </CardContent>
    </Card>
  );
}
