"use client";

import { useAuth, useUser } from "@clerk/nextjs";
import { useEffect, useState } from "react";
import { Bell, Sun, Moon, ShieldCheck, User, Calendar } from "lucide-react";
import Link from "next/link";
import { cn } from "@/lib/utils";

export function TopBar() {
  const { user, isLoaded } = useUser();
  const { signOut } = useAuth();
  const [theme, setTheme] = useState("light");

  useEffect(() => {
    const saved = localStorage.getItem("theme");
    if (saved) setTheme(saved);
    else if (window.matchMedia("(prefers-color-scheme: dark)").matches) setTheme("dark");
  }, []);

  const toggleTheme = () => {
    const next = theme === "light" ? "dark" : "light";
    setTheme(next);
    localStorage.setItem("theme", next);
    document.documentElement.classList.toggle("dark", next === "dark");
  };

  if (!isLoaded) return null;

  return (
    <header className="h-16 border-b border-border bg-white/80 backdrop-blur-md flex items-center justify-between px-6 shrink-0">
      <div className="flex items-center gap-4">
        <button
          onClick={toggleTheme}
          className="p-2 rounded-md text-ink-600 hover:bg-muted transition-colors"
          aria-label="Toggle theme"
        >
          {theme === "light" ? (
            <Moon className="h-5 w-5" />
          ) : (
            <Sun className="h-5 w-5" />
          )}
        </button>
        <div className="hidden md:flex items-center gap-6 text-sm text-ink-600">
          <div className="flex items-center gap-2 text-xs font-medium text-helix-600">
            <ShieldCheck className="h-3 w-3" />
            <span>System Online</span>
          </div>
          <div className="flex items-center gap-2 text-xs font-medium text-ink-600">
            <Calendar className="h-3 w-3" />
            <span>{new Date().toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })}</span>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <button className="p-2 text-ink-600 hover:bg-muted rounded-md" aria-label="Notifications">
          <Bell className="h-5 w-5" />
        </button>
        <div className="flex items-center gap-3 px-3 py-1.5 rounded-full border border-border bg-white">
          <div className="flex flex-col items-end">
            <span className="text-xs font-medium text-ink">{user?.fullName ?? "Admin"}</span>
            <span className="text-xs text-ink-500">{user?.primaryEmailAddress?.emailAddress ?? "admin@helix.local"}</span>
          </div>
          <div className="h-8 w-8 rounded-full bg-helix-100 flex items-center justify-center text-helix-600 font-bold ml-2">
            {user?.fullName?.charAt(0) ?? "A"}
          </div>
        </div>
      </div>
    </header>
  );
}
