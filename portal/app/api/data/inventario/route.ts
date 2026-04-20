import { NextRequest, NextResponse } from 'next/server';
import { auth } from '../../config/auth';
import { InventarioRow, ApiResponse } from '../../lib/types';

const mockData: InventarioRow[] = [
  {
    fecha: '2026-04-01',
    stock_total: 15420,
    rotacion_dias: 28,
    obsoletos: 145,
    faltantes: 23,
  },
  {
    fecha: '2026-04-02',
    stock_total: 15280,
    rotacion_dias: 27,
    obsoletos: 152,
    faltantes: 19,
  },
  {
    fecha: '2026-04-03',
    stock_total: 15350,
    rotacion_dias: 28,
    obsoletos: 148,
    faltantes: 21,
  },
  {
    fecha: '2026-04-04',
    stock_total: 15180,
    rotacion_dias: 26,
    obsoletos: 155,
    faltantes: 18,
  },
  {
    fecha: '2026-04-05',
    stock_total: 15420,
    rotacion_dias: 27,
    obsoletos: 150,
    faltantes: 20,
  },
  {
    fecha: '2026-04-06',
    stock_total: 15550,
    rotacion_dias: 28,
    obsoletos: 145,
    faltantes: 22,
  },
  {
    fecha: '2026-04-07',
    stock_total: 15680,
    rotacion_dias: 29,
    obsoletos: 140,
    faltantes: 24,
  },
];

export async function GET(request: NextRequest): Promise<NextResponse<ApiResponse<InventarioRow[]>>> {
  try {
    const session = await auth();

    if (!session?.user) {
      return NextResponse.json(
        { success: false, error: 'No autenticado' },
        { status: 401 }
      );
    }

    // TODO: Semana 2.2
    // const data = await query<InventarioRow>(`
    //   SELECT
    //     CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE) AS fecha,
    //     SUM(cantidad) AS stock_total,
    //     CAST(AVG(dias_en_almacen) AS DECIMAL(5,2)) AS rotacion_dias,
    //     SUM(CASE WHEN dias_en_almacen > 180 THEN cantidad ELSE 0 END) AS obsoletos,
    //     COUNT(DISTINCT id_producto) FILTER (WHERE cantidad <= stock_minimo) AS faltantes
    //   FROM [dbo].[Fact_Inventario]
    //   WHERE id_sucursal IN (SELECT id_sucursal FROM [dbo].[Vw_RLS_Sucursales] WHERE email = @email)
    //   GROUP BY CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE)
    //   ORDER BY fecha DESC
    // `, { email: session.user.email })

    return NextResponse.json(
      {
        success: true,
        data: mockData,
        message: 'Datos de inventario (MOCK)',
      },
      { status: 200 }
    );
  } catch (error) {
    console.error('[API] Error en /api/data/inventario:', error);
    return NextResponse.json(
      {
        success: false,
        error: 'Error obteniendo datos',
      },
      { status: 500 }
    );
  }
}
