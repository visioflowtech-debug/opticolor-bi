import { getServerSession } from "next-auth";
import { redirect } from "next/navigation";
import { ShieldAlert } from "lucide-react";

import { authOptions } from "@/app/api/auth/[...nextauth]/route";
import { getUsuarios } from "./_actions/get-usuarios";
import { getRoles } from "./_actions/get-roles";
import { getSucursalesParaSelector } from "./_actions/get-sucursales";
import UsuariosClient from "./_components/usuarios-client";

export default async function UsuariosPage() {
  const session = await getServerSession(authOptions);

  if (!session?.user) redirect("/login");

  // Protección: solo niveles 1 y 2
  if ((session.user.nivel ?? 99) > 2) {
    return (
      <div className="flex h-full w-full flex-col items-center justify-center gap-4 text-center">
        <div className="rounded-full bg-destructive/10 p-6">
          <ShieldAlert className="h-12 w-12 text-destructive" />
        </div>
        <h1 className="text-2xl font-bold">Acceso Denegado</h1>
        <p className="text-muted-foreground max-w-md">
          No tienes permisos para acceder a la Gestión de Usuarios. Esta sección está reservada
          para administradores de nivel jerárquico 1 y 2.
        </p>
      </div>
    );
  }

  const [usuariosResult, rolesResult, sucursalesResult] = await Promise.all([
    getUsuarios(),
    getRoles(),
    getSucursalesParaSelector(),
  ]);

  return (
    <div className="w-full max-w-full px-4 pb-6 md:px-6 space-y-6 overflow-hidden">
      <UsuariosClient
        data={usuariosResult.data}
        roles={rolesResult.data}
        sucursales={sucursalesResult.data}
        currentUserId={Number(session.user.id)}
      />
    </div>
  );
}
