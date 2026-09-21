import type { ReactNode } from "react";
import { SiteFooter } from "./site-footer";
import { SiteHeader } from "./site-header";

export function AppLayout({ children }: { children: ReactNode }) {
  return <div className="min-h-screen bg-background"><SiteHeader /><main>{children}</main><SiteFooter /></div>;
}