import { NextRequest, NextResponse } from "next/server";
import { revalidateTag } from "next/cache";

// Diccionario que mapea los módulos core con sus respectivas etiquetas de caché (tags)
// físicas que se configuran en unstable_cache a lo largo del portal.
const TAGS_MAP: Record<string, string[]> = {
  ventas: [
    "ventas",
    "dash-ventas-kpis",
    "dash-ventas-diarias",
    "dash-ventas-top-sucursales",
    "dash-ventas-medios-pago",
  ],
  inventario: [
    "inventario",
    "dash-inventario-kpis",
    "dash-inventario-marcas",
    "dash-inventario-grupos-mix",
    "dash-inventario-dispersion",
    "marcas-grupos-inventory",
  ],
  clinico: [
    "clinico",
    "dash-clinico-kpis",
    "dash-clinico-tendencia",
    "dash-clinico-volumen-conversion",
    "dash-clinico-genero",
    "dash-clinico-edad",
    "dash-clinico-top-sucursales",
  ],
  recaudo: [
    "recaudo",
    "dash-cartera-kpis",
    "dash-cartera-gap-cobro",
    "dash-cartera-mix-ventas",
    "dash-cartera-sucursal",
    "dash-cartera-clientes-deudores",
  ],
  eficiencia: [
    "eficiencia",
    "dash-eficiencia-kpis",
    "dash-eficiencia-tendencia",
    "dash-eficiencia-tipo-lente",
    "dash-eficiencia-ordenes-sucursal",
  ],
};

export async function POST(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const secret = searchParams.get("secret");

  // Validación de seguridad para evitar ataques de invalidación masiva
  if (!secret || secret !== process.env.REVALIDATE_SECRET_TOKEN) {
    return NextResponse.json(
      { message: "Token de seguridad inválido" },
      { status: 401 }
    );
  }

  try {
    const revalidatedTags: string[] = [];

    // Purgar de golpe las 5 capas de caché de datos resumidos
    // llamando a los 5 tags solicitados explícitamente y sus respectivos sub-tags
    const categories = ["ventas", "inventario", "clinico", "recaudo", "eficiencia"];

    for (const category of categories) {
      const tagsToPurge = TAGS_MAP[category];
      if (tagsToPurge) {
        for (const tag of tagsToPurge) {
          revalidateTag(tag, "max");
          revalidatedTags.push(tag);
        }
      }
    }

    return NextResponse.json({
      revalidated: true,
      now: Date.now(),
      message: "Caché global de reportes purgado con éxito",
      purgedTags: revalidatedTags,
    });
  } catch (error) {
    console.error("[ERROR][REVALIDATE_ROUTE]", error);
    return NextResponse.json(
      { message: "Falla interna al purgar caché" },
      { status: 500 }
    );
  }
}
