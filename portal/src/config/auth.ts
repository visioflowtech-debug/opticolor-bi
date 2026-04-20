// NextAuth Configuration (Skeleton)
// Implementación real: Semana 2.2 cuando lleguen usuarios de Opticolor

export const handlers = {
  GET: async () => {
    return new Response('NextAuth GET', { status: 200 });
  },
  POST: async () => {
    return new Response('NextAuth POST', { status: 200 });
  },
};

export async function auth() {
  // Mock session para testing
  return {
    user: {
      id: '1',
      email: 'test@opticolor.com',
      name: 'Usuario Test',
    },
  };
}
