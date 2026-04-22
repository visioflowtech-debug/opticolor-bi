"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";

import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

// Mapear rutas a labels legibles
const routeLabels: Record<string, string> = {
  dashboard: "Dashboard",
  default: "Inicio",
  "resumen-comercial": "Resumen Comercial",
  "eficiencia-ordenes": "Eficiencia Órdenes",
  "control-cartera": "Control Cartera",
  "desempenio-clinico": "Desempeño Clínico",
  inventario: "Inventario",
  analytics: "Análisis",
  crm: "CRM",
  finance: "Finanzas",
};

export function DashboardBreadcrumb() {
  const pathname = usePathname();

  // Extraer segmentos de la ruta
  const segments = pathname
    .split("/")
    .filter((s) => s && s !== "dashboard")
    .slice(0, 3); // Limitar a 3 niveles

  if (segments.length === 0) {
    return null;
  }

  return (
    <Breadcrumb className="mb-4">
      <BreadcrumbList>
        {/* Home link */}
        <BreadcrumbItem>
          <BreadcrumbLink asChild>
            <Link href="/dashboard/default">Dashboard</Link>
          </BreadcrumbLink>
        </BreadcrumbItem>

        {/* Intermediate segments */}
        {segments.slice(0, -1).map((segment, idx) => (
          <div key={idx} className="flex items-center gap-2">
            <BreadcrumbSeparator />
            <BreadcrumbItem>
              <BreadcrumbLink asChild>
                <Link href={`/dashboard/${segments.slice(0, idx + 1).join("/")}`}>
                  {routeLabels[segment] || segment}
                </Link>
              </BreadcrumbLink>
            </BreadcrumbItem>
          </div>
        ))}

        {/* Current page */}
        <div className="flex items-center gap-2">
          <BreadcrumbSeparator />
          <BreadcrumbItem>
            <BreadcrumbPage>{routeLabels[segments[segments.length - 1]] || segments[segments.length - 1]}</BreadcrumbPage>
          </BreadcrumbItem>
        </div>
      </BreadcrumbList>
    </Breadcrumb>
  );
}
