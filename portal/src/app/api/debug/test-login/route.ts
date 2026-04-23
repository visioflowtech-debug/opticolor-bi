import { query } from '@/lib/db';
import bcrypt from 'bcryptjs';

export async function GET(req: Request) {
  const email = 'master.test@opticolor.com';
  const password = 'opticolor123';

  const logs: string[] = [];

  try {
    logs.push('[TEST] Iniciando test de login...');

    logs.push(`[TEST] Buscando usuario: ${email}`);

    const rows = await query<{
      id_usuario: number;
      email: string;
      nombre_completo: string;
      password_hash: string;
      nombre_rol: string;
      nivel_jerarquico: number;
    }>(
      `SELECT id_usuario, email, nombre_completo, password_hash, nombre_rol, nivel_jerarquico
       FROM Vw_Usuario_Accesos
       WHERE email = @email`,
      { email }
    );

    logs.push(`[TEST] Registros encontrados: ${rows.length}`);

    if (!rows.length) {
      logs.push('[TEST] ERROR: Usuario no encontrado');
      return Response.json({ logs, error: 'Usuario no encontrado' });
    }

    const user = rows[0];
    logs.push(`[TEST] Usuario encontrado: ${user.nombre_completo} (ID: ${user.id_usuario})`);
    logs.push(`[TEST] Password hash en BD: ${user.password_hash.substring(0, 20)}...`);

    logs.push(`[TEST] Comparando password...`);
    const isValid = await bcrypt.compare(password, user.password_hash);
    logs.push(`[TEST] Password válido: ${isValid}`);

    if (!isValid) {
      logs.push('[TEST] ERROR: Password incorrecto');
      return Response.json({ logs, error: 'Password incorrecto', user });
    }

    logs.push('[TEST] ✅ Login sería exitoso');

    return Response.json({
      logs,
      success: true,
      user: {
        id: user.id_usuario,
        email: user.email,
        name: user.nombre_completo,
        nombre_rol: user.nombre_rol,
        nivel_jerarquico: user.nivel_jerarquico,
      },
    });
  } catch (error) {
    logs.push(`[TEST] ERROR: ${error instanceof Error ? error.message : String(error)}`);
    return Response.json({ logs, error: String(error) });
  }
}
