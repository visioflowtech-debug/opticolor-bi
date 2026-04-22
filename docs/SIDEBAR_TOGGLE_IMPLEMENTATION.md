# 💻 Implementation Guide: Sidebar Toggle Redesign

**Quick reference for developers implementing the sidebar toggle redesign.**

Ready-to-use code snippets for each file that needs modification.

---

## FILE 1: Layout.tsx (Remove SidebarTrigger)

**Path:** `c:\opticolor-bi\portal\src\app\(main)\dashboard\layout.tsx`

### CURRENT CODE (lines 1-20)

```tsx
import type { ReactNode } from "react";

import { cookies } from "next/headers";

import { AppSidebar } from "@/app/(main)/dashboard/_components/sidebar/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { SidebarInset, SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { users } from "@/data/users";
import { SIDEBAR_COLLAPSIBLE_VALUES, SIDEBAR_VARIANT_VALUES } from "@/lib/preferences/layout";
import { cn } from "@/lib/utils";
import { getPreference } from "@/server/server-actions";

import { AccountSwitcher } from "./_components/sidebar/account-switcher";
import { LayoutControls } from "./_components/sidebar/layout-controls";
import { SearchDialog } from "./_components/sidebar/search-dialog";
import { ThemeSwitcher } from "./_components/sidebar/theme-switcher";
import { DashboardBreadcrumb } from "./_components/sidebar/dashboard-breadcrumb";
```

### NEW CODE (STEP 1: Remove imports)

```tsx
import type { ReactNode } from "react";

import { cookies } from "next/headers";

import { AppSidebar } from "@/app/(main)/dashboard/_components/sidebar/app-sidebar";
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar";
import { users } from "@/data/users";
import { SIDEBAR_COLLAPSIBLE_VALUES, SIDEBAR_VARIANT_VALUES } from "@/lib/preferences/layout";
import { cn } from "@/lib/utils";
import { getPreference } from "@/server/server-actions";

import { AccountSwitcher } from "./_components/sidebar/account-switcher";
import { LayoutControls } from "./_components/sidebar/layout-controls";
import { SearchDialog } from "./_components/sidebar/search-dialog";
import { ThemeSwitcher } from "./_components/sidebar/theme-switcher";
import { DashboardBreadcrumb } from "./_components/sidebar/dashboard-breadcrumb";
```

**Changes:**
- Remove: `Separator`
- Remove: `SidebarTrigger`

---

### CURRENT CODE (lines 45-67)

```tsx
        <header
          className={cn(
            "flex h-12 shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12",
            // Handle sticky navbar style with conditional classes so blur, background, z-index, and rounded corners remain consistent across all SidebarVariant layouts.
            "[html[data-navbar-style=sticky]_&]:sticky [html[data-navbar-style=sticky]_&]:top-0 [html[data-navbar-style=sticky]_&]:z-50 [html[data-navbar-style=sticky]_&]:overflow-hidden [html[data-navbar-style=sticky]_&]:rounded-t-[inherit] [html[data-navbar-style=sticky]_&]:bg-background/50 [html[data-navbar-style=sticky]_&]:backdrop-blur-md",
          )}
        >
          <div className="flex w-full items-center justify-between px-4 lg:px-6">
            <div className="flex items-center gap-1 lg:gap-2">
              <SidebarTrigger className="-ml-1" />
              <Separator
                orientation="vertical"
                className="mx-2 data-[orientation=vertical]:h-4 data-[orientation=vertical]:self-center"
              />
              <SearchDialog />
            </div>
            <div className="flex items-center gap-2">
              <LayoutControls />
              <ThemeSwitcher />
              <AccountSwitcher users={users} />
            </div>
          </div>
        </header>
```

### NEW CODE (STEP 2: Remove trigger + separator from JSX)

```tsx
        <header
          className={cn(
            "flex h-12 shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12",
            // Handle sticky navbar style with conditional classes so blur, background, z-index, and rounded corners remain consistent across all SidebarVariant layouts.
            "[html[data-navbar-style=sticky]_&]:sticky [html[data-navbar-style=sticky]_&]:top-0 [html[data-navbar-style=sticky]_&]:z-50 [html[data-navbar-style=sticky]_&]:overflow-hidden [html[data-navbar-style=sticky]_&]:rounded-t-[inherit] [html[data-navbar-style=sticky]_&]:bg-background/50 [html[data-navbar-style=sticky]_&]:backdrop-blur-md",
          )}
        >
          <div className="flex w-full items-center justify-between px-4 lg:px-6">
            <div className="flex items-center gap-1 lg:gap-2">
              <SearchDialog />
            </div>
            <div className="flex items-center gap-2">
              <LayoutControls />
              <ThemeSwitcher />
              <AccountSwitcher users={users} />
            </div>
          </div>
        </header>
```

**Changes:**
- Remove: `<SidebarTrigger className="-ml-1" />`
- Remove: `<Separator orientation="vertical" ... />`

---

## FILE 2: Sidebar Logo Content (Add Toggle)

**Path:** `c:\opticolor-bi\portal\src\app\(main)\dashboard\_components\sidebar\sidebar-logo-content.tsx`

### CURRENT CODE

```tsx
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

            {/* Favicon: visible when collapsed */}
            {isCollapsed && <Image src="/favicon.ico" alt="Opticolor" width={24} height={24} />}
          </Link>
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
```

### NEW CODE (COMPLETE REPLACEMENT)

```tsx
"use client";

import Link from "next/link";
import Image from "next/image";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { Logo } from "@/components/Logo";
import {
  useSidebar,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Button } from "@/components/ui/button";

export function SidebarLogoContent() {
  const { state, toggleSidebar } = useSidebar();
  const isCollapsed = state === "collapsed";

  // Dynamic icon and labels based on state
  const ChevronIcon = isCollapsed ? ChevronRight : ChevronLeft;
  const toggleLabel = isCollapsed ? "Expandir sidebar" : "Minimizar sidebar";
  const toggleHint = isCollapsed ? "Expandir (Ctrl+B)" : "Minimizar (Ctrl+B)";

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <div className="flex items-center justify-between gap-2 px-2">
          {/* Logo + Text or Favicon */}
          <SidebarMenuButton asChild className="flex-1 min-w-0">
            <Link prefetch={false} href="/dashboard/default" className="flex items-center gap-2">
              {/* Logo + Text: visible when expanded */}
              {!isCollapsed && (
                <>
                  <Logo size="sm" />
                  <span className="font-semibold text-sm truncate">OPTICOLOR</span>
                </>
              )}

              {/* Favicon: visible when collapsed */}
              {isCollapsed && (
                <Image
                  src="/favicon.ico"
                  alt="Opticolor"
                  width={24}
                  height={24}
                />
              )}
            </Link>
          </SidebarMenuButton>

          {/* Toggle Button with Tooltip */}
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                onClick={toggleSidebar}
                className="h-8 w-8 p-0 shrink-0 hover:bg-accent"
                aria-label={toggleLabel}
                title={toggleHint}
              >
                <ChevronIcon size={16} className="text-muted-foreground" />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="right" align="center">
              <div className="space-y-1">
                <p className="text-sm font-medium">{toggleLabel}</p>
                <p className="text-xs text-muted-foreground">{toggleHint}</p>
              </div>
            </TooltipContent>
          </Tooltip>
        </div>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
```

**Key changes:**
- Import: `ChevronLeft, ChevronRight` from lucide-react
- Import: `Tooltip, TooltipContent, TooltipTrigger` from sidebar UI
- Import: `Button` from button UI
- Extract: `toggleSidebar` from `useSidebar()` hook
- Wrap logo + toggle in flex container with `justify-between`
- Add: `<Tooltip>` wrapper with trigger + content
- Add: `<Button>` with icon that changes based on state
- Add: ARIA labels and title attributes

---

## FILE 3: Check Root Layout for TooltipProvider

**Path:** `c:\opticolor-bi\portal\src\app\layout.tsx`

### REQUIRED: Verify TooltipProvider exists

```bash
# Check if TooltipProvider is in root layout
grep -n "TooltipProvider" src/app/layout.tsx
```

### If NOT present, add to root layout

Find the `RootLayout` component and add `<TooltipProvider>`:

```tsx
import { TooltipProvider } from "@/components/ui/tooltip";

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <TooltipProvider>
      {/* existing code */}
      {children}
      {/* existing code */}
    </TooltipProvider>
  );
}
```

**Ensure:**
- TooltipProvider wraps the entire app (usually around `children`)
- Only ONE TooltipProvider in the entire app
- It's in the root layout, not in child components

---

## STEP-BY-STEP IMPLEMENTATION

### Step 1: Update imports in layout.tsx

**File:** `c:\opticolor-bi\portal\src\app\(main)\dashboard\layout.tsx`

```bash
# Lines 1-20
# CHANGE:
# - Remove: Separator import
# - Remove: SidebarTrigger import
```

**Action:** Use the file editor to:
1. Find line 6: `import { Separator } from "@/components/ui/separator";`
2. Delete it
3. Find line 7: `import { SidebarInset, SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";`
4. Change to: `import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar";`

---

### Step 2: Remove JSX from navbar

**File:** `c:\opticolor-bi\portal\src\app\(main)\dashboard\layout.tsx`

**Lines 52-60:** Update the left side of navbar

```bash
# BEFORE:
<div className="flex items-center gap-1 lg:gap-2">
  <SidebarTrigger className="-ml-1" />
  <Separator orientation="vertical" ... />
  <SearchDialog />
</div>

# AFTER:
<div className="flex items-center gap-1 lg:gap-2">
  <SearchDialog />
</div>
```

**Action:** 
1. Find `<SidebarTrigger className="-ml-1" />`
2. Delete that line
3. Find `<Separator orientation="vertical" ... />`
4. Delete those 4 lines (the full Separator component)

---

### Step 3: Replace sidebar-logo-content.tsx completely

**File:** `c:\opticolor-bi\portal\src\app\(main)\dashboard\_components\sidebar\sidebar-logo-content.tsx`

**Action:**
1. Select ALL content (Ctrl+A)
2. Delete
3. Paste the **NEW CODE** from FILE 2 above
4. Save (Ctrl+S)

---

### Step 4: Verify TooltipProvider in root

**File:** `c:\opticolor-bi\portal\src\app\layout.tsx`

**Action:**
1. Search for `TooltipProvider`
2. If found: ✅ Continue to Step 5
3. If NOT found: Add it around children (see FILE 3 above)

---

### Step 5: Type checking

```bash
cd c:\opticolor-bi\portal
npm run type-check
```

**Expected output:**
```
✓ 0 errors
✓ 0 warnings
```

If errors appear, check:
- Imports are spelled correctly
- Component names match Shadcn/UI
- No missing imports

---

### Step 6: Build locally

```bash
npm run build
```

**Expected output:**
```
✓ Compiled successfully
✓ 0 errors
✓ 0 warnings
```

---

### Step 7: Visual testing (local)

If Turbopack dev mode has issues, deploy to Vercel:

```bash
git add -A
git commit -m "refactor: move sidebar toggle from navbar to sidebar header"
git push origin your-feature-branch
```

Wait for Vercel preview URL (2-3 minutes), then test:
- Desktop (1920px): toggle visible + clickable
- Tablet (768px): responsive, no overflow
- Mobile (375px): toggle in sidebar header
- Dark mode: colors visible
- Tooltip: appears on hover

---

## COMMON PITFALLS & FIXES

### Pitfall 1: "useSidebar must be used within SidebarProvider"

**Cause:** Component tries to use hook outside provider tree

**Fix:** Ensure `"use client"` is at top of file

```tsx
"use client";  // ← Must be first line

import { useSidebar } from "@/components/ui/sidebar";
```

---

### Pitfall 2: Tooltip not appearing

**Cause:** TooltipProvider missing in root

**Fix:** Add to root layout:

```tsx
import { TooltipProvider } from "@/components/ui/tooltip";

export default function RootLayout({ children }) {
  return (
    <TooltipProvider>
      {children}
    </TooltipProvider>
  );
}
```

---

### Pitfall 3: ChevronLeft/Right not found

**Cause:** Typo in import or Lucide React not installed

**Fix:** Verify import:

```tsx
// ✓ Correct
import { ChevronLeft, ChevronRight } from "lucide-react";

// ✗ Wrong
import { chevronLeft } from "lucide-react";  // lowercase
import { Chevron } from "lucide-react";       // wrong name
```

---

### Pitfall 4: Button click not working

**Cause:** `toggleSidebar` not extracted from hook

**Fix:** Verify in sidebar-logo-content.tsx:

```tsx
// ✓ Correct
const { state, toggleSidebar } = useSidebar();

// ✗ Wrong
const { state } = useSidebar();  // forgot toggleSidebar
```

---

### Pitfall 5: Icon not changing on collapse

**Cause:** Conditional logic wrong or component not re-rendering

**Fix:** Double-check:

```tsx
// ✓ Correct
const isCollapsed = state === "collapsed";
const ChevronIcon = isCollapsed ? ChevronRight : ChevronLeft;

// ✗ Wrong
const ChevronIcon = ChevronLeft;  // hardcoded, never changes
```

---

## VERIFICATION CHECKLIST

### Code Quality
- [ ] No TypeScript errors: `npm run type-check`
- [ ] Build succeeds: `npm run build`
- [ ] No console errors in browser DevTools
- [ ] All imports present and correct

### Visual
- [ ] Desktop: toggle visible right side of header
- [ ] Minimize: sidebar collapses, icon changes to `▶`
- [ ] Expand: sidebar expands, icon changes to `◀`
- [ ] Tooltip: appears on hover with text

### Responsive
- [ ] Mobile (375px): toggle visible, clickable
- [ ] Tablet (768px): no overflow, works like desktop
- [ ] Desktop (1920px): works as designed

### Accessibility
- [ ] Keyboard Tab: reaches toggle button
- [ ] Focus indicator: visible (blue ring)
- [ ] Ctrl+B: toggles sidebar
- [ ] Screen reader: announces button correctly

### State
- [ ] Refresh page: sidebar state persists
- [ ] Switch to dark mode: toggle still visible
- [ ] Switch to light mode: toggle still visible

---

## GIT COMMIT MESSAGE

```
refactor: move sidebar toggle from navbar to sidebar header

- Remove SidebarTrigger and Separator from navbar (layout.tsx)
- Move toggle button to sidebar header with ChevronLeft/Right icons
- Add Tooltip for improved UX ("Minimizar/Expandir sidebar")
- Maintain Ctrl+B keyboard shortcut functionality
- Improve navbar space utilization and visual hierarchy

Files changed:
  - src/app/(main)/dashboard/layout.tsx
  - src/app/(main)/dashboard/_components/sidebar/sidebar-logo-content.tsx

No breaking changes.
```

---

## POST-DEPLOYMENT MONITORING

After merging to main:

```
Hour 1:
- [ ] Check Vercel build succeeded
- [ ] opticolor-bi.vercel.app loads
- [ ] Toggle visible and clickable
- [ ] No console errors

Hour 2-4:
- [ ] No error logs in Vercel monitoring
- [ ] Cross-browser test (Chrome, Firefox, Safari)
- [ ] Mobile test (iOS Safari, Android Chrome)

Ongoing:
- [ ] Monitor Sentry/error tracking
- [ ] Check user feedback on toggle usability
- [ ] Watch performance metrics (no regression)
```

---

## QUICK REFERENCE

### Files Modified
1. `src/app/(main)/dashboard/layout.tsx` — Remove SidebarTrigger + Separator
2. `src/app/(main)/dashboard/_components/sidebar/sidebar-logo-content.tsx` — Add toggle + Tooltip

### Files Verified
1. `src/app/layout.tsx` — Ensure TooltipProvider present

### New Dependencies
- None (Lucide, Shadcn/UI, React already present)

### Breaking Changes
- None

### Backward Compatibility
- ✅ Ctrl+B shortcut still works
- ✅ Sidebar state still persists in cookie
- ✅ All existing features unaffected

---

**Last updated:** 21 Abril 2026  
**Status:** ✅ Ready to implement  
