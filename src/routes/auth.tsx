import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { toast } from "sonner";

import { AppLayout } from "@/components/app-layout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/auth")({
  head: () => {
    const title = "Workspace sign in | IYEOB";
    const description = "Sign in or create an IYEOB workspace account to contribute and review synthetic datasets.";
    return {
      meta: [
        { title },
        { name: "description", content: description },
        { property: "og:title", content: title },
        { property: "og:description", content: description },
        { property: "og:type", content: "website" },
        { name: "twitter:card", content: "summary_large_image" },
      ],
    };
  },
  component: AuthPage,
});

function AuthPage() {
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");

  const signIn = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success("Signed in");
    void navigate({ to: "/submissions" });
  };

  const signUp = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy(true);
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { emailRedirectTo: window.location.origin, data: { full_name: fullName } },
    });
    setBusy(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    if (data.session) {
      toast.success("Welcome to IYEOB");
      void navigate({ to: "/submissions" });
      return;
    }
    toast.success("Check your email to confirm your account.");
  };

  return (
    <AppLayout>
      <section className="mx-auto max-w-md px-5 py-20">
        <span className="text-xs font-extrabold uppercase tracking-[0.18em] text-primary">Workspace access</span>
        <h1 className="mt-3 font-display text-3xl font-extrabold">Contribute and review synthetic datasets.</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">
          Members submit documented synthetic datasets. Administrators review, approve, and publish them.
        </p>

        <Tabs defaultValue="signin" className="mt-8">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="signin">Sign in</TabsTrigger>
            <TabsTrigger value="signup">Create account</TabsTrigger>
          </TabsList>

          <TabsContent value="signin">
            <form className="mt-6 space-y-4 border border-border bg-card p-6" onSubmit={signIn}>
              <Field label="Email" id="signin-email"><Input id="signin-email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
              <Field label="Password" id="signin-password"><Input id="signin-password" type="password" required value={password} onChange={(e) => setPassword(e.target.value)} /></Field>
              <Button type="submit" className="w-full" disabled={busy}>{busy ? "Signing in…" : "Sign in"}</Button>
            </form>
          </TabsContent>

          <TabsContent value="signup">
            <form className="mt-6 space-y-4 border border-border bg-card p-6" onSubmit={signUp}>
              <Field label="Full name" id="signup-name"><Input id="signup-name" required value={fullName} onChange={(e) => setFullName(e.target.value)} /></Field>
              <Field label="Email" id="signup-email"><Input id="signup-email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
              <Field label="Password" id="signup-password"><Input id="signup-password" type="password" required minLength={8} value={password} onChange={(e) => setPassword(e.target.value)} /></Field>
              <Button type="submit" className="w-full" disabled={busy}>{busy ? "Creating account…" : "Create account"}</Button>
              <p className="text-xs leading-5 text-muted-foreground">New members join as contributors. The first member of a workspace becomes its administrator.</p>
            </form>
          </TabsContent>
        </Tabs>

        <p className="mt-8 text-sm text-muted-foreground">
          Just browsing? <Link to="/datasets" className="font-semibold text-primary">Explore the repository</Link>.
        </p>
      </section>
    </AppLayout>
  );
}

function Field({ label, id, children }: { label: string; id: string; children: React.ReactNode }) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      {children}
    </div>
  );
}
