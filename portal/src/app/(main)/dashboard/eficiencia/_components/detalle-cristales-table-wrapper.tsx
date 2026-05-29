import { getTipoLente } from "../_actions/get-eficiencia-data";
import { DetalleCristalesTable } from "./detalle-cristales-table";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function DetalleCristalesTableWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getTipoLente({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <DetalleCristalesTable data={data} error={result.error} />
  );
}
