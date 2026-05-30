"use client";

import { useState } from "react";
import { Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  TableFooter,
} from "@/components/ui/table";
import { formatBsCurrency } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";
import type { MarcaItem } from "../_actions/get-inventario-data";

interface Props {
  data: MarcaItem[];
  error?: string;
}

export function DetalleTable({ data, error }: Props) {
  const isMobile = useIsMobile();
  const [searchQuery, setSearchQuery] = useState("");
  const [currentPage, setCurrentPage] = useState<number | string>(1);
  const itemsPerPage = 10;

  // 1. Filtrar registros reactivamente por marca
  const filteredData = data.filter((item) =>
    item.marca.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // 2. Calcular los totales basados exclusivamente en el conjunto filtrado
  const totalUnidades = filteredData.reduce((sum, item) => sum + item.unidadesVendidas, 0);
  const totalStock = filteredData.reduce((sum, item) => sum + item.stockFisico, 0);
  const totalVentaNeta = filteredData.reduce((sum, item) => sum + item.ventaNeta, 0);

  // 3. Paginación
  const totalPages = Math.max(1, Math.ceil(filteredData.length / itemsPerPage));
  const activePage = typeof currentPage === "number" ? Math.min(currentPage, totalPages) : 1;
  
  const paginatedData = filteredData.slice(
    (activePage - 1) * itemsPerPage,
    activePage * itemsPerPage
  );

  return (
    <Card className="w-full h-auto flex flex-col justify-between min-w-0 overflow-hidden rounded-2xl shadow-md border border-slate-100 dark:border-slate-800 bg-white dark:bg-slate-900">
      <CardHeader className="shrink-0 pb-3 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Detalle por Marca
        </CardTitle>
        <div className="relative w-full sm:w-60">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            type="search"
            placeholder="Buscar marca..."
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              setCurrentPage(1); // Reset page on search
            }}
            className="pl-8 h-9 text-xs"
          />
        </div>
      </CardHeader>
      
      <CardContent className="min-h-0 flex-1 flex flex-col justify-between px-6 py-0 pb-4">
        <div className="min-h-0 flex-1 flex flex-col">
          {error && (
            <div className="text-sm text-destructive pb-2 px-1">{error}</div>
          )}

          {!filteredData.length ? (
            <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">
              Sin datos para el período seleccionado
            </div>
          ) : (
            <div className="w-full overflow-x-auto h-auto min-h-0 pb-2">
              <Table className="min-w-[480px]">
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="text-xs font-semibold uppercase tracking-wide">
                      Marca
                    </TableHead>
                    <TableHead className="text-right text-xs font-semibold uppercase tracking-wide">
                      Und. Vendidas
                    </TableHead>
                    <TableHead className="text-right text-xs font-semibold uppercase tracking-wide">
                      Stock Físico
                    </TableHead>
                    <TableHead className="text-right text-xs font-semibold uppercase tracking-wide">
                      Venta Neta
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {paginatedData.map((item) => (
                    <TableRow key={item.marca} className="text-xs">
                      <TableCell className="font-medium">{item.marca}</TableCell>
                      <TableCell className="text-right tabular-nums">
                        {item.unidadesVendidas.toLocaleString("en-US")}
                      </TableCell>
                      <TableCell className="text-right tabular-nums text-muted-foreground">
                        {item.stockFisico.toLocaleString("en-US")}
                      </TableCell>
                      <TableCell
                        className="text-right tabular-nums font-medium"
                        title={formatBsCurrency(item.ventaNeta)}
                      >
                        {formatBsCurrency(item.ventaNeta)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
                <TableFooter>
                  <TableRow className="hover:bg-transparent font-semibold">
                    <TableCell className="text-xs uppercase">Total Filtrado</TableCell>
                    <TableCell className="text-right text-xs tabular-nums">
                      {totalUnidades.toLocaleString("en-US")}
                    </TableCell>
                    <TableCell className="text-right text-xs tabular-nums text-muted-foreground">
                      {totalStock.toLocaleString("en-US")}
                    </TableCell>
                    <TableCell className="text-right text-xs tabular-nums font-semibold">
                      {formatBsCurrency(totalVentaNeta)}
                    </TableCell>
                  </TableRow>
                </TableFooter>
              </Table>
            </div>
          )}
        </div>

        {/* Footer de Paginación */}
        {filteredData.length > 0 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-4 border-t border-slate-100 dark:border-slate-800 shrink-0">
            <div className="text-xs text-muted-foreground">
              Mostrando {(activePage - 1) * itemsPerPage + 1} a {Math.min(activePage * itemsPerPage, filteredData.length)} de {filteredData.length} marcas
            </div>
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setCurrentPage(Math.max(1, activePage - 1))}
                disabled={activePage === 1}
                className="h-8 text-xs px-3"
              >
                Anterior
              </Button>
              <div className="flex items-center text-xs text-muted-foreground font-medium">
                Pág.
                <input
                  type="number"
                  min={1}
                  max={totalPages}
                  value={currentPage}
                  onChange={(e) => {
                    const val = parseInt(e.target.value, 10);
                    if (!isNaN(val)) {
                      setCurrentPage(Math.max(1, Math.min(val, totalPages)));
                    } else {
                      setCurrentPage("");
                    }
                  }}
                  onBlur={() => {
                    if (currentPage === "" || isNaN(Number(currentPage))) {
                      setCurrentPage(activePage);
                    }
                  }}
                  className="w-12 h-8 text-center p-0 text-sm mx-1 rounded-md border-slate-200 border bg-background text-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                />
                de {totalPages}
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setCurrentPage(Math.min(totalPages, activePage + 1))}
                disabled={activePage === totalPages}
                className="h-8 text-xs px-3"
              >
                Siguiente
              </Button>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
