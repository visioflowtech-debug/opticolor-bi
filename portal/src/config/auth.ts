import { auth as authFn } from '@/app/api/auth/[...nextauth]/route';

// Re-export auth from the route handler
export const auth = authFn;
