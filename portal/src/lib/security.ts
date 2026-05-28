import sql from "mssql";
import { unstable_cache } from "next/cache";
import { getConnection } from "@/lib/db";

async function fetchUserAllowedSucursales(userId: string): Promise<string> {
  if (process.env.NODE_ENV !== "production") {
    console.log("[AUDITORÍA-PERMISOS] Valor recibido en userId:", userId, " | Tipo:", typeof userId);
  }

  if (!userId) {
    return "-1";
  }

  try {
    const pool = await getConnection();
    const request = pool.request();

    const isNumeric = !isNaN(Number(userId)) && String(userId).trim() !== "";

    if (isNumeric) {
      // Al pasar el número directamente sin el segundo argumento de tipo, 
      // el driver mssql mapea el primitivo de JS a INT/FLOAT automáticamente sin romper su validador.
      request.input("userId", Number(userId));
    } else {
      // Para strings o correos, usamos sql.VarChar como función invocada
      request.input("userId", sql.VarChar(100), String(userId).trim());
    }

    const result = await request.query(`
      SELECT id_sucursal
      FROM dbo.Seguridad_Usuarios_Sucursales
      WHERE id_usuario = @userId AND esta_vigente = 1
    `);

    if (result.recordset.length === 0) {
      return "-1";
    }

    return result.recordset.map((row) => row.id_sucursal).join(",");
  } catch (error) {
    console.error("[EMERGENCIA][fetchUserAllowedSucursales] Error en query de sucursales:", error);
    // Escape fallback to prevent freezing the UI on database errors
    return "-1";
  }
}

export const getUserAllowedSucursales = unstable_cache(
  async (userId: number | string) => {
    return fetchUserAllowedSucursales(String(userId).trim());
  },
  ["user-permissions"],
  { revalidate: 7200, tags: ["user-permissions"] }
);
