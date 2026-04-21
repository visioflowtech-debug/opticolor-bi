"use client";
import * as React from "react";

import { ChartBar, Forklift, Gauge, GraduationCap, Search, ShoppingBag } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from "@/components/ui/command";

interface SearchItem {
  group: string;
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  href: string;
}

const searchItems: SearchItem[] = [
  { group: "Informes", icon: ChartBar, label: "Resumen Comercial", href: "/dashboard/resumen-comercial" },
  { group: "Informes", icon: Gauge, label: "Eficiencia de Órdenes", href: "/dashboard/eficiencia-ordenes" },
  { group: "Informes", icon: ShoppingBag, label: "Control de Cartera", href: "/dashboard/control-cartera" },
  { group: "Informes", icon: GraduationCap, label: "Desempeño Clínico", href: "/dashboard/desempenio-clinico" },
  { group: "Informes", icon: Forklift, label: "Inventario", href: "/dashboard/inventario" },
];

export function SearchDialog() {
  const [open, setOpen] = React.useState(false);
  const groups = [...new Set(searchItems.map((item) => item.group))];

  React.useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "j" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((open) => !open);
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  return (
    <>
      <Button
        onClick={() => setOpen(true)}
        variant="link"
        className="px-0! font-normal text-muted-foreground hover:no-underline"
      >
        <Search data-icon="inline-start" />
        Buscar
        <kbd className="inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-medium text-[10px]">
          <span className="text-xs">⌘</span>J
        </kbd>
      </Button>
      <CommandDialog open={open} onOpenChange={setOpen}>
        <Command>
          <CommandInput placeholder="Buscar informes…" />
          <CommandList>
            <CommandEmpty>No se encontraron resultados.</CommandEmpty>
            {groups.map((group, index) => (
              <React.Fragment key={group}>
                {index > 0 && <CommandSeparator />}
                <CommandGroup heading={group}>
                  {searchItems
                    .filter((item) => item.group === group)
                    .map((item) => (
                      <CommandItem
                        key={item.label}
                        onSelect={() => {
                          window.location.href = item.href;
                          setOpen(false);
                        }}
                      >
                        {item.icon && <item.icon />}
                        <span>{item.label}</span>
                      </CommandItem>
                    ))}
                </CommandGroup>
              </React.Fragment>
            ))}
          </CommandList>
        </Command>
      </CommandDialog>
    </>
  );
}
