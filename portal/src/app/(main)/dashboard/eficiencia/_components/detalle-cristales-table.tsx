"use client";

import { useState } from "react";
import {
  Table,
  TableBody,
  TableCell,
  TableFooter,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatCurrency } from "@/lib/utils";
import type { TipoLenteDetalle } from "../_actions/get-eficiencia-data";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Search } from "lucide-react";

interface Props {
  data: TipoLenteDetalle[];
  error?: string | null;
}

export function DetalleCristalesTable({ data, error }: Props) {
  const [searchQuery, setSearchQuery] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  // Si no hay datos y no se ha buscado nada
  if (!data.length && !searchQuery) {
    return (
      <div className="flex h-32 items-center justify-center text-sm text-muted-foreground border rounded-xl bg-card">
        No hay datos de cristales en el período seleccionado
      </div>
    );
  }

  // Ordenar datos
  const sortedData = [...data].sort((a, b) => b.volumen_ordenes - a.volumen_ordenes);

  // Filtrar por descripción
  const filteredData = sortedData.filter((item) =>
    item.tipo_lente_descripcion.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Totales basados en datos filtrados
  const totales = filteredData.reduce(
    (acc, item) => ({
      volumen_ordenes: acc.volumen_ordenes + item.volumen_ordenes,
      monto_total: acc.monto_total + item.monto_total,
    }),
    { volumen_ordenes: 0, monto_total: 0 }
  );

  // Paginación
  const totalPages = Math.ceil(filteredData.length / itemsPerPage);
  const paginatedData = filteredData.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <CardTitle className="text-sm font-semibold text-muted-foreground">
          Detalle de Órdenes de Cristales por Tipo
        </CardTitle>
        <div className="relative w-full max-w-xs sm:ml-auto">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            type="text"
            placeholder="Buscar cristal..."
            className="pl-8 h-9 text-xs"
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              setCurrentPage(1); // Reseteo de página al filtrar
            }}
          />
        </div>
      </CardHeader>
      <CardContent>
        {error && (
          <div className="text-sm text-destructive pb-2">{error}</div>
        )}

        {filteredData.length === 0 ? (
          <div className="flex h-32 items-center justify-center text-sm text-muted-foreground border rounded-xl bg-card">
            No se encontraron cristales para "{searchQuery}"
          </div>
        ) : (
          <div className="w-full overflow-x-auto pb-2">
            <Table className="min-w-[520px]">
              <TableHeader>
                <TableRow className="bg-muted/50 hover:bg-muted/50">
                  <TableHead className="font-semibold text-xs uppercase tracking-wider">Tipo de Lente</TableHead>
                  <TableHead className="text-right font-semibold text-xs uppercase tracking-wider">Volumen de Órdenes</TableHead>
                  <TableHead className="text-right font-semibold text-xs uppercase tracking-wider">Monto Total</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {paginatedData.map((item) => (
                  <TableRow key={item.tipo_lente_descripcion} className="group transition-colors">
                    <TableCell className="font-medium text-sm text-muted-foreground">
                      {item.tipo_lente_descripcion}
                    </TableCell>
                    <TableCell className="text-right tabular-nums text-sm">
                      {new Intl.NumberFormat("en-US").format(item.volumen_ordenes)}
                    </TableCell>
                    <TableCell className="text-right tabular-nums text-sm">
                      {formatCurrency(item.monto_total)}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
              <TableFooter>
                <TableRow className="bg-muted/30 font-semibold">
                  <TableCell className="text-xs uppercase tracking-wider text-muted-foreground">
                    Total
                  </TableCell>
                  <TableCell className="text-right tabular-nums text-sm">
                    {new Intl.NumberFormat("en-US").format(totales.volumen_ordenes)}
                  </TableCell>
                  <TableCell className="text-right tabular-nums text-sm">
                    {formatCurrency(totales.monto_total)}
                  </TableCell>
                </TableRow>

                {/* Paginación */}
                <TableRow className="bg-background hover:bg-background border-t">
                  <TableCell colSpan={3}>
                    <div className="flex flex-col sm:flex-row items-center justify-between py-2 px-1 w-full gap-3">
                      <span className="text-xs text-muted-foreground">
                        Página {currentPage} de {totalPages || 1} ({filteredData.length} resultados)
                      </span>
                      <div className="flex items-center gap-1 select-none">
                        <Button
                          variant="outline"
                          size="sm"
                          className="h-8 text-xs font-medium"
                          onClick={() => setCurrentPage((prev) => Math.max(prev - 1, 1))}
                          disabled={currentPage === 1}
                        >
                          Anterior
                        </Button>

                        <span className="text-xs text-muted-foreground px-1">Ir a:</span>
                        <input
                          type="number"
                          min={1}
                          max={totalPages || 1}
                          value={currentPage}
                          onChange={(e) => {
                            const val = parseInt(e.target.value, 10);
                            if (!isNaN(val)) {
                              setCurrentPage(Math.min(Math.max(val, 1), totalPages || 1));
                            }
                          }}
                          className="w-12 h-8 text-center p-0 text-sm mx-1 rounded-md border border-slate-200"
                        />

                        <Button
                          variant="outline"
                          size="sm"
                          className="h-8 text-xs font-medium"
                          onClick={() => setCurrentPage((prev) => Math.min(prev + 1, totalPages || 1))}
                          disabled={currentPage === totalPages || totalPages === 0}
                        >
                          Siguiente
                        </Button>
                      </div>
                    </div>
                  </TableCell>
                </TableRow>
              </TableFooter>
            </Table>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
