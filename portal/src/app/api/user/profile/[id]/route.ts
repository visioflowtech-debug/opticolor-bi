import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/config/auth';
import { query } from '@/lib/db';
import type { ApiResponse, UserProfile, UserProfileRaw } from '@/lib/types';

// ─── Constantes de jerarquía ──────────────────────────────────────────────────
const NIVEL_SUPER_ADMIN = 1; // Solo SUPER_ADMIN puede ver perfil de cualquier usuario

// ─── Query SQL (un solo round-trip a Azure SQL) ───────────────────────────────
// Referencia completa: /sql/queries/perfil_usuario.sql
const QUERY_PERFIL = `
SELECT
    u.id_usuario,
    u.email,
    u.nombre_completo,
    u.esta_activo,
    u.ultima_sesion,
    u.fecha_creacion,
    u.usuario_creacion,
    u.fecha_modificacion,

    r.id_rol,
    r.nombre_rol,
    r.descripcion       AS descripcion_rol,
    r.nivel_jerarquico,
    ur.fecha_asignacion AS fecha_asignacion_rol,

    (
        SELECT
            p.nombre_permiso,
            p.descripcion   AS descripcion_permiso,
            p.modulo,
            p.accion
        FROM  Seguridad_Roles_Permisos  rp2
        JOIN  Seguridad_Permisos        p   ON p.id_permiso = rp2.id_permiso
                                           AND p.esta_activo = 1
        WHERE rp2.id_rol = ur.id_rol
        ORDER BY p.modulo, p.nombre_permiso
        FOR JSON PATH
    ) AS permisos_json,

    (
        SELECT
            psd.id_sucursal,
            psd.nombre      AS nombre_sucursal,
            psd.ciudad,
            psd.estado,
            CAST(psd.es_corporativo AS BIT) AS es_corporativo,
            us2.fecha_asignacion
        FROM  Seguridad_Usuarios_Sucursales us2
        JOIN  Param_Sucursales_Directorio   psd ON psd.id_sucursal = us2.id_sucursal
                                               AND psd.esta_activo  = 1
        WHERE us2.id_usuario   = u.id_usuario
          AND us2.esta_vigente  = 1
        ORDER BY psd.estado, psd.nombre
        FOR JSON PATH
    ) AS sucursales_json,

    (
        SELECT TOP 1
            ses.ip_origen,
            ses.user_agent,
            ses.fecha_inicio,
            ses.fecha_expiracion,
            CAST(ses.esta_activa AS BIT) AS esta_activa
        FROM  Seguridad_Sesiones ses
        WHERE ses.id_usuario = u.id_usuario
        ORDER BY ses.fecha_inicio DESC
        FOR JSON PATH
    ) AS ultima_sesion_json,

    (
        SELECT TOP 5
            a.accion,
            a.tabla_afectada,
            a.resultado,
            a.ip_origen,
            a.fecha_accion
        FROM  Seguridad_Auditoria a
        WHERE a.id_usuario = u.id_usuario
        ORDER BY a.fecha_accion DESC
        FOR JSON PATH
    ) AS auditoria_json

FROM  Seguridad_Usuarios      u
JOIN  Seguridad_Usuarios_Roles ur ON ur.id_usuario  = u.id_usuario
                                 AND ur.esta_vigente = 1
JOIN  Seguridad_Roles          r  ON r.id_rol        = ur.id_rol
                                 AND r.esta_activo    = 1
WHERE u.id_usuario = @id_usuario
`;

// ─── Helpers ──────────────────────────────────────────────────────────────────

function parseJsonColumn<T>(raw: string | null, fallback: T): T {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function mapRawToProfile(raw: UserProfileRaw): UserProfile {
  return {
    id_usuario:           raw.id_usuario,
    email:                raw.email,
    nombre_completo:      raw.nombre_completo,
    esta_activo:          raw.esta_activo,
    ultima_sesion:        raw.ultima_sesion,
    fecha_creacion:       raw.fecha_creacion,
    usuario_creacion:     raw.usuario_creacion,
    fecha_modificacion:   raw.fecha_modificacion,
    id_rol:               raw.id_rol,
    nombre_rol:           raw.nombre_rol,
    descripcion_rol:      raw.descripcion_rol,
    nivel_jerarquico:     raw.nivel_jerarquico,
    fecha_asignacion_rol: raw.fecha_asignacion_rol,
    permisos:             parseJsonColumn(raw.permisos_json, []),
    sucursales:           parseJsonColumn(raw.sucursales_json, []),
    ultima_sesion_detalle: (() => {
      const arr = parseJsonColumn<UserProfile['ultima_sesion_detalle'][]>(raw.ultima_sesion_json, []);
      return arr?.[0] ?? null;
    })(),
    auditoria_reciente: parseJsonColumn(raw.auditoria_json, []),
  };
}

// ─── Route Handler ────────────────────────────────────────────────────────────

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
): Promise<NextResponse<ApiResponse<UserProfile>>> {
  try {
    const session = await auth();

    if (!session?.user) {
      return NextResponse.json(
        { success: false, error: 'No autenticado' },
        { status: 401 }
      );
    }

    const { id } = await params;
    const targetId = Number(id);

    if (!Number.isInteger(targetId) || targetId <= 0) {
      return NextResponse.json(
        { success: false, error: 'ID de usuario inválido' },
        { status: 400 }
      );
    }

    const sessionUserId    = Number(session.user.id);
    const sessionNivel     = (session.user as any).nivel_jerarquico as number;
    const isSuperAdmin     = sessionNivel === NIVEL_SUPER_ADMIN;
    const isOwnProfile     = sessionUserId === targetId;

    // Solo el propio usuario o SUPER_ADMIN pueden acceder
    if (!isOwnProfile && !isSuperAdmin) {
      return NextResponse.json(
        { success: false, error: 'Acceso denegado' },
        { status: 403 }
      );
    }

    const rows = await query<UserProfileRaw>(QUERY_PERFIL, { id_usuario: targetId });

    if (!rows.length) {
      return NextResponse.json(
        { success: false, error: 'Usuario no encontrado' },
        { status: 404 }
      );
    }

    const profile = mapRawToProfile(rows[0]);

    return NextResponse.json(
      { success: true, data: profile },
      { status: 200 }
    );
  } catch (error) {
    console.error('[API] Error en /api/user/profile/[id]:', error);
    return NextResponse.json(
      { success: false, error: 'Error obteniendo perfil' },
      { status: 500 }
    );
  }
}
