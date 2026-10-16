"use client";

import { useEffect, useState } from "react";
import { useAuth, useUser } from "@clerk/nextjs";
import {
  LayoutDashboard,
  Users,
  Building2,
  BookOpen,
  Fuel,
  ClipboardList,
  AlertTriangle,
  Truck,
  Settings,
  ShieldAlert,
  LogOut,
  ShieldCheck,
  Menu,
  ChevronRight,
} from "lucide-react";
import Link from "next/link";
import { cn } from "@/lib/utils";

const NAV_ITEMS = [
  {
    name: "Dashboard",
    href: "/dashboard",
    icon: LayoutDashboard,
    requiredRole: null,
  },
  {
    name: "Users",
    href: "/users",
    icon: Users,
    requiredRole: ["ADMIN", "SYSTEM_ADMIN"],
  },
  {
    name: "Tenants",
    href: "/tenants",
    icon: Building2,
    requiredRole: ["ADMIN", "SYSTEM_ADMIN"],
  },
  {
    name: "Training",
    href: "/training",
    icon: BookOpen,
    requiredRole: null,
  },
  {
    name: "Fuel",
    href: "/fuel",
    icon: Fuel,
    requiredRole: null,
  },
  {
    name: "Inspections",
    href: "/inspections",
    icon: ClipboardList,
    requiredRole: null,
  },
  {
    name: "Accidents",
    href: "/accidents",
    icon: AlertTriangle,
    requiredRole: null,
  },
  {
    name: "Vehicles",
    href: "/vehicles",
    icon: Truck,
    requiredRole: null,
  },
  {
    name: "Settings",
    href: "/settings",
    icon: Settings,
    requiredRole: ["ADMIN", "SYSTEM_ADMIN"],
  },
  {
    name: "Privacy (DSAR)",
    href: "/privacy",
    icon: ShieldAlert,
    requiredRole: null,
  },
];

export function Sidebar() {
  const { user, isLoaded } = useUser();
  const [collapsed, setCollapsed] = useState(false);
  const { signOut } = useAuth();

  const visibleItems = NAV_ITEMS.filter((item) => {
    if (!item.requiredRole) return true;
    if (!user) return false;
    const roles = (user.publicMetadata as any)?.roles ?? [];
    return item.requiredRole.some((r: string) => roles.includes(r));
  });

  if (!isLoaded) {
    return (
      <aside className="w-16 border-r border-border bg-white flex flex-col items-center py-6">
        <div className="h-10 w-10 rounded-lg bg-helix-100 flex items-center justify-center mb-8">
          <span className="text-helix-600 font-bold">H</span>
        </div>
        {NAV_ITEMS.map((item) => (
          <div key={item.name} className="sidebar-item h-10 w-10 flex-col justify-center items-center gap-1 p-0 text-helix-400 hover:bg-helix-50">
            <item.icon className="h-5 w-5" />
          </div>
        ))}
        <div className="mt-auto mb-4">
          <button
            onClick={() => signOut()}
            className="sidebar-item h-10 w-10 flex-col justify-center items-center gap-1 p-0 text-red-400 hover:bg-red-50"
          >
            <LogOut className="h-5 w-5" />
          </button>
        </div>
      </aside>
    );
  }

  return (
    <>
      <aside
        className={cn(
          "flex flex-col items-center py-6 border-r border-border bg-white transition-all duration-300",
          collapsed ? "w-16" : "w-64",
        )}
      >
        <div className={`flex items-center gap-2 px-4 mb-8 ${collapsed ? "justify-center" : ""}`}>
          <div className="h-10 w-10 rounded-lg bg-helix-100 flex items-center justify-center">
            <span className="text-helix-600 font-bold">H</span>
          </div>
          {!collapsed && (
            <h1 className="font-bold text-lg text-ink tracking-tight">Helix Admin</h1>
          )}
        </div>

        <nav className="flex-1">
          {visibleItems.map((item) => {
            const isActive = typeof window !== "undefined" && window.location.pathname === item.href;
            return (
              <Link
                key={item.name}
                href={item.href}
                className={cn(
                  "sidebar-item",
                  isActive ? "bg-helix-50 text-helix-900 border-r-2 border-helix-500" : "text-ink-600 hover:bg-muted",
                  collapsed ? "h-10 w-10 flex-col justify-center items-center p-0" : "h-10 px-4 justify-between",
                )}
              >
                <item.icon className="h-5 w-5" />
                {!collapsed && <span>{item.name}</span>}
                {!collapsed && <ChevronRight className="h-4 w-4 text-ink-300" />}
              </Link>
            );
          })}
        </nav>

        <div className="mt-auto p-4">
          <button
            onClick={() => signOut()}
            className={cn(
              "sidebar-item",
              collapsed ? "h-10 w-10 flex-col justify-center items-center p-0 text-red-400 hover:bg-red-50" : "h-10 px-4 justify-between text-red-600 hover:bg-red-50",
            )}
          >
            <LogOut className="h-5 w-5" />
            {!collapsed && <span>Sign out</span>}
          </button>
        </div>
      </aside>

      {!collapsed && (
        <button
          onClick={() => setCollapsed((c) => !c)}
          className="absolute left-4 top-6 z-20 p-2 text-ink-600 hover:text-ink-900"
          aria-label="Collapse sidebar"
        >
          <Menu className="h-5 w-5" />
        </button>
      )}
    </>
  );
}
