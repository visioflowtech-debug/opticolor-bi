"use client";

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

interface Props {
  data: TipoLenteDetalle[];
}

export function DetalleCristalesTable({ data }: Props) {
  if (!data.length) {
    return (
      <div className="flex h-32 items-center justify-center text-sm text-muted-foreground border rounded-xl bg-card">
        No hay datos de cristales en el período seleccionado
      </div>
    );
  }

  const sortedData = [...data].sort((a, b) => b.volumen_ordenes - a.volumen_ordenes);

  const totales = sortedData.reduce(
    (acc, item) => ({
      volumen_ordenes: acc.volumen_ordenes + item.volumen_ordenes,
      monto_total:     acc.monto_total     + item.monto_total,
    }),
    { volumen_ordenes: 0, monto_total: 0 }
  );

  return (
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
          {sortedData.map((item) => (
            <TableRow key={item.tipo_lente_descripcion} className="group transition-colors">
              <TableCell className="font-medium text-sm text-muted-foreground">
                {item.tipo_lente_descripcion}
              </TableCell>
              <TableCell className="text-right tabular-nums text-sm font-semibold">
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
        </TableFooter>
      </Table>
    </div>
  );
}
