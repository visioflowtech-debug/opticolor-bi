"use client";

import Link from "next/link";
import Image from "next/image";

import { Logo } from "@/components/Logo";
import { useSidebar, SidebarMenu, SidebarMenuButton, SidebarMenuItem } from "@/components/ui/sidebar";

export function SidebarLogoContent() {
  const { state } = useSidebar();
  const isCollapsed = state === "collapsed";

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <SidebarMenuButton asChild>
          <Link prefetch={false} href="/dashboard/default" className="flex items-center gap-2">
            {/* Logo: visible when expanded */}
            {!isCollapsed && <Logo size="sm" />}

            {/* Favicon: visible when collapsed */}
            {isCollapsed && <Image src="/favicon.ico" alt="Opticolor" width={24} height={24} />}

            {/* Text: visible only when expanded */}
            {!isCollapsed && <span className="font-semibold text-sm">OPTICOLOR</span>}
          </Link>
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
