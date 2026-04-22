"use client";

import Link from "next/link";
import Image from "next/image";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { Logo } from "@/components/Logo";
import { useSidebar, SidebarMenu, SidebarMenuButton, SidebarMenuItem } from "@/components/ui/sidebar";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";

export function SidebarLogoContent() {
  const { state, toggleSidebar } = useSidebar();
  const isCollapsed = state === "collapsed";

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        {/* Expanded state: Logo + Text + Toggle */}
        {!isCollapsed && (
          <div className="flex items-center justify-between gap-2">
            <SidebarMenuButton asChild className="flex-1">
              <Link prefetch={false} href="/dashboard/default" className="flex items-center gap-2">
                <Logo size="sm" />
                <span className="font-semibold text-sm">OPTICOLOR</span>
              </Link>
            </SidebarMenuButton>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 shrink-0"
                  onClick={() => toggleSidebar()}
                  aria-label="Minimizar sidebar"
                >
                  <ChevronLeft className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right" className="ml-2">
                Minimizar
              </TooltipContent>
            </Tooltip>
          </div>
        )}

        {/* Collapsed state: Favicon + Toggle */}
        {isCollapsed && (
          <div className="flex flex-col items-center justify-center gap-2">
            <SidebarMenuButton asChild className="w-full justify-center">
              <Link prefetch={false} href="/dashboard/default">
                <Image src="/favicon.ico" alt="Opticolor" width={24} height={24} />
              </Link>
            </SidebarMenuButton>

            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8"
                  onClick={() => toggleSidebar()}
                  aria-label="Expandir sidebar"
                >
                  <ChevronRight className="h-4 w-4" />
                </Button>
              </TooltipTrigger>
              <TooltipContent side="right" className="ml-2">
                Expandir
              </TooltipContent>
            </Tooltip>
          </div>
        )}
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
