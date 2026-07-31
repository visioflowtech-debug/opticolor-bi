export interface ReportParams {
  startDate: string; // "YYYY-MM-DD"
  endDate: string;   // "YYYY-MM-DD"
  sucursales: string | null; // IDs separados por coma, null = todas
  marcaFilter?: string | null; // nombres separados por coma, null = todas (inventario, eficiencia)
  grupoFilter?: string | null; // nombres separados por coma, null = todos (inventario)
  tipoLenteFilter?: string | null; // valores de tipo_lente_agrupado separados por coma, null = todos (eficiencia)
}
