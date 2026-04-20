import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/config/auth';
import { InventarioRow, ApiResponse } from '@/lib/types';

const mockData: InventarioRow[] = [
  {
    nombre_producto: 'Lentes Luxury Pro',
    stock_actual: 450,
    stock_minimo: 100,
    rotacion_dias: 12,
    capital_invertido: 45000,
  },
  {
    nombre_producto: 'Lentes Intermedias Standard',
    stock_actual: 320,
    stock_minimo: 80,
    rotacion_dias: 15,
    capital_invertido: 25600,
  },
  {
    nombre_producto: 'Lentes Be Diferent Colors',
    stock_actual: 280,
    stock_minimo: 60,
    rotacion_dias: 18,
    capital_invertido: 19600,
  },
  {
    nombre_producto: 'Lentes Contacto Soft',
    stock_actual: 1200,
    stock_minimo: 300,
    rotacion_dias: 8,
    capital_invertido: 36000,
  },
  {
    nombre_producto: 'Monturas Luxury',
    stock_actual: 180,
    stock_minimo: 40,
    rotacion_dias: 22,
    capital_invertido: 28000,
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
