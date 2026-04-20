'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const navItems = [
  { href: '/dashboard', label: '📊 Resumen Comercial' },
  { href: '/dashboard/eficiencia-ordenes', label: '⚙️ Eficiencia de Órdenes' },
  { href: '/dashboard/control-cartera', label: '💰 Control de Cartera' },
  { href: '/dashboard/desempenio-clinico', label: '🏥 Desempeño Clínico' },
  { href: '/dashboard/inventario', label: '📦 Inventario' },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="fixed left-0 top-16 bottom-0 w-64 bg-primary-900 text-white overflow-y-auto">
      <nav className="p-4 space-y-2">
        {navItems.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`block px-4 py-3 rounded-lg transition ${
              pathname === item.href
                ? 'bg-primary-600 font-semibold'
                : 'hover:bg-primary-800'
            }`}
          >
            {item.label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
