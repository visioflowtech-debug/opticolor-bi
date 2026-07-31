import { getOrdenesSucursal } from "../_actions/get-eficiencia-data";
import { OrdenesSucursalChart } from "./ordenes-sucursal-chart";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  tipoLenteFilter: string | null;
  marcaFilter: string | null;
}

export async function OrdenesSucursalChartWrapper({ startDate, endDate, sucursales, tipoLenteFilter, marcaFilter }: WrapperProps) {
  const result = await getOrdenesSucursal({ startDate, endDate, sucursales, tipoLenteFilter, marcaFilter });
  const data = result.data ?? [];

  return (
    <div className="w-full h-auto md:h-[480px] min-w-0">
      <OrdenesSucursalChart data={data} error={result.error} />
    </div>
  );
}
