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

// ─── Perfil de Usuario (/dashboard/perfil) ────────────────────────────────────

export interface UserProfileSucursal {
  id_sucursal: number;
  nombre_sucursal: string;
  ciudad: string;
  estado: string;
  es_corporativo: boolean;
  fecha_asignacion: string; // ISO string
}

export interface UserProfilePermiso {
  nombre_permiso: string;
  descripcion_permiso: string;
  modulo: string;
  accion: string;
}

export interface UserProfileSesion {
  ip_origen: string;
  user_agent: string;
  fecha_inicio: string;
  fecha_expiracion: string;
  esta_activa: boolean;
}

export interface UserProfileAuditoria {
  accion: string;
  tabla_afectada: string;
  resultado: string;
  ip_origen: string;
  fecha_accion: string;
}

/** Tipo completo retornado por GET /api/user/profile/[id] */
export interface UserProfile {
  // Datos personales
  id_usuario: number;
  email: string;
  nombre_completo: string;
  esta_activo: boolean;
  ultima_sesion: string | null;
  fecha_creacion: string;
  usuario_creacion: string;
  fecha_modificacion: string | null;
  // Rol activo
  id_rol: number;
  nombre_rol: string;
  descripcion_rol: string;
  nivel_jerarquico: number;
  fecha_asignacion_rol: string;
  // Arrays resueltos desde JSON
  permisos: UserProfilePermiso[];
  sucursales: UserProfileSucursal[];
  ultima_sesion_detalle: UserProfileSesion | null;
  auditoria_reciente: UserProfileAuditoria[];
}

/** Fila cruda que retorna Azure SQL antes de parsear los JSON columns */
export interface UserProfileRaw
  extends Omit<UserProfile, 'permisos' | 'sucursales' | 'ultima_sesion_detalle' | 'auditoria_reciente'> {
  permisos_json: string | null;
  sucursales_json: string | null;
  ultima_sesion_json: string | null;
  auditoria_json: string | null;
}
