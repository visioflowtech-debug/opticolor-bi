import { NextRequest, NextResponse } from 'next/server';
import { auth } from '../../config/auth';
import { ControlCarteraRow, ApiResponse } from '../../lib/types';

const mockData: ControlCarteraRow[] = [
  {
    fecha: '2026-04-01',
    facturado: 250000,
    recaudado: 220000,
    saldo: 30000,
    cartera_dias: 12,
  },
  {
    fecha: '2026-04-02',
    facturado: 382000,
    recaudado: 335000,
    saldo: 47000,
    cartera_dias: 11,
  },
  {
    fecha: '2026-04-03',
    facturado: 256000,
    recaudado: 224000,
    saldo: 32000,
    cartera_dias: 12,
  },
  {
    fecha: '2026-04-04',
    facturado: 270000,
    recaudado: 236000,
    saldo: 34000,
    cartera_dias: 13,
  },
  {
    fecha: '2026-04-05',
    facturado: 287000,
    recaudado: 253000,
    saldo: 34000,
    cartera_dias: 12,
  },
  {
    fecha: '2026-04-06',
    facturado: 276000,
    recaudado: 242000,
    saldo: 34000,
    cartera_dias: 12,
  },
  {
    fecha: '2026-04-07',
    facturado: 290000,
    recaudado: 256000,
    saldo: 34000,
    cartera_dias: 11,
  },
];

export async function GET(request: NextRequest): Promise<NextResponse<ApiResponse<ControlCarteraRow[]>>> {
  try {
    const session = await auth();

    if (!session?.user) {
      return NextResponse.json(
        { success: false, error: 'No autenticado' },
        { status: 401 }
      );
    }

    // TODO: Semana 2.2
    // const data = await query<ControlCarteraRow>(`
    //   SELECT
    //     CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE) AS fecha,
    //     SUM(monto_facturado) AS facturado,
    //     SUM(monto_recaudado) AS recaudado,
    //     SUM(monto_facturado - monto_recaudado) AS saldo,
    //     CAST(AVG(dias_cartera) AS DECIMAL(5,2)) AS cartera_dias
    //   FROM [dbo].[Fact_Cartera]
    //   WHERE id_sucursal IN (SELECT id_sucursal FROM [dbo].[Vw_RLS_Sucursales] WHERE email = @email)
    //   GROUP BY CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE)
    //   ORDER BY fecha DESC
    // `, { email: session.user.email })

    return NextResponse.json(
      {
        success: true,
        data: mockData,
        message: 'Datos de control de cartera (MOCK)',
      },
      { status: 200 }
    );
  } catch (error) {
    console.error('[API] Error en /api/data/control-cartera:', error);
    return NextResponse.json(
      {
        success: false,
        error: 'Error obteniendo datos',
      },
      { status: 500 }
    );
  }
}
