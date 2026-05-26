"use client";

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatBsCurrency } from "@/lib/utils";
import type { MarcaItem } from "../_actions/get-inventario-data";


interface Props {
  data: MarcaItem[];
}

export function DetalleTable({ data }: Props) {
  if (!data.length) {
    return (
      <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">
        Sin datos para el período seleccionado
      </div>
    );
  }

  return (
    <div className="w-full overflow-x-auto pb-2">
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
          {data.map((item) => (
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
      </Table>
    </div>
  );
}
