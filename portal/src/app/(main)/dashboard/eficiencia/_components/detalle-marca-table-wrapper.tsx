import { getDetalleOrdenesPorMarca } from "../_actions/get-eficiencia-data";
import { DetalleMarcaTable } from "./detalle-marca-table";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  tipoLenteFilter: string | null;
  marcaFilter: string | null;
}

export async function DetalleMarcaTableWrapper({ startDate, endDate, sucursales, tipoLenteFilter, marcaFilter }: WrapperProps) {
  const result = await getDetalleOrdenesPorMarca({ startDate, endDate, sucursales, tipoLenteFilter, marcaFilter });
  const data = result.data ?? [];

  return (
    <DetalleMarcaTable data={data} error={result.error} />
  );
}
