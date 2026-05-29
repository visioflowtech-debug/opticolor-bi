import { getClientesDeudoresTabla } from "../_actions/get-cartera-data";
import { ClientesDeudoresTable } from "./clientes-deudores-table";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function ClientesDeudoresTableWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getClientesDeudoresTabla({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Clientes Deudores
        </CardTitle>
      </CardHeader>
      <CardContent>
        {result.error && (
          <div className="text-sm text-destructive pb-2">{result.error}</div>
        )}
        <ClientesDeudoresTable data={data} />
      </CardContent>
    </Card>
  );
}
