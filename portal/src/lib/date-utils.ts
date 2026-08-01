export const MAP_MES_NAME_TO_ABBR: Record<string, string> = {
  Enero: "Ene", Febrero: "Feb", Marzo: "Mar", Abril: "Abr", Mayo: "May", Junio: "Jun",
  Julio: "Jul", Agosto: "Ago", Septiembre: "Sep", Octubre: "Oct", Noviembre: "Nov", Diciembre: "Dic"
};

export const MAP_MES_NUM_TO_ABBR: Record<string, string> = {
  "01": "Ene", "02": "Feb", "03": "Mar", "04": "Abr", "05": "May", "06": "Jun",
  "07": "Jul", "08": "Ago", "09": "Sep", "10": "Oct", "11": "Nov", "12": "Dic"
};

// Rango de fechas por defecto (mes en curso) cuando el usuario no filtró nada,
// en hora de Venezuela (GMT-4) — nunca en la hora del proceso Node, que en el
// contenedor de producción corre en UTC (sin `new Date()` sin ajustar, el
// calendario se adelanta hasta 4 horas: a las 8pm del 31/07 en Venezuela ya es
// 1 de agosto en UTC). Se calcula restando 4h al epoch y leyendo con los
// getters UTC*, el mismo patrón ya usado en getResumenKPIs — funciona sin
// depender de la zona horaria configurada en el proceso.
export function getDefaultDateRangeGMT4(): { startDate: string; endDate: string } {
  const nowGMT4 = new Date(Date.now() - 4 * 60 * 60 * 1000);
  const year = nowGMT4.getUTCFullYear();
  const month = String(nowGMT4.getUTCMonth() + 1).padStart(2, "0");
  const day = String(nowGMT4.getUTCDate()).padStart(2, "0");
  return {
    startDate: `${year}-${month}-01`,
    endDate: `${year}-${month}-${day}`,
  };
}
