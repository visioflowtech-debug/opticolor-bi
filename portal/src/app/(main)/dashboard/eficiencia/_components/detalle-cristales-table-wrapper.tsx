import { getTipoLente } from "../_actions/get-eficiencia-data";
import { DetalleCristalesTable } from "./detalle-cristales-table";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  tipoLenteFilter: string | null;
  marcaFilter: string | null;
}

export async function DetalleCristalesTableWrapper({ startDate, endDate, sucursales, tipoLenteFilter, marcaFilter }: WrapperProps) {
  const result = await getTipoLente({ startDate, endDate, sucursales, tipoLenteFilter, marcaFilter });
  const data = result.data ?? [];

  return (
    <DetalleCristalesTable data={data} error={result.error} />
  );
}
