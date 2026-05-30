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
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Search } from "lucide-react";
import { formatCurrency } from "@/lib/utils";
import type { ClienteDeudor } from "../_actions/get-cartera-data";

interface Props {
  data: ClienteDeudor[];
}

export function ClientesDeudoresTable({ data }: Props) {
  const [currentPage, setCurrentPage] = useState(1);
  const [searchQuery, setSearchQuery] = useState("");
  const itemsPerPage = 10;

  if (!data.length) {
    return (
      <div className="flex h-32 items-center justify-center text-sm text-muted-foreground border rounded-xl bg-card">
        No hay clientes deudores en el período seleccionado
      </div>
    );
  }

  // Filtrado reactivo en tiempo real
  const filteredData = data.filter((item) =>
    item.nombre_completo.toLowerCase().includes(searchQuery.toLowerCase()) ||
    item.nombre_sucursal.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const totales = filteredData.reduce(
    (acc, c) => ({
      monto_total: acc.monto_total + c.monto_total,
      monto_pagado: acc.monto_pagado + c.monto_pagado,
      saldo_pendiente: acc.saldo_pendiente + c.saldo_pendiente,
    }),
    { monto_total: 0, monto_pagado: 0, saldo_pendiente: 0 }
  );

  // Paginación
  const totalPages = Math.max(1, Math.ceil(filteredData.length / itemsPerPage));
  const startIndex = (currentPage - 1) * itemsPerPage;
  const displayData = filteredData.slice(startIndex, startIndex + itemsPerPage);

  return (
    <div className="w-full space-y-4">
      {/* Barra de búsqueda y conteo responsiva */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
          Clientes con Saldo Pendiente ({filteredData.length})
        </div>
        <div className="relative w-full max-w-xs sm:ml-auto">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            type="text"
            placeholder="Buscar cliente..."
            className="pl-8 h-9 text-xs"
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              setCurrentPage(1); // RESETEO CRÍTICO: Regresar a la página 1 al filtrar datos
            }}
          />
        </div>
      </div>

      {filteredData.length === 0 ? (
        <div className="flex h-32 items-center justify-center text-sm text-muted-foreground border rounded-xl bg-card">
          No se encontraron clientes que coincidan con la búsqueda
        </div>
      ) : (
        <>
          <div className="w-full overflow-x-auto pb-2">
            <Table className="min-w-[700px]">
              <TableHeader>
                <TableRow className="bg-muted/50 hover:bg-muted/50">
                  <TableHead className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider h-8">Sucursal</TableHead>
                  <TableHead className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider h-8">Cliente</TableHead>
                  <TableHead className="text-right text-[11px] font-semibold text-muted-foreground uppercase tracking-wider h-8">Monto Órdenes</TableHead>
                  <TableHead className="text-right text-[11px] font-semibold text-muted-foreground uppercase tracking-wider h-8">Recaudado</TableHead>
                  <TableHead className="text-right text-[11px] font-semibold text-muted-foreground uppercase tracking-wider h-8">Saldo Pendiente</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {displayData.map((cliente) => {
                  const pctPagado = cliente.monto_total > 0
                    ? (cliente.monto_pagado / cliente.monto_total) * 100
                    : 0;

                  return (
                    <TableRow
                      key={`${cliente.nombre_sucursal}-${cliente.nombre_completo}`}
                      className="group transition-colors"
                    >
                      <TableCell className="text-xs font-medium text-foreground max-w-[150px] sm:max-w-none truncate py-2">
                        {cliente.nombre_sucursal}
                      </TableCell>
                      <TableCell className="text-xs font-medium text-foreground max-w-[150px] sm:max-w-none truncate py-2">
                        {cliente.nombre_completo}
                      </TableCell>
                      <TableCell className="text-right text-xs font-medium text-foreground whitespace-nowrap py-2">
                        {formatCurrency(cliente.monto_total)}
                      </TableCell>
                      <TableCell className="text-right text-xs font-medium text-foreground whitespace-nowrap py-2">
                        <TooltipProvider>
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <span className="cursor-default underline decoration-dashed decoration-muted-foreground/40 underline-offset-4">
                                {formatCurrency(cliente.monto_pagado)}
                              </span>
                            </TooltipTrigger>
                            <TooltipContent>
                              {pctPagado.toFixed(1)}% del total
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      </TableCell>
                      <TableCell className="text-right text-xs font-medium text-destructive whitespace-nowrap py-2">
                        {formatCurrency(cliente.saldo_pendiente)}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
              <TableFooter>
                <TableRow className="bg-muted/30 font-semibold">
                  <TableCell colSpan={2} className="text-xs uppercase tracking-wider text-muted-foreground">
                    Total General ({filteredData.length} Clientes)
                  </TableCell>
                  <TableCell className="text-right text-xs font-bold text-foreground whitespace-nowrap py-2">
                    {formatCurrency(totales.monto_total)}
                  </TableCell>
                  <TableCell className="text-right text-xs font-bold text-foreground whitespace-nowrap py-2">
                    {formatCurrency(totales.monto_pagado)}
                  </TableCell>
                  <TableCell className="text-right text-xs font-bold text-destructive whitespace-nowrap py-2">
                    {formatCurrency(totales.saldo_pendiente)}
                  </TableCell>
                </TableRow>
              </TableFooter>
            </Table>
          </div>

          {/* Controles de paginación */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-4 py-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setCurrentPage((prev) => Math.max(1, prev - 1))}
                disabled={currentPage === 1}
                className="text-xs"
              >
                Anterior
              </Button>
              <div className="flex items-center text-xs font-medium text-muted-foreground">
                <span>Página</span>
                <Input
                  type="number"
                  min={1}
                  max={totalPages}
                  value={currentPage}
                  onChange={(e) => {
                    const val = Number(e.target.value);
                    if (!isNaN(val) && val >= 1 && val <= totalPages) {
                      setCurrentPage(val);
                    }
                  }}
                  className="w-12 h-8 text-center p-0 text-sm mx-1 rounded-md"
                />
                <span>de {totalPages}</span>
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setCurrentPage((prev) => Math.min(totalPages, prev + 1))}
                disabled={currentPage === totalPages}
                className="text-xs"
              >
                Siguiente
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
