"use client";

import { useEffect, useRef } from "react";
import { signOut, useSession } from "next-auth/react";

const INACTIVITY_MS = 15 * 60 * 1000; // 15 minutos
const ACTIVITY_EVENTS = ["mousemove", "keydown", "scroll", "click"] as const;

export function SessionWatcher() {
  const { status } = useSession();
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    // Sesión expirada detectada en cliente → cerrar inmediatamente
    if (status === "unauthenticated") {
      void signOut({ callbackUrl: "/login" });
      return;
    }
    if (status !== "authenticated") return;

    const resetTimer = () => {
      if (timerRef.current) clearTimeout(timerRef.current);
      timerRef.current = setTimeout(() => {
        void signOut({ callbackUrl: "/login" });
      }, INACTIVITY_MS);
    };

    resetTimer();
    ACTIVITY_EVENTS.forEach((ev) =>
      window.addEventListener(ev, resetTimer, { passive: true }),
    );

    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
      ACTIVITY_EVENTS.forEach((ev) => window.removeEventListener(ev, resetTimer));
    };
  }, [status]);

  return null;
}
