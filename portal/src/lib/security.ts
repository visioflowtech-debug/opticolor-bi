import sql from "mssql";
import { unstable_cache } from "next/cache";
import { getConnection } from "@/lib/db";

async function fetchUserAllowedSucursales(userId: string): Promise<string> {
  console.log("[AUDITORÍA-PERMISOS] Valor recibido en userId:", userId, " | Tipo:", typeof userId);

  if (!userId) {
    return "-1";
  }

  try {
    const pool = await getConnection();
    const request = pool.request();

    const isNumeric = !isNaN(Number(userId)) && String(userId).trim() !== "";

    if (isNumeric) {
      // Si es un ID numérico (ej: "1" o 12), lo mandamos como INT nativo
      request.input("userId", sql.Int, Number(userId));
    } else {
      // Si es un email o string alfanumérico, lo mandamos como VarChar
      request.input("userId", sql.VarChar, String(userId).trim());
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
