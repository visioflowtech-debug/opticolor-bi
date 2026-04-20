import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/config/auth';
import { DesempenioClinicoRow, ApiResponse } from '@/lib/types';

const mockData: DesempenioClinicoRow[] = [
  {
    fecha: '2026-04-01',
    examenes_realizados: 125,
    venta_realizadas: 98,
    tasa_conversion: 78.4,
    productividad_examinador: 8.9,
  },
  {
    fecha: '2026-04-02',
    examenes_realizados: 142,
    venta_realizadas: 115,
    tasa_conversion: 81.0,
    productividad_examinador: 9.5,
  },
  {
    fecha: '2026-04-03',
    examenes_realizados: 138,
    venta_realizadas: 107,
    tasa_conversion: 77.5,
    productividad_examinador: 9.1,
  },
  {
    fecha: '2026-04-04',
    examenes_realizados: 155,
    venta_realizadas: 128,
    tasa_conversion: 82.6,
    productividad_examinador: 9.8,
  },
  {
    fecha: '2026-04-05',
    examenes_realizados: 168,
    venta_realizadas: 142,
    tasa_conversion: 84.5,
    productividad_examinador: 10.2,
  },
  {
    fecha: '2026-04-06',
    examenes_realizados: 145,
    venta_realizadas: 119,
    tasa_conversion: 82.1,
    productividad_examinador: 9.6,
  },
  {
    fecha: '2026-04-07',
    examenes_realizados: 175,
    venta_realizadas: 151,
    tasa_conversion: 86.3,
    productividad_examinador: 10.5,
  },
];

export async function GET(request: NextRequest): Promise<NextResponse<ApiResponse<DesempenioClinicoRow[]>>> {
  try {
    const session = await auth();

    if (!session?.user) {
      return NextResponse.json(
        { success: false, error: 'No autenticado' },
        { status: 401 }
      );
    }

    // TODO: Semana 2.2
    // const data = await query<DesempenioClinicoRow>(`
    //   SELECT
    //     CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE) AS fecha,
    //     COUNT(DISTINCT id_examen) AS examenes_realizados,
    //     COUNT(DISTINCT CASE WHEN venta_realizada = 1 THEN id_examen END) AS venta_realizadas,
    //     CAST(COUNT(DISTINCT CASE WHEN venta_realizada = 1 THEN id_examen END) * 100.0 / COUNT(DISTINCT id_examen) AS DECIMAL(5,2)) AS tasa_conversion,
    //     CAST(COUNT(DISTINCT id_venta) * 1.0 / COUNT(DISTINCT id_examinador) AS DECIMAL(5,2)) AS productividad_examinador
    //   FROM [dbo].[Fact_Clinica]
    //   WHERE id_sucursal IN (SELECT id_sucursal FROM [dbo].[Vw_RLS_Sucursales] WHERE email = @email)
    //   GROUP BY CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE)
    //   ORDER BY fecha DESC
    // `, { email: session.user.email })

    return NextResponse.json(
      {
        success: true,
        data: mockData,
        message: 'Datos de desempeño clínico (MOCK)',
      },
      { status: 200 }
    );
  } catch (error) {
    console.error('[API] Error en /api/data/desempenio-clinico:', error);
    return NextResponse.json(
      {
        success: false,
        error: 'Error obteniendo datos',
      },
      { status: 500 }
    );
  }
}
