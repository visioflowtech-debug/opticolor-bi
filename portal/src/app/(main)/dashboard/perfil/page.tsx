"use client";

import { useSession } from "next-auth/react";
import { useEffect, useState } from "react";
import {
  Activity,
  Building2,
  CalendarDays,
  Globe,
  KeyRound,
  MapPin,
  MonitorSmartphone,
  Shield,
  User,
} from "lucide-react";

import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

import type { UserProfile } from "@/lib/types";
import { cn, getInitials } from "@/lib/utils";

// ─── Constantes ───────────────────────────────────────────────────────────────

const NIVEL_MAX = 5;

// Misma clase de gradiente que usa metric-cards.tsx en dashboard/default
const CARD_GRADIENT =
  "*:data-[slot=card]:bg-linear-to-t *:data-[slot=card]:from-primary/5 *:data-[slot=card]:to-card *:data-[slot=card]:shadow-xs dark:*:data-[slot=card]:bg-card";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function fmt(
  dateStr: string | null | undefined,
  style: "member" | "short" | "full",
): string {
  if (!dateStr) return "—";
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) return "—";
  switch (style) {
    case "member":
      return new Intl.DateTimeFormat("es-VE", {
        month: "long",
        year: "numeric",
      }).format(d);
    case "short":
      return new Intl.DateTimeFormat("es-VE", {
        day: "2-digit",
        month: "long",
        year: "numeric",
      }).format(d);
    case "full":
      return new Intl.DateTimeFormat("es-VE", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      }).format(d);
  }
}

function parseUA(ua: string | null | undefined): string {
  if (!ua) return "Dispositivo desconocido";
  const browsers: [RegExp, string][] = [
    [/Edg\//, "Edge"],
    [/OPR\/|Opera/, "Opera"],
    [/Chrome\//, "Chrome"],
    [/Firefox\//, "Firefox"],
    [/Safari\//, "Safari"],
  ];
  const browser = browsers.find(([re]) => re.test(ua))?.[1] ?? "Navegador";
  const os = /Windows/.test(ua)
    ? "Windows"
    : /Mac OS X/.test(ua)
      ? "macOS"
      : /Android/.test(ua)
        ? "Android"
        : /iPhone|iPad/.test(ua)
          ? "iOS"
          : /Linux/.test(ua)
            ? "Linux"
            : "";
  return os ? `${browser} en ${os}` : browser;
}

// ─── Skeleton de carga ────────────────────────────────────────────────────────

function ProfileSkeleton() {
  return (
    <div className="flex flex-col gap-4 md:gap-6">
      <div className="space-y-2 border-b pb-4">
        <Skeleton className="h-9 w-44" />
        <Skeleton className="h-5 w-80" />
      </div>
      <div className="grid gap-4 lg:grid-cols-3">
        <Skeleton className="h-44 rounded-xl" />
        <Skeleton className="h-44 rounded-xl lg:col-span-2" />
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Skeleton className="h-52 rounded-xl" />
        <Skeleton className="h-52 rounded-xl" />
      </div>
      <Skeleton className="h-64 rounded-xl" />
    </div>
  );
}

// ─── Icono de sección (patrón del dashboard default) ─────────────────────────

function SectionIcon({ icon: Icon }: { icon: React.ElementType }) {
  return (
    <div className="flex size-7 items-center justify-center rounded-lg border bg-muted text-muted-foreground">
      <Icon className="size-4" />
    </div>
  );
}

// ─── Página ───────────────────────────────────────────────────────────────────

export default function PerfilPage() {
  const { data: session, status } = useSession();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (status === "loading") return;

    // NextAuth JWT coloca el id en session.user.id (ver callbacks en [...nextauth]/route.ts)
    const userId = (session?.user as any)?.id as string | undefined;

    if (!userId) {
      setFetchError("__debug__");
      setLoading(false);
      return;
    }

    fetch(`/api/user/profile/${userId}`)
      .then((res) => res.json())
      .then((json) => {
        if (json.success && json.data) {
          setProfile(json.data as UserProfile);
        } else {
          setFetchError("No se pudo cargar la información del perfil.");
        }
      })
      .catch(() => setFetchError("Error de conexión. Intenta recargar la página."))
      .finally(() => setLoading(false));
  }, [session, status]);

  // ── Estado de carga ────────────────────────────────────────────────────────
  if (status === "loading" || loading) return <ProfileSkeleton />;

  // ── Estado de error ────────────────────────────────────────────────────────
  if (fetchError) {
    return (
      <div className="flex flex-col gap-4 md:gap-6">
        <div className="border-b pb-4">
          <h1 className="text-3xl font-bold tracking-tight">Mi Perfil</h1>
        </div>
        <Card>
          <CardContent className="py-8">
            {fetchError === "__debug__" ? (
              <>
                <p className="text-base font-medium text-destructive">
                  Error: ID de sesión no encontrado.
                </p>
                <pre className="mt-4 max-h-40 overflow-auto rounded bg-muted p-2 text-[10px]">
                  {JSON.stringify(session, null, 2)}
                </pre>
              </>
            ) : (
              <>
                <p className="text-base text-muted-foreground">{fetchError}</p>
                <p className="mt-1 text-sm text-muted-foreground">
                  Si el problema persiste, contacta al administrador del sistema.
                </p>
              </>
            )}
          </CardContent>
        </Card>
      </div>
    );
  }

  if (!profile) return null;

  const nivel = profile.nivel_jerarquico;
  const isNacional = nivel <= 2; // SUPER_ADMIN (1) o MASTER (2) → sin filtro geográfico

  // Permisos agrupados por módulo para renderizar como chips
  const permisosPorModulo = profile.permisos.reduce<Record<string, string[]>>(
    (acc, p) => {
      const key = p.modulo || "General";
      if (!acc[key]) acc[key] = [];
      acc[key].push(p.nombre_permiso);
      return acc;
    },
    {},
  );

  return (
    <div className="flex flex-col gap-4 md:gap-6">

      {/* ── Header ──────────────────────────────────────────────────────────── */}
      <div className="border-b pb-4">
        <h1 className="text-3xl font-bold tracking-tight">Mi Perfil</h1>
        <p className="mt-2 text-muted-foreground">
          Información de tu cuenta y accesos en Opticolor BI
        </p>
      </div>

      {/* ── Fila 1: Identidad (1/3) + Rol y Acceso (2/3) ─────────────────── */}
      <div className={cn("grid gap-4 lg:grid-cols-3", CARD_GRADIENT)}>

        {/* Sección 1 — Identidad */}
        <Card>
          <CardHeader>
            <CardTitle>
              <SectionIcon icon={User} />
            </CardTitle>
            <CardDescription>Identidad</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            <div className="flex items-center gap-3">
              <Avatar className="size-14 rounded-xl">
                <AvatarFallback className="rounded-xl text-lg font-semibold">
                  {getInitials(profile.nombre_completo)}
                </AvatarFallback>
              </Avatar>
              <div className="min-w-0 flex flex-col gap-0.5">
                <span className="truncate font-semibold leading-tight">
                  {profile.nombre_completo}
                </span>
                <span className="truncate text-xs text-muted-foreground">
                  {profile.email}
                </span>
              </div>
            </div>

            <Badge
              variant={profile.esta_activo ? "default" : "destructive"}
              className="w-fit"
            >
              {profile.esta_activo ? "Activo" : "Inactivo"}
            </Badge>

            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <CalendarDays className="size-3.5 shrink-0" />
              <span>Miembro desde {fmt(profile.fecha_creacion, "member")}</span>
            </div>
          </CardContent>
        </Card>

        {/* Sección 2 — Rol y Acceso */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>
              <SectionIcon icon={Shield} />
            </CardTitle>
            <CardDescription>Rol y Acceso</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-2xl font-semibold leading-none">
                {profile.nombre_rol}
              </span>
              <Badge variant="secondary">
                Nivel {nivel} de {NIVEL_MAX}
              </Badge>
            </div>

            {profile.descripcion_rol && (
              <p className="text-sm text-muted-foreground">{profile.descripcion_rol}</p>
            )}

            <Separator />

            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <CalendarDays className="size-3.5 shrink-0" />
              <span>Asignado el {fmt(profile.fecha_asignacion_rol, "short")}</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* ── Fila 2: Alcance Geográfico + Sesión Actual ────────────────────── */}
      <div className={cn("grid gap-4 lg:grid-cols-2", CARD_GRADIENT)}>

        {/* Sección 3 — Alcance Geográfico */}
        <Card>
          <CardHeader>
            <CardTitle>
              <SectionIcon icon={Building2} />
            </CardTitle>
            <CardDescription>Alcance Geográfico</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            {isNacional ? (
              <div className="flex items-center gap-2">
                <Globe className="size-4 shrink-0 text-muted-foreground" />
                <Badge variant="secondary">
                  Acceso nacional — todas las sucursales
                </Badge>
              </div>
            ) : profile.sucursales.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                Sin sucursales asignadas.
              </p>
            ) : (
              <ul className="flex flex-col gap-2">
                {profile.sucursales.map((s) => (
                  <li key={s.id_sucursal} className="flex items-start gap-2">
                    <MapPin className="mt-0.5 size-3.5 shrink-0 text-muted-foreground" />
                    <div className="flex flex-col">
                      <span className="text-sm font-medium leading-tight">
                        {s.nombre_sucursal}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        {s.ciudad}, {s.estado}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>

        {/* Sección 5 — Sesión Actual */}
        <Card>
          <CardHeader>
            <CardTitle>
              <SectionIcon icon={MonitorSmartphone} />
            </CardTitle>
            <CardDescription>Sesión Actual</CardDescription>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
              <dt className="text-muted-foreground">Última conexión</dt>
              <dd className="font-medium">{fmt(profile.ultima_sesion, "full")}</dd>

              {profile.ultima_sesion_detalle && (
                <>
                  <dt className="text-muted-foreground">IP de origen</dt>
                  <dd className="font-medium tabular-nums">
                    {profile.ultima_sesion_detalle.ip_origen || "—"}
                  </dd>

                  <dt className="text-muted-foreground">Dispositivo</dt>
                  <dd className="font-medium">
                    {parseUA(profile.ultima_sesion_detalle.user_agent)}
                  </dd>

                  <dt className="text-muted-foreground">Sesión vence</dt>
                  <dd className="font-medium">
                    {fmt(profile.ultima_sesion_detalle.fecha_expiracion, "full")}
                  </dd>
                </>
              )}
            </dl>
          </CardContent>
        </Card>
      </div>

      {/* Sección 4 — Permisos (solo SUPER_ADMIN / MASTER) */}
      {isNacional && Object.keys(permisosPorModulo).length > 0 && (
        <div className={CARD_GRADIENT}>
          <Card>
            <CardHeader>
              <CardTitle>
                <SectionIcon icon={KeyRound} />
              </CardTitle>
              <CardDescription>Permisos</CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-4">
              {Object.entries(permisosPorModulo).map(([modulo, permisos]) => (
                <div key={modulo} className="flex flex-col gap-2">
                  <span className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
                    {modulo}
                  </span>
                  <div className="flex flex-wrap gap-1.5">
                    {permisos.map((nombre) => (
                      <Badge key={nombre} variant="outline" className="font-normal">
                        {nombre}
                      </Badge>
                    ))}
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        </div>
      )}

      {/* Sección 6 — Actividad Reciente */}
      <div className={CARD_GRADIENT}>
        <Card>
          <CardHeader>
            <CardTitle>
              <SectionIcon icon={Activity} />
            </CardTitle>
            <CardDescription>Actividad Reciente</CardDescription>
          </CardHeader>
          <CardContent className="p-0">
            {profile.auditoria_reciente.length === 0 ? (
              <p className="px-4 py-8 text-center text-sm text-muted-foreground">
                Sin actividad registrada.
              </p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Acción</TableHead>
                    <TableHead>Módulo</TableHead>
                    <TableHead>Resultado</TableHead>
                    <TableHead>Fecha</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {profile.auditoria_reciente.map((a, i) => (
                    // biome-ignore lint/suspicious/noArrayIndexKey: lista inmutable de max 5 elementos
                    <TableRow key={i}>
                      <TableCell className="font-medium">{a.accion}</TableCell>
                      <TableCell className="text-muted-foreground">
                        {a.tabla_afectada}
                      </TableCell>
                      <TableCell>
                        <Badge
                          className={cn(
                            "border-transparent",
                            a.resultado === "EXITO"
                              ? "bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"
                              : "bg-destructive/10 text-destructive dark:bg-destructive/20",
                          )}
                        >
                          {a.resultado}
                        </Badge>
                      </TableCell>
                      <TableCell className="tabular-nums text-muted-foreground">
                        {fmt(a.fecha_accion, "full")}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>

    </div>
  );
}
