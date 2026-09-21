import { useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import { Menu, Search, X } from "lucide-react";
import { useState } from "react";

import logo from "@/assets/iyeob.png.asset.json";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/auth";

const links = [
  { label: "Datasets", to: "/datasets" as const },
  { label: "Research", to: "/research" as const },
  { label: "Developers", to: "/developers" as const },
];

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const { user, isAdmin, signOut } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const handleSignOut = async () => {
    await queryClient.cancelQueries();
    queryClient.clear();
    await signOut();
    void navigate({ to: "/auth", replace: true });
  };

  return (
    <header className="sticky top-0 z-50 border-b border-border/70 bg-background/90 backdrop-blur-xl">
      <div className="mx-auto flex h-18 max-w-7xl items-center justify-between px-5 lg:px-8">
        <Link to="/" className="flex items-center gap-2.5" aria-label="IYEOB home">
          <img src={logo.url} alt="" className="size-9 object-contain" />
          <span className="font-display text-xl font-extrabold tracking-normal text-foreground">IYEOB</span>
        </Link>

        <nav className="hidden items-center gap-8 md:flex" aria-label="Primary navigation">
          {links.map((link) => (
            <Link
              key={link.to}
              to={link.to}
              className={`text-sm font-medium transition-colors ${pathname === link.to ? "text-primary" : "text-muted-foreground hover:text-foreground"}`}
            >
              {link.label}
            </Link>
          ))}
          <span className="group relative cursor-default text-sm font-medium text-muted-foreground">
            Models
            <span className="absolute -right-4 -top-2 size-1.5 rounded-full bg-highlight" />
          </span>
          <span className="group relative cursor-default text-sm font-medium text-muted-foreground">
            APIs
            <span className="absolute -right-4 -top-2 size-1.5 rounded-full bg-highlight" />
          </span>
        </nav>

        <div className="hidden items-center gap-2 md:flex">
          <Button variant="ghost" size="icon" aria-label="Search datasets" asChild>
            <Link to="/datasets"><Search /></Link>
          </Button>
          {user ? (
            <>
              {isAdmin && <Button variant="ghost" asChild><Link to="/admin">Admin</Link></Button>}
              <Button variant="ghost" asChild><Link to="/saved">Saved</Link></Button>
              <Button variant="ghost" asChild><Link to="/submissions">My submissions</Link></Button>
              <Button variant="outline" onClick={() => void handleSignOut()}>Sign out</Button>
            </>
          ) : (
            <>
              <Button variant="ghost" asChild><Link to="/auth">Sign in</Link></Button>
              <Button asChild><Link to="/auth">Get started</Link></Button>
            </>
          )}
        </div>

        <Button variant="ghost" size="icon" className="md:hidden" onClick={() => setOpen((value) => !value)} aria-label="Toggle navigation">
          {open ? <X /> : <Menu />}
        </Button>
      </div>
      {open && (
        <nav className="border-t border-border bg-background px-5 py-5 md:hidden" aria-label="Mobile navigation">
          <div className="mx-auto flex max-w-7xl flex-col gap-1">
            {links.map((link) => (
              <Link key={link.to} to={link.to} onClick={() => setOpen(false)} className="rounded-md px-3 py-3 text-sm font-semibold hover:bg-muted">
                {link.label}
              </Link>
            ))}
            {user && (
              <Link to="/saved" onClick={() => setOpen(false)} className="rounded-md px-3 py-3 text-sm font-semibold hover:bg-muted">Saved datasets</Link>
            )}
            {user && (
              <Link to="/submissions" onClick={() => setOpen(false)} className="rounded-md px-3 py-3 text-sm font-semibold hover:bg-muted">My submissions</Link>
            )}
            {user && isAdmin && (
              <Link to="/admin" onClick={() => setOpen(false)} className="rounded-md px-3 py-3 text-sm font-semibold hover:bg-muted">Admin</Link>
            )}
            {user ? (
              <Button variant="outline" className="mt-3" onClick={() => { setOpen(false); void handleSignOut(); }}>Sign out</Button>
            ) : (
              <Button className="mt-3" asChild><Link to="/auth" onClick={() => setOpen(false)}>Sign in</Link></Button>
            )}
          </div>
        </nav>
      )}
    </header>
  );
}