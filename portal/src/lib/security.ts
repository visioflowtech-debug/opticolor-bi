import * as mssql from "mssql";
import { unstable_cache } from "next/cache";
import { getConnection } from "@/lib/db";

async function fetchUserAllowedSucursales(userId: number): Promise<string> {
  const pool = await getConnection();
  const result = await pool.request()
    .input("userId", mssql.Int, userId)
    .query(`
      SELECT id_sucursal
      FROM dbo.Seguridad_Usuarios_Sucursales
      WHERE id_usuario = @userId AND esta_vigente = 1
    `);

  if (result.recordset.length === 0) {
    return "-1";
  }

  return result.recordset.map((row) => row.id_sucursal).join(",");
}

export const getUserAllowedSucursales = unstable_cache(
  async (userId: number) => {
    return fetchUserAllowedSucursales(userId);
  },
  ["user-permissions"],
  { revalidate: 7200, tags: ["user-permissions"] }
);
