import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/config/auth';
import { ControlCarteraRow, ApiResponse } from '@/lib/types';

const mockData: ControlCarteraRow[] = [
  {
    fecha: '2026-04-01',
    facturado: 250000,
    recaudado: 220000,
    saldo: 30000,
    dias_cartera: 12,
  },
  {
    fecha: '2026-04-02',
    facturado: 382000,
    recaudado: 335000,
    saldo: 47000,
    dias_cartera: 11,
  },
  {
    fecha: '2026-04-03',
    facturado: 256000,
    recaudado: 224000,
    saldo: 32000,
    dias_cartera: 12,
  },
  {
    fecha: '2026-04-04',
    facturado: 270000,
    recaudado: 236000,
    saldo: 34000,
    dias_cartera: 13,
  },
  {
    fecha: '2026-04-05',
    facturado: 287000,
    recaudado: 253000,
    saldo: 34000,
    dias_cartera: 12,
  },
  {
    fecha: '2026-04-06',
    facturado: 276000,
    recaudado: 242000,
    saldo: 34000,
    dias_cartera: 12,
  },
  {
    fecha: '2026-04-07',
    facturado: 290000,
    recaudado: 256000,
    saldo: 34000,
    dias_cartera: 11,
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
