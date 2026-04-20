// TypeScript Interfaces para Portal Opticolor

export interface ResumenComercialRow {
  fecha: string;
  venta_total: number;
  cobrado: number;
  ticket_promedio?: number;
  run_rate?: number;
  otif?: number;
}

export interface EficienciaOrdenesRow {
  fecha: string;
  ordenes_total: number;
  ordenes_proceso: number;
  dias_promedio_entrega: number;
  cumplimiento_fecha: number;
}

export interface ControlCarteraRow {
  fecha: string;
  facturado: number;
  recaudado: number;
  saldo: number;
  dias_cartera: number;
}

export interface DesempenioClinicoRow {
  fecha: string;
  total_examenes: number;
  pacientes_con_compra: number;
  tasa_conversion: number;
  venta_promedio_paciente: number;
}

export interface InventarioRow {
  nombre_producto: string;
  stock_actual: number;
  stock_minimo: number;
  rotacion_dias: number;
  capital_invertido: number;
}

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface User {
  id_usuario: number;
  email: string;
  nombre_completo: string;
  id_rol: number;
  nombre_rol: string;
  nivel_jerarquico: number;
  sucursales: number[];
  permisos: string[];
}
