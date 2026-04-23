import type { ReactNode } from "react";

import type { Metadata } from "next";

import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { APP_CONFIG } from "@/config/app-config";
import { fontVars } from "@/lib/fonts/registry";
import { PREFERENCE_DEFAULTS } from "@/lib/preferences/preferences-config";
import { THEME_MODE_VALUES } from "@/lib/preferences/theme";
import { SIDEBAR_VARIANT_VALUES, SIDEBAR_COLLAPSIBLE_VALUES, CONTENT_LAYOUT_VALUES, NAVBAR_STYLE_VALUES } from "@/lib/preferences/layout";
import { THEME_PRESET_VALUES } from "@/lib/preferences/theme";
import { ThemeBootScript } from "@/scripts/theme-boot";
import { PreferencesStoreProvider } from "@/stores/preferences/preferences-provider";
import { getPreference } from "@/server/server-actions";
import { fontRegistry } from "@/lib/fonts/registry";
import { Providers } from "@/app/providers";

const FONT_KEYS = Object.keys(fontRegistry) as Array<keyof typeof fontRegistry>;

import "./globals.css";

export const metadata: Metadata = {
  title: APP_CONFIG.meta.title,
  description: APP_CONFIG.meta.description,
};

export const dynamic = "force-dynamic";

export default async function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  const [theme_mode, theme_preset, content_layout, navbar_style, sidebar_variant, sidebar_collapsible, font] =
    await Promise.all([
      getPreference("theme_mode", THEME_MODE_VALUES, PREFERENCE_DEFAULTS.theme_mode),
      getPreference("theme_preset", THEME_PRESET_VALUES, PREFERENCE_DEFAULTS.theme_preset),
      getPreference("content_layout", CONTENT_LAYOUT_VALUES, PREFERENCE_DEFAULTS.content_layout),
      getPreference("navbar_style", NAVBAR_STYLE_VALUES, PREFERENCE_DEFAULTS.navbar_style),
      getPreference("sidebar_variant", SIDEBAR_VARIANT_VALUES, PREFERENCE_DEFAULTS.sidebar_variant),
      getPreference("sidebar_collapsible", SIDEBAR_COLLAPSIBLE_VALUES, PREFERENCE_DEFAULTS.sidebar_collapsible),
      getPreference("font", FONT_KEYS, PREFERENCE_DEFAULTS.font),
    ]);
  return (
    <html
      lang="en"
      data-theme-mode={theme_mode}
      data-theme-preset={theme_preset}
      data-content-layout={content_layout}
      data-navbar-style={navbar_style}
      data-sidebar-variant={sidebar_variant}
      data-sidebar-collapsible={sidebar_collapsible}
      data-font={font}
      suppressHydrationWarning
    >
      <head>
        <link rel="icon" href="/favicon.ico" />
        {/* Applies theme and layout preferences on load to avoid flicker and unnecessary server rerenders. */}
        <ThemeBootScript />
      </head>
      <body className={`${fontVars} min-h-screen antialiased`}>
        <Providers>
          <TooltipProvider>
            <PreferencesStoreProvider
              themeMode={theme_mode}
              themePreset={theme_preset}
              contentLayout={content_layout}
              navbarStyle={navbar_style}
              font={font}
            >
              {children}
              <Toaster />
            </PreferencesStoreProvider>
          </TooltipProvider>
        </Providers>
      </body>
    </html>
  );
}
