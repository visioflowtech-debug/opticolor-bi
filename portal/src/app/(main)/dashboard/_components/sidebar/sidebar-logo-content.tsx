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
            {/* Logo + Text: visible when expanded */}
            {!isCollapsed && (
              <>
                <Logo size="sm" />
                <span className="font-semibold text-sm">OPTICOLOR</span>
              </>
            )}

            {/* Collapsed state: empty space (clean minimalist design) */}
            {isCollapsed && <div className="h-6 w-full" />}
          </Link>
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
