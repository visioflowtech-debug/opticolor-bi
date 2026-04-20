import { NextRequest, NextResponse } from 'next/server';
import { auth } from '../../../config/auth';
import { DesempenioClinicoRow, ApiResponse } from '../../../lib/types';

const mockData: DesempenioClinicoRow[] = [
  {
    fecha: '2026-04-01',
    total_examenes: 125,
    pacientes_con_compra: 98,
    tasa_conversion: 78.4,
    venta_promedio_paciente: 8.9,
  },
  {
    fecha: '2026-04-02',
    total_examenes: 142,
    pacientes_con_compra: 115,
    tasa_conversion: 81.0,
    venta_promedio_paciente: 9.5,
  },
  {
    fecha: '2026-04-03',
    total_examenes: 138,
    pacientes_con_compra: 107,
    tasa_conversion: 77.5,
    venta_promedio_paciente: 9.1,
  },
  {
    fecha: '2026-04-04',
    total_examenes: 155,
    pacientes_con_compra: 128,
    tasa_conversion: 82.6,
    venta_promedio_paciente: 9.8,
  },
  {
    fecha: '2026-04-05',
    total_examenes: 168,
    pacientes_con_compra: 142,
    tasa_conversion: 84.5,
    venta_promedio_paciente: 10.2,
  },
  {
    fecha: '2026-04-06',
    total_examenes: 145,
    pacientes_con_compra: 119,
    tasa_conversion: 82.1,
    venta_promedio_paciente: 9.6,
  },
  {
    fecha: '2026-04-07',
    total_examenes: 175,
    pacientes_con_compra: 151,
    tasa_conversion: 86.3,
    venta_promedio_paciente: 10.5,
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
    //     COUNT(DISTINCT id_examen) AS total_examenes,
    //     COUNT(DISTINCT CASE WHEN venta_realizada = 1 THEN id_examen END) AS pacientes_con_compra,
    //     CAST(COUNT(DISTINCT CASE WHEN venta_realizada = 1 THEN id_examen END) * 100.0 / COUNT(DISTINCT id_examen) AS DECIMAL(5,2)) AS tasa_conversion,
    //     CAST(COUNT(DISTINCT id_venta) * 1.0 / COUNT(DISTINCT id_examinador) AS DECIMAL(5,2)) AS venta_promedio_paciente
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
