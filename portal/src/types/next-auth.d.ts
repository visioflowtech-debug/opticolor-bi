import "next-auth"
import "next-auth/jwt"

declare module "next-auth" {
  interface Session {
    user: {
      id: string
      email: string
      name: string
      nombre_rol: string
      nivel_jerarquico: number
      image?: string | null
    }
  }

  interface User {
    id: string
    email: string
    name: string
    nombre_rol: string
    nivel_jerarquico: number
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    id: string
    email: string
    name: string
    nombre_rol: string
    nivel_jerarquico: number
  }
}
