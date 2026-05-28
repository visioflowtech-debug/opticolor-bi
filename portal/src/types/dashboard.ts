export interface ReportParams {
  startDate: string; // "YYYY-MM-DD"
  endDate: string;   // "YYYY-MM-DD"
  sucursales: string | null; // IDs separados por coma, null = todas
  marcaFilter?: string | null; // nombres separados por coma, null = todas (inventario)
  grupoFilter?: string | null; // nombres separados por coma, null = todos (inventario)
}
