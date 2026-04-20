import {
  BarChart3,
  Clock,
  Fingerprint,
  LayoutDashboard,
  Lock,
  type LucideIcon,
  Package,
  TrendingUp,
  Wallet,
} from "lucide-react";

export interface NavSubItem {
  title: string;
  url: string;
  icon?: LucideIcon;
  comingSoon?: boolean;
  newTab?: boolean;
  isNew?: boolean;
}

export interface NavMainItem {
  title: string;
  url: string;
  icon?: LucideIcon;
  subItems?: NavSubItem[];
  comingSoon?: boolean;
  newTab?: boolean;
  isNew?: boolean;
}

export interface NavGroup {
  id: number;
  label?: string;
  items: NavMainItem[];
}

export const sidebarItems: NavGroup[] = [
  {
    id: 1,
    label: "Informes Opticolor",
    items: [
      {
        title: "Resumen Comercial",
        url: "/dashboard/resumen-comercial",
        icon: LayoutDashboard,
      },
      {
        title: "Eficiencia de Órdenes",
        url: "/dashboard/eficiencia-ordenes",
        icon: Clock,
      },
      {
        title: "Control de Cartera",
        url: "/dashboard/control-cartera",
        icon: Wallet,
      },
      {
        title: "Desempeño Clínico",
        url: "/dashboard/desempenio-clinico",
        icon: TrendingUp,
      },
      {
        title: "Inventario",
        url: "/dashboard/inventario",
        icon: Package,
      },
    ],
  },
  {
    id: 2,
    label: "Administración",
    items: [
      {
        title: "Usuarios",
        url: "/dashboard/coming-soon",
        icon: BarChart3,
        comingSoon: true,
      },
      {
        title: "Roles",
        url: "/dashboard/coming-soon",
        icon: Lock,
        comingSoon: true,
      },
      {
        title: "Autenticación",
        url: "/auth",
        icon: Fingerprint,
        subItems: [
          { title: "Login", url: "/auth/v1/login", newTab: true },
          { title: "Registro", url: "/auth/v1/register", newTab: true },
        ],
      },
    ],
  },
];
