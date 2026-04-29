-- ============================================================================
-- QUERY: Perfil completo de usuario para /dashboard/perfil
-- DB:    db-opticolor-dw  |  Creado: 28 Abril 2026
-- Uso:   Un solo round-trip a Azure SQL. Los arrays vienen como JSON strings
--        que se parsean en el API route de Next.js.
-- Param: @id_usuario INT
-- ============================================================================

-- ─── ANÁLISIS DE TABLAS INVOLUCRADAS ─────────────────────────────────────────
--
-- Seguridad_Usuarios       → datos personales
--   id_usuario, email, nombre_completo, [password_hash ⛔], esta_activo,
--   ultima_sesion, fecha_creacion, usuario_creacion, fecha_modificacion
--
-- Seguridad_Roles          → catálogo de roles (SUPER_ADMIN=1, MASTER=2, SUPERVISOR=3)
--   id_rol, nombre_rol, descripcion, nivel_jerarquico, esta_activo
--
-- Seguridad_Usuarios_Roles → asignación vigente (esta_vigente=1 = activo)
--   id_usuario FK→Usuarios, id_rol FK→Roles, fecha_asignacion, fecha_revocacion, esta_vigente
--
-- Seguridad_Permisos       → acciones granulares (VER_INFORME_*, ADMIN_USUARIOS…)
--   id_permiso, nombre_permiso, descripcion, modulo, accion, esta_activo
--
-- Seguridad_Roles_Permisos → M:M roles↔permisos
--   id_rol, id_permiso, fecha_asignacion
--
-- Seguridad_Usuarios_Sucursales → RLS; qué sucursales puede ver el usuario
--   id_usuario, id_sucursal, fecha_asignacion, esta_vigente
--   ↳ id_sucursal FK→ Param_Sucursales_Directorio (103 sucursales reales)
--
-- Param_Sucursales_Directorio   → directorio maestro de 103 sucursales VE
--   id_sucursal, nombre, ciudad, estado, es_corporativo, esta_activo
--
-- Seguridad_Sesiones       → historial JWT del portal
--   id_sesion, id_usuario, [token_jwt ⛔], ip_origen, user_agent,
--   fecha_inicio, fecha_expiracion, esta_activa
--
-- Seguridad_Auditoria      → log inmutable de acciones
--   id_auditoria, id_usuario, accion, tabla_afectada, registro_id,
--   [valores_anteriores ⛔], [valores_nuevos ⛔], resultado, [mensaje_error ⛔],
--   ip_origen, fecha_accion
--
-- ─── CAMPOS QUE NUNCA SE EXPONEN ─────────────────────────────────────────────
--   password_hash           → bcrypt hash  ⛔ nunca
--   token_jwt               → JWT activo   ⛔ nunca
--   valores_anteriores      → puede contener PII ⛔ no en perfil
--   valores_nuevos          → ídem         ⛔ no en perfil
--   mensaje_error           → stack traces internos ⛔ no en perfil
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    -- ── Datos personales ──────────────────────────────────────────────────────
    u.id_usuario,
    u.email,
    u.nombre_completo,
    u.esta_activo,
    u.ultima_sesion,
    u.fecha_creacion,
    u.usuario_creacion,
    u.fecha_modificacion,

    -- ── Rol activo ────────────────────────────────────────────────────────────
    r.id_rol,
    r.nombre_rol,
    r.descripcion       AS descripcion_rol,
    r.nivel_jerarquico,
    ur.fecha_asignacion AS fecha_asignacion_rol,

    -- ── Permisos activos del rol (JSON array) ─────────────────────────────────
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

    -- ── Sucursales asignadas (JSON array) ─────────────────────────────────────
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

    -- ── Última sesión registrada (JSON object dentro de array length=1) ────────
    (
        SELECT TOP 1
            ses.ip_origen,
            ses.user_agent,
            ses.fecha_inicio,
            ses.fecha_expiracion,
            CAST(ses.esta_activa AS BIT) AS esta_activa
            -- token_jwt ⛔ EXCLUIDO
        FROM  Seguridad_Sesiones ses
        WHERE ses.id_usuario = u.id_usuario
        ORDER BY ses.fecha_inicio DESC
        FOR JSON PATH
    ) AS ultima_sesion_json,

    -- ── Últimas 5 acciones de auditoría (JSON array) ──────────────────────────
    (
        SELECT TOP 5
            a.accion,
            a.tabla_afectada,
            a.resultado,
            a.ip_origen,
            a.fecha_accion
            -- valores_anteriores ⛔ EXCLUIDO
            -- valores_nuevos     ⛔ EXCLUIDO
            -- mensaje_error      ⛔ EXCLUIDO
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
WHERE u.id_usuario = @id_usuario;

-- ─── NOTAS DE RENDIMIENTO ─────────────────────────────────────────────────────
-- • Índices recomendados:
--     Seguridad_Usuarios_Roles(id_usuario, esta_vigente)
--     Seguridad_Usuarios_Sucursales(id_usuario, esta_vigente)
--     Seguridad_Sesiones(id_usuario, fecha_inicio DESC)
--     Seguridad_Auditoria(id_usuario, fecha_accion DESC)
-- • Tiempo esperado en Azure SQL Basic: < 50 ms con datos actuales
-- • FOR JSON PATH retorna NULL cuando el subconjunto está vacío
--   → el API route maneja esto con `JSON.parse(col ?? '[]')`
-- ─────────────────────────────────────────────────────────────────────────────
