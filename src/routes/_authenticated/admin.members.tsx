import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, Mail, ShieldCheck, ShieldMinus, Trash2, UserPlus } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

import { AppLayout } from "@/components/app-layout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";

export const Route = createFileRoute("/_authenticated/admin/members")({
  head: () => ({
    meta: [
      { title: "Administrator management | IYEOB Admin" },
      { name: "description", content: "Invite administrators, promote contributors, and revoke administrator privileges." },
    ],
  }),
  component: MembersPage,
});

type Member = { user_id: string; email: string | null; full_name: string | null; roles: string[]; created_at: string };
type Invite = { id: string; email: string; accepted_at: string | null; created_at: string };

function MembersPage() {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  const members = useQuery({
    queryKey: ["workspace-members"],
    queryFn: async () => {
      const { data, error } = await supabase.rpc("list_workspace_members");
      if (error) throw error;
      return (data ?? []) as Member[];
    },
  });

  const invites = useQuery({
    queryKey: ["admin-invites"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("admin_invites")
        .select("id, email, accepted_at, created_at")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data as Invite[];
    },
  });

  const admins = (members.data ?? []).filter((member) => member.roles.includes("admin"));

  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: ["workspace-members"] });
    void queryClient.invalidateQueries({ queryKey: ["admin-invites"] });
    void queryClient.invalidateQueries({ queryKey: ["audit-log"] });
  };

  const invite = async () => {
    const value = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      toast.error("Enter a valid email address.");
      return;
    }
    const existing = (members.data ?? []).find((member) => member.email?.toLowerCase() === value);
    if (existing) {
      await promote(existing);
      setEmail("");
      return;
    }
    setBusy("invite");
    const { error } = await supabase.from("admin_invites").insert({ email: value, invited_by: user?.id ?? null });
    setBusy(null);
    if (error) {
      toast.error(error.message.includes("duplicate") ? "That email is already invited." : error.message);
      return;
    }
    setEmail("");
    toast.success("Invitation recorded — they become an administrator when they sign up.");
    refresh();
  };

  const promote = async (member: Member) => {
    setBusy(member.user_id);
    const { error } = await supabase.rpc("grant_admin", { _user_id: member.user_id });
    setBusy(null);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success(`${member.email ?? "Member"} is now an administrator`);
    refresh();
  };

  const revoke = async (member: Member) => {
    if (admins.length <= 1) {
      toast.error("You cannot revoke the last remaining administrator.");
      return;
    }
    if (member.user_id === user?.id && !window.confirm("Revoke your own administrator access?")) return;
    setBusy(member.user_id);
    const { error } = await supabase.rpc("revoke_admin", { _user_id: member.user_id });
    setBusy(null);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success("Administrator access revoked");
    refresh();
  };

  const cancelInvite = async (id: string) => {
    setBusy(id);
    const { error } = await supabase.from("admin_invites").delete().eq("id", id);
    setBusy(null);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success("Invitation cancelled");
    refresh();
  };

  return (
    <AppLayout>
      <section className="mx-auto max-w-5xl px-5 py-14 lg:px-8">
        <Link to="/admin" className="inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground hover:text-primary">
          <ArrowLeft className="size-4" />Review queue
        </Link>
        <h1 className="mt-6 font-display text-4xl font-extrabold">Administrators &amp; members</h1>
        <p className="mt-3 max-w-2xl text-sm text-muted-foreground">
          Administrator access is granted only by an existing administrator, and the workspace always keeps at least one.
        </p>

        <div className="mt-10 border border-border bg-card p-6">
          <h2 className="font-display text-lg font-bold">Invite an administrator</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Already a member? They are promoted immediately. New to IYEOB? They join as an administrator when they create their account.
          </p>
          <div className="mt-4 flex flex-wrap gap-3">
            <Input
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="name@organisation.org"
              type="email"
              aria-label="Administrator email"
              className="h-11 max-w-sm"
            />
            <Button className="h-11" disabled={busy === "invite"} onClick={() => void invite()}>
              <UserPlus />Send invitation
            </Button>
          </div>

          {(invites.data ?? []).filter((row) => !row.accepted_at).length > 0 && (
            <ul className="mt-6 space-y-2 border-t border-border pt-5">
              {(invites.data ?? []).filter((row) => !row.accepted_at).map((row) => (
                <li key={row.id} className="flex flex-wrap items-center justify-between gap-3 text-sm">
                  <span className="flex items-center gap-2"><Mail className="size-4 text-muted-foreground" />{row.email}
                    <span className="text-xs text-muted-foreground">invited {new Date(row.created_at).toLocaleDateString()}</span>
                  </span>
                  <Button variant="ghost" size="sm" className="text-destructive" disabled={busy === row.id} onClick={() => void cancelInvite(row.id)}>
                    <Trash2 />Cancel
                  </Button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="mt-8 border border-border bg-card">
          <div className="border-b border-border px-6 py-4">
            <h2 className="font-display text-lg font-bold">Workspace members</h2>
            <p className="mt-1 text-xs text-muted-foreground">{admins.length} administrator{admins.length === 1 ? "" : "s"} · {(members.data ?? []).length} member{(members.data ?? []).length === 1 ? "" : "s"}</p>
          </div>
          {members.isLoading && <p className="px-6 py-8 text-sm text-muted-foreground">Loading members…</p>}
          <ul className="divide-y divide-border">
            {(members.data ?? []).map((member) => {
              const isAdminMember = member.roles.includes("admin");
              const lastAdmin = isAdminMember && admins.length <= 1;
              return (
                <li key={member.user_id} className="flex flex-wrap items-center justify-between gap-3 px-6 py-5">
                  <div>
                    <p className="font-semibold">{member.full_name || member.email}</p>
                    <p className="text-xs text-muted-foreground">{member.email} · joined {new Date(member.created_at).toLocaleDateString()}</p>
                  </div>
                  <div className="flex flex-wrap items-center gap-3">
                    <span className={`rounded-full px-3 py-1 text-[11px] font-bold uppercase tracking-wider ${isAdminMember ? "bg-primary/10 text-primary" : "bg-muted text-muted-foreground"}`}>
                      {isAdminMember ? "Administrator" : "Contributor"}
                    </span>
                    {isAdminMember ? (
                      <Button
                        variant="outline"
                        size="sm"
                        className="text-destructive"
                        disabled={busy === member.user_id || lastAdmin}
                        title={lastAdmin ? "The workspace must keep one administrator" : undefined}
                        onClick={() => void revoke(member)}
                      >
                        <ShieldMinus />Revoke admin
                      </Button>
                    ) : (
                      <Button variant="outline" size="sm" disabled={busy === member.user_id} onClick={() => void promote(member)}>
                        <ShieldCheck />Make administrator
                      </Button>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        </div>
      </section>
    </AppLayout>
  );
}
