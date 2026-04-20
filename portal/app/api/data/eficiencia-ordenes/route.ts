import { NextRequest, NextResponse } from 'next/server';
import { auth } from '../../../config/auth';
import { EficienciaOrdenesRow, ApiResponse } from '../../../lib/types';

const mockData: EficienciaOrdenesRow[] = [
  {
    fecha: '2026-04-01',
    ordenes_total: 45,
    ordenes_proceso: 8,
    dias_promedio_entrega: 3.2,
    cumplimiento_fecha: 94.4,
  },
  {
    fecha: '2026-04-02',
    ordenes_total: 52,
    ordenes_proceso: 10,
    dias_promedio_entrega: 3.0,
    cumplimiento_fecha: 96.2,
  },
  {
    fecha: '2026-04-03',
    ordenes_total: 48,
    ordenes_proceso: 9,
    dias_promedio_entrega: 3.1,
    cumplimiento_fecha: 95.8,
  },
  {
    fecha: '2026-04-04',
    ordenes_total: 55,
    ordenes_proceso: 11,
    dias_promedio_entrega: 3.3,
    cumplimiento_fecha: 93.6,
  },
  {
    fecha: '2026-04-05',
    ordenes_total: 58,
    ordenes_proceso: 7,
    dias_promedio_entrega: 2.9,
    cumplimiento_fecha: 98.3,
  },
  {
    fecha: '2026-04-06',
    ordenes_total: 50,
    ordenes_proceso: 8,
    dias_promedio_entrega: 3.0,
    cumplimiento_fecha: 96.0,
  },
  {
    fecha: '2026-04-07',
    ordenes_total: 60,
    ordenes_proceso: 6,
    dias_promedio_entrega: 2.8,
    cumplimiento_fecha: 98.3,
  },
];

export async function GET(request: NextRequest): Promise<NextResponse<ApiResponse<EficienciaOrdenesRow[]>>> {
  try {
    const session = await auth();

    if (!session?.user) {
      return NextResponse.json(
        { success: false, error: 'No autenticado' },
        { status: 401 }
      );
    }

    // TODO: Semana 2.2 - Query SQL real
    // const data = await query<EficienciaOrdenesRow>(`
    //   SELECT
    //     CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE) AS fecha,
    //     COUNT(*) AS ordenes_total,
    //     SUM(CASE WHEN estado = 'EN_PROCESO' THEN 1 ELSE 0 END) AS ordenes_proceso,
    //     AVG(DATEDIFF(DAY, fecha_inicio, fecha_finalizacion)) AS dias_promedio_entrega,
    //     CAST(SUM(CASE WHEN DATEDIFF(DAY, fecha_inicio, fecha_finalizacion) <= dias_plazo THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS cumplimiento_fecha
    //   FROM [dbo].[Fact_Ordenes]
    //   WHERE id_sucursal IN (SELECT id_sucursal FROM [dbo].[Vw_RLS_Sucursales] WHERE email = @email)
    //   GROUP BY CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE)
    //   ORDER BY fecha DESC
    // `, { email: session.user.email })

    return NextResponse.json(
      {
        success: true,
        data: mockData,
        message: 'Datos de eficiencia de órdenes (MOCK)',
      },
      { status: 200 }
    );
  } catch (error) {
    console.error('[API] Error en /api/data/eficiencia-ordenes:', error);
    return NextResponse.json(
      {
        success: false,
        error: 'Error obteniendo datos',
      },
      { status: 500 }
    );
  }
}
