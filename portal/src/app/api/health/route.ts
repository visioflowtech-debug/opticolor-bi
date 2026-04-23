import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET() {
  try {
    console.log('[Health] Verificando conexión a BD...');
    console.log('[Health] Variables de entorno:', {
      server: process.env.AZURE_SQL_SERVER,
      database: process.env.AZURE_SQL_DATABASE,
      user: process.env.AZURE_SQL_USER,
      port: process.env.AZURE_SQL_PORT,
    });

    const result = await query('SELECT TOP 1 id_usuario, email FROM Vw_Usuario_Accesos');

    return NextResponse.json({
      status: 'ok',
      message: 'Conexión a BD exitosa',
      recordCount: result.length,
    });
  } catch (error) {
    console.error('[Health] Error:', error);
    return NextResponse.json(
      {
        status: 'error',
        message: String(error),
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 500 }
    );
  }
}
