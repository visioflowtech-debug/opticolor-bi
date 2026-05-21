"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { startOfMonth } from "date-fns";
import type { DateRange } from "react-day-picker";
import { Layers, MapPin, Tag } from "lucide-react";

import { DateRangePicker } from "@/components/date-range-picker";
import type { MiSucursal } from "../../_actions/get-mis-sucursales";
import { getMarcasGrupos } from "../../inventario/_actions/get-inventario-filters";
import { MultiSelectFilter } from "./multi-select-filter";

interface Props {
  sucursales: MiSucursal[];
}

export function ReportFilters({ sucursales }: Props) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const fromParam = searchParams.get("from");
  const toParam = searchParams.get("to");
  const sucursalParam = searchParams.get("sucursal");
  const marcaParam = searchParams.get("marca");
  const grupoParam = searchParams.get("grupo");

  const isInventario = pathname.startsWith("/dashboard/inventario");

  // Arrays de selección derivados de los params de la URL
  const sucursalesSelected = sucursalParam ? sucursalParam.split(",").filter(Boolean) : [];
  const marcasSelected = marcaParam ? marcaParam.split(",").filter(Boolean) : [];
  const gruposSelected = grupoParam ? grupoParam.split(",").filter(Boolean) : [];

  // Opciones de Marca y Grupo — se cargan solo en la ruta de inventario
  const [marcas, setMarcas] = useState<string[]>([]);
  const [grupos, setGrupos] = useState<string[]>([]);

  useEffect(() => {
    if (!isInventario) return;
    getMarcasGrupos()
      .then(({ data }) => {
        if (data) {
          setMarcas(data.marcas);
          setGrupos(data.grupos);
        }
      })
      .catch(() => {/* fail silently */});
  }, [isInventario]);

  // ── Date Range ────────────────────────────────────────────────────────────

  const [localDateRange, setLocalDateRange] = useState<DateRange>({
    from: fromParam ? new Date(fromParam) : startOfMonth(new Date()),
    to: toParam ? new Date(toParam) : new Date(),
  });

  const debounceTimer = useRef<NodeJS.Timeout | null>(null);

  const handleDateChange = useCallback(
    (range: DateRange | undefined) => {
      if (!range?.from) return;
      const fromDate = range.from;
      const toDate = range.to;

      const newFromStr = fromDate.toISOString();
      const newToStr = toDate ? toDate.toISOString() : null;

      const currentParams = new URLSearchParams(window.location.search);
      const currentFrom = currentParams.get("from");
      const currentTo = currentParams.get("to");

      if (currentFrom === newFromStr && currentTo === newToStr) return;

      setLocalDateRange(range);

      if (debounceTimer.current) clearTimeout(debounceTimer.current);

      debounceTimer.current = setTimeout(() => {
        const freshParams = new URLSearchParams(window.location.search);
        freshParams.set("from", newFromStr);
        if (newToStr) freshParams.set("to", newToStr);
        else freshParams.delete("to");
        router.replace(`${pathname}?${freshParams.toString()}`, { scroll: false });
      }, 500);
    },
    [pathname, router],
  );

  const handleSucursalChange = useCallback(
    (vals: string[]) => {
      const params = new URLSearchParams(searchParams.toString());
      if (vals.length === 0) params.delete("sucursal");
      else params.set("sucursal", vals.join(","));
      router.replace(`${pathname}?${params.toString()}`, { scroll: false });
    },
    [pathname, router, searchParams],
  );

  const handleMarcaChange = useCallback(
    (vals: string[]) => {
      const params = new URLSearchParams(searchParams.toString());
      if (vals.length === 0) params.delete("marca");
      else params.set("marca", vals.join(","));
      router.replace(`${pathname}?${params.toString()}`, { scroll: false });
    },
    [pathname, router, searchParams],
  );

  const handleGrupoChange = useCallback(
    (vals: string[]) => {
      const params = new URLSearchParams(searchParams.toString());
      if (vals.length === 0) params.delete("grupo");
      else params.set("grupo", vals.join(","));
      router.replace(`${pathname}?${params.toString()}`, { scroll: false });
    },
    [pathname, router, searchParams],
  );

  const sucursalOptions = sucursales.map((s) => ({
    value: String(s.id_sucursal),
    label: s.nombre_sucursal,
  }));

  const marcaOptions = marcas.map((m) => ({ value: m, label: m }));
  const grupoOptions = grupos.map((g) => ({ value: g, label: g }));

  return (
    <div className="flex w-full items-center gap-2 overflow-x-auto pb-0.5 xl:overflow-visible xl:flex-nowrap md:w-auto">

      {/* ── Permanentes: siempre visibles en cualquier ruta de /dashboard ── */}
      <div className="shrink-0 w-full sm:w-auto">
        <DateRangePicker value={localDateRange} onChange={handleDateChange} />
      </div>

      <div className="shrink-0 min-w-[150px] md:min-w-[180px] xl:min-w-[220px]">
        <MultiSelectFilter
          options={sucursalOptions}
          selected={sucursalesSelected}
          onChange={handleSucursalChange}
          placeholder="Todas las sucursales"
          icon={<MapPin className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />}
        />
      </div>

      {/* ── Dinámicos: solo en /dashboard/inventario, carga lazy ─────────── */}
      {isInventario && marcas.length > 0 && (
        <div className="shrink-0 min-w-[130px] md:min-w-[150px] xl:min-w-[180px]">
          <MultiSelectFilter
            options={marcaOptions}
            selected={marcasSelected}
            onChange={handleMarcaChange}
            placeholder="Todas las marcas"
            icon={<Tag className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />}
          />
        </div>
      )}

      {isInventario && grupos.length > 0 && (
        <div className="shrink-0 min-w-[130px] md:min-w-[150px] xl:min-w-[180px]">
          <MultiSelectFilter
            options={grupoOptions}
            selected={gruposSelected}
            onChange={handleGrupoChange}
            placeholder="Todos los grupos"
            icon={<Layers className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />}
          />
        </div>
      )}
    </div>
  );
}
