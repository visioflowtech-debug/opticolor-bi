import { getTipoLente } from "../_actions/get-eficiencia-data";
import { TipoLenteChart } from "./tipo-lente-chart";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  tipoLenteFilter: string | null;
  marcaFilter: string | null;
}

export async function TipoLenteChartWrapper({ startDate, endDate, sucursales, tipoLenteFilter, marcaFilter }: WrapperProps) {
  const result = await getTipoLente({ startDate, endDate, sucursales, tipoLenteFilter, marcaFilter });
  const data = result.data ?? [];

  return (
    <div className="w-full h-auto md:h-[480px] min-w-0">
      <TipoLenteChart data={data} error={result.error} />
    </div>
  );
}
