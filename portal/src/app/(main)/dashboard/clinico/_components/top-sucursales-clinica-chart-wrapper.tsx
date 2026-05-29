import { getTopSucursalesExamen } from "../_actions/get-clinica-data";
import { TopSucursalesClinicaChart } from "./top-sucursales-clinica-chart";

interface WrapperProps {
  startDate: string;
  endDate: string;
  sucursales: string | null;
}

export async function TopSucursalesClinicaChartWrapper({ startDate, endDate, sucursales }: WrapperProps) {
  const result = await getTopSucursalesExamen({ startDate, endDate, sucursales });
  const data = result.data ?? [];

  return (
    <div className="w-full h-auto md:h-[480px] min-w-0">
      <TopSucursalesClinicaChart data={data} error={result.error} />
    </div>
  );
}
