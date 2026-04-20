import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/config/auth';
import { ResumenComercialRow, ApiResponse } from '@/lib/types';

// Mock data - será reemplazado por queries SQL reales en Semana 2.2
const mockData: ResumenComercialRow[] = [
  {
    fecha: '2026-04-01',
    venta_total: 125000,
    cobrado: 110000,
    ticket_promedio: 850,
    run_rate: 98.5,
    otif: 96.2,
  },
  {
    fecha: '2026-04-02',
    venta_total: 132000,
    cobrado: 115000,
    ticket_promedio: 870,
    run_rate: 99.1,
    otif: 97.1,
  },
  {
    fecha: '2026-04-03',
    venta_total: 128000,
    cobrado: 112000,
    ticket_promedio: 860,
    run_rate: 98.8,
    otif: 96.8,
  },
  {
    fecha: '2026-04-04',
    venta_total: 135000,
    cobrado: 118000,
    ticket_promedio: 890,
    run_rate: 99.3,
    otif: 97.5,
  },
  {
    fecha: '2026-04-05',
    venta_total: 142000,
    cobrado: 125000,
    ticket_promedio: 920,
    run_rate: 99.5,
    otif: 98.1,
  },
  {
    fecha: '2026-04-06',
    venta_total: 138000,
    cobrado: 121000,
    ticket_promedio: 905,
    run_rate: 99.2,
    otif: 97.8,
  },
  {
    fecha: '2026-04-07',
    venta_total: 145000,
    cobrado: 128000,
    ticket_promedio: 930,
    run_rate: 99.6,
    otif: 98.3,
  },
];

export async function GET(request: NextRequest): Promise<NextResponse<ApiResponse<ResumenComercialRow[]>>> {
  try {
    const session = await auth();

    if (!session?.user) {
      return NextResponse.json(
        { success: false, error: 'No autenticado' },
        { status: 401 }
      );
    }

    // TODO: Semana 2.2 - Reemplazar con query SQL real
    // const data = await query<ResumenComercialRow>(`
    //   SELECT
    //     CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE) AS fecha,
    //     SUM(monto_total) AS venta_total,
    //     SUM(monto_cobrado) AS cobrado,
    //     AVG(monto_total) AS ticket_promedio,
    //     AVG(run_rate) AS run_rate,
    //     AVG(otif) AS otif
    //   FROM [dbo].[Fact_Ventas]
    //   WHERE id_sucursal IN (SELECT id_sucursal FROM [dbo].[Vw_RLS_Sucursales] WHERE email = @email)
    //   GROUP BY CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE)
    //   ORDER BY fecha DESC
    // `, { email: session.user.email })

    return NextResponse.json(
      {
        success: true,
        data: mockData,
        message: 'Datos de resumen comercial (MOCK - Semana 2.2 datos reales)',
      },
      { status: 200 }
    );
  } catch (error) {
    console.error('[API] Error en /api/data/resumen-comercial:', error);
    return NextResponse.json(
      {
        success: false,
        error: 'Error obteniendo datos',
      },
      { status: 500 }
    );
  }
}
