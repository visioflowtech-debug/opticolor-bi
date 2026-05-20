"use client";

import { useState, useEffect, useRef } from "react";
import { usePathname } from "next/navigation";

import { cn } from "@/lib/utils";
import { ReportFilters } from "./report-filters";
import type { MiSucursal } from "../../_actions/get-mis-sucursales";
import { SidebarTrigger } from "@/components/ui/sidebar";

// Rutas donde la navbar se oculta por completo
const CONFIG_ROUTES = [
  "/dashboard/usuarios",
  "/dashboard/sucursales",
  "/dashboard/perfil",
];

// Rutas de reportes donde aparecen los filtros
const REPORT_ROUTES = [
  "/dashboard/resumen-comercial",
  "/dashboard/cartera",
  "/dashboard/eficiencia",
  "/dashboard/clinico",
  "/dashboard/inventario",
];

interface Props {
  sucursales?: MiSucursal[];
}

export function DashboardHeader({ sucursales = [] }: Props) {
  const pathname = usePathname();
  const [isVisible, setIsVisible] = useState(true);
  const lastScrollYRef = useRef(0);

  useEffect(() => {
    const handleScroll = () => {
      const currentY = window.scrollY;
      setIsVisible(currentY <= 50 || currentY < lastScrollYRef.current);
      lastScrollYRef.current = currentY;
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const isConfig = CONFIG_ROUTES.some((r) => pathname.startsWith(r));
  const isReport = REPORT_ROUTES.some((r) => pathname.startsWith(r));

  // Rutas que no son de reporte ni de configuración: sin header
  if (!isReport && !isConfig) return null;

  let title = "";
  if (pathname.startsWith("/dashboard/usuarios")) {
    title = "Gestión de Usuarios";
  } else if (pathname.startsWith("/dashboard/sucursales")) {
    title = "Gestión de Sucursales";
  } else if (pathname.startsWith("/dashboard/perfil")) {
    title = "Mi Perfil";
  }

  const showFilters = isReport && sucursales.length > 0;

  return (
    <header
      className={cn(
        "sticky top-0 z-30 w-full border-b bg-background/95 backdrop-blur shrink-0 items-center justify-between px-4 h-16 md:h-20 flex transition-transform duration-300",
        isVisible ? "translate-y-0" : "-translate-y-full"
      )}
    >
      <div className="flex items-center gap-3">
        <SidebarTrigger className="shrink-0" />
        {title && (
          <span className="font-semibold text-base md:text-lg text-foreground tracking-tight">
            {title}
          </span>
        )}
      </div>

      {showFilters && (
        <div className="flex-1 min-w-0 ml-2 overflow-x-auto">
          <ReportFilters sucursales={sucursales} />
        </div>
      )}
    </header>
  );
}
