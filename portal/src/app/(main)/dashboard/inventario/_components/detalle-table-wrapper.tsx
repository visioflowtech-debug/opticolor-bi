import { getMarcasDetalleData } from "../_actions/get-inventario-data";
import { DetalleTable } from "./detalle-table";

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
    <DetalleTable data={data} error={result.error} />
  );
}
