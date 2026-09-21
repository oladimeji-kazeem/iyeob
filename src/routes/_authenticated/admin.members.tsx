import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import {
  ArrowLeft,
  Building2,
  Check,
  Clock,
  Key,
  Mail,
  MoreVertical,
  Plus,
  RefreshCw,
  Search,
  Shield,
  ShieldAlert,
  ShieldCheck,
  Trash2,
  UserCheck,
  UserPlus,
  Users,
  UserX,
  X,
} from "lucide-react";
import { useMemo, useState } from "react";
import { toast } from "sonner";

import { AppLayout } from "@/components/app-layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";

export const Route = createFileRoute("/_authenticated/admin/members")({
  head: () => ({
    meta: [
      { title: "Identity, Roles & Access Governance | IYEOB Admin" },
      {
        name: "description",
        content:
          "Enterprise user directory, multi-role assignment, permission matrix, organisation affiliations, and access status controls.",
      },
    ],
  }),
  component: MembersPage,
});

export type SystemRole =
  | "ADMIN"
  | "PUBLISHER"
  | "REVIEWER"
  | "DATA_EDITOR"
  | "EDITOR"
  | "RESEARCHER"
  | "DEVELOPER"
  | "USER";

export type UserStatus = "ACTIVE" | "SUSPENDED" | "PENDING";

export type FullMember = {
  user_id: string;
  email: string | null;
  display_name: string | null;
  status: UserStatus;
  roles: string[];
  permissions: string[];
  organisation_id: string | null;
  organisation_name: string | null;
  created_at: string;
  last_login_at: string | null;
  email_verified: boolean;
};

export type Invite = {
  id: string;
  email: string;
  role?: string | null;
  accepted_at: string | null;
  created_at: string;
};

const ALL_ROLES: { name: SystemRole; label: string; description: string; badgeColor: string }[] = [
  {
    name: "ADMIN",
    label: "Administrator",
    description: "Full system administration, access management, and security controls.",
    badgeColor: "bg-purple-500/15 text-purple-600 dark:text-purple-400 border-purple-500/30",
  },
  {
    name: "PUBLISHER",
    label: "Publisher",
    description: "Authority to validate, approve, and publicly publish synthetic datasets.",
    badgeColor: "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border-emerald-500/30",
  },
  {
    name: "REVIEWER",
    label: "Reviewer",
    description: "Conducts data quality checks, editorial audits, and methodology reviews.",
    badgeColor: "bg-amber-500/15 text-amber-600 dark:text-amber-400 border-amber-500/30",
  },
  {
    name: "DATA_EDITOR",
    label: "Data Editor",
    description: "Creates and curates synthetic datasets, metadata dictionaries, and CMS sections.",
    badgeColor: "bg-blue-500/15 text-blue-600 dark:text-blue-400 border-blue-500/30",
  },
  {
    name: "RESEARCHER",
    label: "Researcher",
    description: "Full exploratory querying, benchmark evaluations, and research notebook downloads.",
    badgeColor: "bg-cyan-500/15 text-cyan-600 dark:text-cyan-400 border-cyan-500/30",
  },
  {
    name: "DEVELOPER",
    label: "Developer",
    description: "API access, synthetic integration keys, schema consumers, and code snippets.",
    badgeColor: "bg-indigo-500/15 text-indigo-600 dark:text-indigo-400 border-indigo-500/30",
  },
  {
    name: "USER",
    label: "Standard User",
    description: "Browsing, public dataset downloads, bookmarking, and community submissions.",
    badgeColor: "bg-muted text-muted-foreground border-border",
  },
];

const PERMISSIONS_CATALOGUE = [
  { key: "dataset:create", label: "Create Datasets", category: "Datasets" },
  { key: "dataset:read", label: "Read Datasets", category: "Datasets" },
  { key: "dataset:update", label: "Update Datasets", category: "Datasets" },
  { key: "dataset:delete", label: "Archive/Delete Datasets", category: "Datasets" },
  { key: "dataset:publish", label: "Publish Datasets", category: "Publishing" },
  { key: "dataset:quality_check", label: "Run Quality Checks", category: "Quality" },
  { key: "dataset:review", label: "Review Submissions", category: "Publishing" },
  { key: "user:manage", label: "Manage Users & Roles", category: "Administration" },
  { key: "organisation:manage", label: "Manage Organisations", category: "Administration" },
  { key: "analytics:read", label: "View Analytics", category: "Intelligence" },
  { key: "audit:read", label: "View Audit Logs", category: "Intelligence" },
];

const DEFAULT_ROLE_PERMISSIONS: Record<string, string[]> = {
  ADMIN: [
    "dataset:create",
    "dataset:read",
    "dataset:update",
    "dataset:delete",
    "dataset:publish",
    "dataset:quality_check",
    "dataset:review",
    "user:manage",
    "organisation:manage",
    "analytics:read",
    "audit:read",
  ],
  PUBLISHER: ["dataset:read", "dataset:publish", "dataset:quality_check", "dataset:review", "analytics:read"],
  REVIEWER: ["dataset:read", "dataset:quality_check", "dataset:review", "analytics:read"],
  DATA_EDITOR: ["dataset:create", "dataset:read", "dataset:update", "dataset:quality_check"],
  RESEARCHER: ["dataset:read", "analytics:read"],
  DEVELOPER: ["dataset:read"],
  USER: ["dataset:read"],
};

function MembersPage() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  // Search & Filter State
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<string>("ALL");
  const [statusFilter, setStatusFilter] = useState<string>("ALL");

  // Dialog State
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteRole, setInviteRole] = useState<SystemRole>("DATA_EDITOR");
  const [activeMember, setActiveMember] = useState<FullMember | null>(null);
  const [roleModalMember, setRoleModalMember] = useState<FullMember | null>(null);
  const [selectedRoles, setSelectedRoles] = useState<string[]>([]);
  const [permissionModalMember, setPermissionModalMember] = useState<FullMember | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  // 1. Fetch Members Query
  const membersQuery = useQuery({
    queryKey: ["workspace-members-full"],
    queryFn: async (): Promise<FullMember[]> => {
      // First attempt the comprehensive RPC function
      try {
        const { data, error } = await supabase.rpc("list_workspace_members_full");
        if (!error && data && data.length > 0) {
          return data as FullMember[];
        }
      } catch {
        // Continue to fallback
      }

      // Fallback: Use standard list_workspace_members RPC or direct user table join
      const { data: legacyData, error: legacyError } = await supabase.rpc("list_workspace_members");
      if (legacyError) {
        // Final fallback: fetch profiles / users
        const { data: profiles, error: pErr } = await supabase.from("profiles").select("*");
        if (pErr) throw pErr;
        return (profiles ?? []).map((p) => ({
          user_id: p.id,
          email: p.email,
          display_name: p.full_name ?? p.email,
          status: "ACTIVE" as UserStatus,
          roles: ["USER"],
          permissions: ["dataset:read"],
          organisation_id: null,
          organisation_name: null,
          created_at: p.created_at,
          last_login_at: null,
          email_verified: true,
        }));
      }

      return (legacyData ?? []).map((m: { user_id: string; email: string | null; full_name: string | null; roles: string[]; created_at: string }) => {
        const roles = (m.roles ?? []).map((r) => r.toUpperCase());
        if (!roles.length) roles.push("USER");
        const permissions = Array.from(new Set(roles.flatMap((r) => DEFAULT_ROLE_PERMISSIONS[r] ?? [])));
        return {
          user_id: m.user_id,
          email: m.email,
          display_name: m.full_name || m.email,
          status: "ACTIVE" as UserStatus,
          roles,
          permissions,
          organisation_id: null,
          organisation_name: null,
          created_at: m.created_at,
          last_login_at: null,
          email_verified: true,
        };
      });
    },
  });

  // 2. Fetch Invites Query
  const invitesQuery = useQuery({
    queryKey: ["admin-invites"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("admin_invites")
        .select("id, email, accepted_at, created_at, role")
        .order("created_at", { ascending: false });
      if (error) {
        // Fallback without role column if column not yet added
        const { data: fallback, error: fErr } = await supabase
          .from("admin_invites")
          .select("id, email, accepted_at, created_at")
          .order("created_at", { ascending: false });
        if (fErr) throw fErr;
        return fallback as Invite[];
      }
      return data as Invite[];
    },
  });

  const members = useMemo(() => membersQuery.data ?? [], [membersQuery.data]);
  const invites = useMemo(() => invitesQuery.data ?? [], [invitesQuery.data]);

  // Compute Metrics
  const stats = useMemo(() => {
    const total = members.length;
    const admins = members.filter((m) => m.roles.some((r) => r.toUpperCase() === "ADMIN")).length;
    const editors = members.filter((m) =>
      m.roles.some((r) => ["PUBLISHER", "REVIEWER", "DATA_EDITOR", "EDITOR"].includes(r.toUpperCase())),
    ).length;
    const suspended = members.filter((m) => m.status === "SUSPENDED").length;
    return { total, admins, editors, suspended };
  }, [members]);

  // Filtered Members
  const filteredMembers = useMemo(() => {
    return members.filter((m) => {
      const matchesSearch =
        !search ||
        (m.email ?? "").toLowerCase().includes(search.toLowerCase()) ||
        (m.display_name ?? "").toLowerCase().includes(search.toLowerCase()) ||
        (m.organisation_name ?? "").toLowerCase().includes(search.toLowerCase());

      const matchesRole =
        roleFilter === "ALL" || m.roles.some((r) => r.toUpperCase() === roleFilter.toUpperCase());

      const matchesStatus =
        statusFilter === "ALL" || (m.status ?? "ACTIVE").toUpperCase() === statusFilter.toUpperCase();

      return matchesSearch && matchesRole && matchesStatus;
    });
  }, [members, search, roleFilter, statusFilter]);

  const refreshAll = () => {
    void queryClient.invalidateQueries({ queryKey: ["workspace-members-full"] });
    void queryClient.invalidateQueries({ queryKey: ["admin-invites"] });
    void queryClient.invalidateQueries({ queryKey: ["audit-log"] });
  };

  // Action: Send Invitation with Role Preset
  const handleSendInvite = async () => {
    const value = inviteEmail.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      toast.error("Please enter a valid email address.");
      return;
    }

    setBusy("invite");
    const { error } = await supabase.from("admin_invites").insert({
      email: value,
      invited_by: user?.id ?? null,
      role: inviteRole.toLowerCase(),
    });
    setBusy(null);

    if (error) {
      toast.error(error.message.includes("duplicate") ? "That email is already invited." : error.message);
      return;
    }

    setInviteEmail("");
    toast.success(`Invitation sent to ${value} with role ${inviteRole}`);
    refreshAll();
  };

  // Action: Cancel Invite
  const handleCancelInvite = async (id: string) => {
    setBusy(id);
    const { error } = await supabase.from("admin_invites").delete().eq("id", id);
    setBusy(null);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success("Invitation cancelled");
    refreshAll();
  };

  // Open Role Edit Dialog
  const openRoleModal = (member: FullMember) => {
    setRoleModalMember(member);
    setSelectedRoles([...member.roles.map((r) => r.toUpperCase())]);
  };

  // Action: Save Roles
  const handleSaveRoles = async () => {
    if (!roleModalMember) return;
    const targetUserId = roleModalMember.user_id;

    // Check last admin safeguard
    const isCurrentlyAdmin = roleModalMember.roles.some((r) => r.toUpperCase() === "ADMIN");
    const willBeAdmin = selectedRoles.includes("ADMIN");
    if (isCurrentlyAdmin && !willBeAdmin && stats.admins <= 1) {
      toast.error("You cannot revoke the last remaining administrator in the workspace.");
      return;
    }

    setBusy("roles-save");
    try {
      // Find roles to add and roles to remove
      const currentRolesUpper = roleModalMember.roles.map((r) => r.toUpperCase());
      const rolesToAdd = selectedRoles.filter((r) => !currentRolesUpper.includes(r));
      const rolesToRemove = currentRolesUpper.filter((r) => !selectedRoles.includes(r));

      for (const r of rolesToAdd) {
        const { error } = await supabase.rpc("assign_user_role", {
          _user_id: targetUserId,
          _role: r,
        });
        if (error) {
          // Fallback direct role insertion
          if (r === "ADMIN") {
            await supabase.rpc("grant_admin", { _user_id: targetUserId });
          }
        }
      }

      for (const r of rolesToRemove) {
        const { error } = await supabase.rpc("remove_user_role", {
          _user_id: targetUserId,
          _role: r,
        });
        if (error) {
          if (r === "ADMIN") {
            await supabase.rpc("revoke_admin", { _user_id: targetUserId });
          }
        }
      }

      toast.success(`Roles updated for ${roleModalMember.display_name}`);
      setRoleModalMember(null);
      refreshAll();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to update roles.");
    } finally {
      setBusy(null);
    }
  };

  // Action: Toggle User Access Status (Active / Suspended / Pending)
  const handleChangeStatus = async (member: FullMember, newStatus: UserStatus) => {
    if (member.user_id === user?.id && newStatus === "SUSPENDED") {
      toast.error("You cannot suspend your own administrative account.");
      return;
    }

    setBusy(`status-${member.user_id}`);
    try {
      const { error } = await supabase.rpc("set_user_status", {
        _user_id: member.user_id,
        _status: newStatus,
      });

      if (error) {
        // Fallback update on public.users
        const { error: directErr } = await supabase
          .from("users")
          .update({ status: newStatus as any, updated_at: new Date().toISOString() })
          .eq("id", member.user_id);
        if (directErr) throw directErr;
      }

      toast.success(`Member status changed to ${newStatus}`);
      refreshAll();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to change user status.");
    } finally {
      setBusy(null);
    }
  };

  return (
    <AppLayout>
      <section className="mx-auto max-w-7xl px-5 py-12 lg:px-8">
        {/* Top Header */}
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <Link
              to="/admin"
              className="inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-muted-foreground transition-colors hover:text-primary"
            >
              <ArrowLeft className="size-4" /> Review Queue
            </Link>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" asChild>
              <Link to="/admin/analytics">Analytics</Link>
            </Button>
            <Button variant="outline" size="sm" asChild>
              <Link to="/admin/audit">Audit Trail</Link>
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={refreshAll}
              disabled={membersQuery.isFetching}
              title="Refresh member lists"
            >
              <RefreshCw className={`size-3.5 ${membersQuery.isFetching ? "animate-spin" : ""}`} />
            </Button>
          </div>
        </div>

        <div className="mt-4">
          <span className="text-xs font-extrabold uppercase tracking-[0.2em] text-primary">
            Governance &amp; Identity
          </span>
          <h1 className="mt-2 font-display text-4xl font-extrabold tracking-tight">
            Members &amp; Access Controls
          </h1>
          <p className="mt-2 max-w-3xl text-sm text-muted-foreground">
            Privilege management for IYEOB African Data &amp; AI Infrastructure. Manage multi-role
            authorizations, inspect cryptographic permission sets, invite specialized teams, and enforce
            access statuses.
          </p>
        </div>

        {/* Executive Metric Cards */}
        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="border border-border bg-card p-5 shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">
                Total Members
              </span>
              <Users className="size-4 text-muted-foreground" />
            </div>
            <div className="mt-2 font-display text-3xl font-extrabold">{stats.total}</div>
            <p className="mt-1 text-xs text-muted-foreground">Registered repository contributors</p>
          </div>

          <div className="border border-border bg-card p-5 shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">
                Administrators
              </span>
              <ShieldCheck className="size-4 text-purple-500" />
            </div>
            <div className="mt-2 font-display text-3xl font-extrabold text-purple-600 dark:text-purple-400">
              {stats.admins}
            </div>
            <p className="mt-1 text-xs text-muted-foreground">Privileged system operators</p>
          </div>

          <div className="border border-border bg-card p-5 shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">
                Editorial &amp; Review
              </span>
              <Shield className="size-4 text-emerald-500" />
            </div>
            <div className="mt-2 font-display text-3xl font-extrabold text-emerald-600 dark:text-emerald-400">
              {stats.editors}
            </div>
            <p className="mt-1 text-xs text-muted-foreground">Publishers, editors &amp; reviewers</p>
          </div>

          <div className="border border-border bg-card p-5 shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">
                Restricted / Suspended
              </span>
              <ShieldAlert className="size-4 text-destructive" />
            </div>
            <div className="mt-2 font-display text-3xl font-extrabold text-destructive">
              {stats.suspended}
            </div>
            <p className="mt-1 text-xs text-muted-foreground">Revoked login privileges</p>
          </div>
        </div>

        {/* Main Tabbed Interface */}
        <div className="mt-8">
          <Tabs defaultValue="directory" className="space-y-6">
            <TabsList className="bg-muted p-1">
              <TabsTrigger value="directory" className="gap-2 font-semibold">
                <Users className="size-4" /> Member Directory ({members.length})
              </TabsTrigger>
              <TabsTrigger value="matrix" className="gap-2 font-semibold">
                <Key className="size-4" /> Role &amp; Permission Matrix
              </TabsTrigger>
              <TabsTrigger value="invitations" className="gap-2 font-semibold">
                <Mail className="size-4" /> Invitations (
                {invites.filter((i) => !i.accepted_at).length})
              </TabsTrigger>
            </TabsList>

            {/* TAB 1: MEMBER DIRECTORY */}
            <TabsContent value="directory" className="space-y-6">
              {/* Filter & Search Bar */}
              <div className="flex flex-wrap items-center justify-between gap-4 border border-border bg-card p-4">
                <div className="relative flex-1 min-w-[240px] max-w-md">
                  <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                  <Input
                    placeholder="Search by name, email, or organisation..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    className="pl-9 h-10"
                  />
                  {search && (
                    <button
                      onClick={() => setSearch("")}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-muted-foreground hover:text-foreground"
                    >
                      Clear
                    </button>
                  )}
                </div>

                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-2">
                    <Label className="text-xs text-muted-foreground">Role:</Label>
                    <Select value={roleFilter} onValueChange={setRoleFilter}>
                      <SelectTrigger className="h-10 w-36">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="ALL">All Roles</SelectItem>
                        {ALL_ROLES.map((r) => (
                          <SelectItem key={r.name} value={r.name}>
                            {r.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="flex items-center gap-2">
                    <Label className="text-xs text-muted-foreground">Status:</Label>
                    <Select value={statusFilter} onValueChange={setStatusFilter}>
                      <SelectTrigger className="h-10 w-32">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="ALL">All Status</SelectItem>
                        <SelectItem value="ACTIVE">Active</SelectItem>
                        <SelectItem value="PENDING">Pending</SelectItem>
                        <SelectItem value="SUSPENDED">Suspended</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              </div>

              {/* Members Table */}
              <div className="border border-border bg-card overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-sm">
                    <thead className="bg-muted/60 text-xs font-bold uppercase tracking-wider text-muted-foreground border-b border-border">
                      <tr>
                        <th className="px-5 py-3.5">User Identity</th>
                        <th className="px-4 py-3.5">Assigned Roles</th>
                        <th className="px-4 py-3.5">Organisation</th>
                        <th className="px-4 py-3.5">Access Status</th>
                        <th className="px-4 py-3.5">Joined / Active</th>
                        <th className="px-5 py-3.5 text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-border">
                      {membersQuery.isLoading && (
                        <tr>
                          <td colSpan={6} className="py-12 text-center text-muted-foreground">
                            Loading workspace directory...
                          </td>
                        </tr>
                      )}

                      {!membersQuery.isLoading && filteredMembers.length === 0 && (
                        <tr>
                          <td colSpan={6} className="py-16 text-center text-muted-foreground">
                            <Users className="mx-auto size-8 text-muted-foreground/50 mb-2" />
                            <p className="font-semibold">No members match the active filters.</p>
                            <Button
                              variant="link"
                              size="sm"
                              onClick={() => {
                                setSearch("");
                                setRoleFilter("ALL");
                                setStatusFilter("ALL");
                              }}
                            >
                              Reset filters
                            </Button>
                          </td>
                        </tr>
                      )}

                      {filteredMembers.map((member) => {
                        const isSelf = member.user_id === user?.id;
                        const status = member.status || "ACTIVE";

                        return (
                          <tr
                            key={member.user_id}
                            className={`transition-colors hover:bg-muted/30 ${
                              status === "SUSPENDED" ? "opacity-60 bg-destructive/5" : ""
                            }`}
                          >
                            {/* User Column */}
                            <td className="px-5 py-4">
                              <div className="flex items-center gap-3">
                                <div className="flex size-9 shrink-0 items-center justify-center rounded-full bg-primary/10 font-display font-bold text-primary text-xs">
                                  {(member.display_name || member.email || "U")
                                    .slice(0, 2)
                                    .toUpperCase()}
                                </div>
                                <div>
                                  <div className="flex items-center gap-1.5 font-semibold text-foreground">
                                    {member.display_name || "Unnamed Member"}
                                    {isSelf && (
                                      <Badge variant="outline" className="text-[10px] py-0 px-1">
                                        You
                                      </Badge>
                                    )}
                                  </div>
                                  <div className="text-xs text-muted-foreground">{member.email}</div>
                                </div>
                              </div>
                            </td>

                            {/* Roles Column */}
                            <td className="px-4 py-4">
                              <div className="flex flex-wrap gap-1.5 max-w-xs">
                                {member.roles.map((roleStr) => {
                                  const roleDef = ALL_ROLES.find(
                                    (r) => r.name.toUpperCase() === roleStr.toUpperCase(),
                                  );
                                  return (
                                    <Badge
                                      key={roleStr}
                                      variant="outline"
                                      className={`text-[11px] font-semibold border ${
                                        roleDef?.badgeColor || "bg-muted text-muted-foreground"
                                      }`}
                                    >
                                      {roleDef?.label || roleStr}
                                    </Badge>
                                  );
                                })}
                              </div>
                            </td>

                            {/* Organisation Column */}
                            <td className="px-4 py-4 text-xs text-muted-foreground">
                              {member.organisation_name ? (
                                <span className="inline-flex items-center gap-1.5 font-medium text-foreground">
                                  <Building2 className="size-3.5 text-primary shrink-0" />
                                  {member.organisation_name}
                                </span>
                              ) : (
                                <span className="italic text-muted-foreground/60">Independent</span>
                              )}
                            </td>

                            {/* Status Column */}
                            <td className="px-4 py-4">
                              <span
                                className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                                  status === "ACTIVE"
                                    ? "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400"
                                    : status === "SUSPENDED"
                                    ? "bg-destructive/10 text-destructive"
                                    : "bg-amber-500/10 text-amber-600 dark:text-amber-400"
                                }`}
                              >
                                <span
                                  className={`size-1.5 rounded-full ${
                                    status === "ACTIVE"
                                      ? "bg-emerald-500"
                                      : status === "SUSPENDED"
                                      ? "bg-destructive"
                                      : "bg-amber-500"
                                  }`}
                                />
                                {status}
                              </span>
                            </td>

                            {/* Dates Column */}
                            <td className="px-4 py-4 text-xs text-muted-foreground">
                              <div>Joined {new Date(member.created_at).toLocaleDateString()}</div>
                              {member.last_login_at && (
                                <div className="text-[11px] text-muted-foreground/70 flex items-center gap-1 mt-0.5">
                                  <Clock className="size-3" /> Active{" "}
                                  {new Date(member.last_login_at).toLocaleDateString()}
                                </div>
                              )}
                            </td>

                            {/* Actions Column */}
                            <td className="px-5 py-4 text-right">
                              <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                  <Button variant="ghost" size="sm" className="size-8 p-0">
                                    <MoreVertical className="size-4" />
                                  </Button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="end" className="w-48">
                                  <DropdownMenuLabel>Access Governance</DropdownMenuLabel>
                                  <DropdownMenuItem onClick={() => openRoleModal(member)}>
                                    <Shield className="mr-2 size-4 text-primary" />
                                    Manage Roles
                                  </DropdownMenuItem>
                                  <DropdownMenuItem onClick={() => setPermissionModalMember(member)}>
                                    <Key className="mr-2 size-4 text-amber-500" />
                                    View Permissions
                                  </DropdownMenuItem>
                                  <DropdownMenuSeparator />
                                  <DropdownMenuLabel className="text-xs text-muted-foreground font-normal">
                                    Account Status
                                  </DropdownMenuLabel>
                                  {status !== "ACTIVE" && (
                                    <DropdownMenuItem
                                      onClick={() => void handleChangeStatus(member, "ACTIVE")}
                                    >
                                      <UserCheck className="mr-2 size-4 text-emerald-500" />
                                      Mark as Active
                                    </DropdownMenuItem>
                                  )}
                                  {status !== "SUSPENDED" && !isSelf && (
                                    <DropdownMenuItem
                                      onClick={() => void handleChangeStatus(member, "SUSPENDED")}
                                      className="text-destructive focus:text-destructive"
                                    >
                                      <UserX className="mr-2 size-4 text-destructive" />
                                      Suspend Access
                                    </DropdownMenuItem>
                                  )}
                                  {status !== "PENDING" && !isSelf && (
                                    <DropdownMenuItem
                                      onClick={() => void handleChangeStatus(member, "PENDING")}
                                    >
                                      <Clock className="mr-2 size-4 text-amber-500" />
                                      Mark as Pending
                                    </DropdownMenuItem>
                                  )}
                                </DropdownMenuContent>
                              </DropdownMenu>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            </TabsContent>

            {/* TAB 2: ROLE & PERMISSION MATRIX */}
            <TabsContent value="matrix" className="space-y-6">
              <div className="border border-border bg-card p-6">
                <h2 className="font-display text-xl font-bold">Cryptographic Privilege Matrix</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  The IYEOB authorization framework assigns granular operational permissions to defined
                  roles. Users inherit the union of all privileges granted across their assigned roles.
                </p>

                <div className="mt-6 overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead className="bg-muted text-muted-foreground uppercase font-bold border-b border-border">
                      <tr>
                        <th className="px-4 py-3 min-w-[200px]">Permission Name</th>
                        <th className="px-3 py-3 text-center">Category</th>
                        {ALL_ROLES.map((role) => (
                          <th key={role.name} className="px-3 py-3 text-center">
                            {role.label}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-border">
                      {PERMISSIONS_CATALOGUE.map((perm) => (
                        <tr key={perm.key} className="hover:bg-muted/30">
                          <td className="px-4 py-3 font-semibold font-mono text-foreground">
                            {perm.key}
                            <span className="block font-sans font-normal text-muted-foreground text-[11px]">
                              {perm.label}
                            </span>
                          </td>
                          <td className="px-3 py-3 text-center">
                            <Badge variant="outline" className="text-[10px]">
                              {perm.category}
                            </Badge>
                          </td>
                          {ALL_ROLES.map((role) => {
                            const isGranted = (DEFAULT_ROLE_PERMISSIONS[role.name] ?? []).includes(
                              perm.key,
                            );
                            return (
                              <td key={role.name} className="px-3 py-3 text-center">
                                {isGranted ? (
                                  <span className="inline-flex size-6 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-600 dark:text-emerald-400">
                                    <Check className="size-3.5" />
                                  </span>
                                ) : (
                                  <span className="text-muted-foreground/30">—</span>
                                )}
                              </td>
                            );
                          })}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </TabsContent>

            {/* TAB 3: INVITATIONS */}
            <TabsContent value="invitations" className="space-y-6">
              {/* Send Invitation Card */}
              <div className="border border-border bg-card p-6">
                <h2 className="font-display text-lg font-bold">Invite a Contributor with Preset Role</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  Send an official workspace invitation. When the user registers with this email address,
                  the chosen authorization role is automatically granted during sign-up.
                </p>

                <div className="mt-5 grid gap-4 sm:grid-cols-3 max-w-2xl">
                  <div className="sm:col-span-2 space-y-1.5">
                    <Label htmlFor="inviteEmail" className="text-xs">
                      Email Address
                    </Label>
                    <Input
                      id="inviteEmail"
                      type="email"
                      placeholder="specialist@african-institution.org"
                      value={inviteEmail}
                      onChange={(e) => setInviteEmail(e.target.value)}
                      className="h-10"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <Label htmlFor="inviteRole" className="text-xs">
                      Initial Role Preset
                    </Label>
                    <Select
                      value={inviteRole}
                      onValueChange={(val) => setInviteRole(val as SystemRole)}
                    >
                      <SelectTrigger id="inviteRole" className="h-10">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {ALL_ROLES.filter((r) => r.name !== "USER").map((r) => (
                          <SelectItem key={r.name} value={r.name}>
                            {r.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <div className="mt-4">
                  <Button
                    onClick={handleSendInvite}
                    disabled={busy === "invite" || !inviteEmail.trim()}
                    className="gap-2"
                  >
                    <UserPlus className="size-4" /> Send Invitation
                  </Button>
                </div>
              </div>

              {/* Pending Invites List */}
              <div className="border border-border bg-card">
                <div className="border-b border-border px-6 py-4">
                  <h3 className="font-display text-base font-bold">Pending Invitations</h3>
                  <p className="text-xs text-muted-foreground">
                    Awaiting account registration on IYEOB
                  </p>
                </div>

                {invitesQuery.isLoading && (
                  <p className="px-6 py-8 text-sm text-muted-foreground">Loading invitations...</p>
                )}

                {!invitesQuery.isLoading && invites.filter((i) => !i.accepted_at).length === 0 && (
                  <div className="px-6 py-12 text-center text-sm text-muted-foreground">
                    No pending invitations. All invitations have been claimed or none have been sent.
                  </div>
                )}

                <ul className="divide-y divide-border">
                  {invites
                    .filter((row) => !row.accepted_at)
                    .map((invite) => (
                      <li
                        key={invite.id}
                        className="flex flex-wrap items-center justify-between gap-4 px-6 py-4"
                      >
                        <div className="flex items-center gap-3">
                          <div className="flex size-8 items-center justify-center rounded-full bg-primary/10 text-primary">
                            <Mail className="size-4" />
                          </div>
                          <div>
                            <p className="font-semibold text-sm">{invite.email}</p>
                            <p className="text-xs text-muted-foreground">
                              Invited {new Date(invite.created_at).toLocaleDateString()}
                            </p>
                          </div>
                        </div>

                        <div className="flex items-center gap-3">
                          {invite.role && (
                            <Badge variant="outline" className="uppercase text-[10px] font-bold">
                              {invite.role}
                            </Badge>
                          )}
                          <Button
                            variant="ghost"
                            size="sm"
                            className="text-destructive hover:bg-destructive/10"
                            disabled={busy === invite.id}
                            onClick={() => void handleCancelInvite(invite.id)}
                          >
                            <Trash2 className="size-3.5 mr-1" /> Cancel
                          </Button>
                        </div>
                      </li>
                    ))}
                </ul>
              </div>
            </TabsContent>
          </Tabs>
        </div>

        {/* DIALOG 1: MANAGE ROLES */}
        {roleModalMember && (
          <Dialog open={Boolean(roleModalMember)} onOpenChange={() => setRoleModalMember(null)}>
            <DialogContent className="max-w-md">
              <DialogHeader>
                <DialogTitle className="font-display text-xl font-bold">
                  Modify Authorizations
                </DialogTitle>
                <DialogDescription>
                  Configure system roles for{" "}
                  <strong className="text-foreground">
                    {roleModalMember.display_name || roleModalMember.email}
                  </strong>
                  .
                </DialogDescription>
              </DialogHeader>

              <div className="mt-4 space-y-3">
                {ALL_ROLES.map((role) => {
                  const isChecked = selectedRoles.includes(role.name);
                  return (
                    <label
                      key={role.name}
                      className={`flex items-start gap-3 rounded-md border p-3 cursor-pointer transition-colors ${
                        isChecked
                          ? "border-primary bg-primary/5"
                          : "border-border hover:bg-muted/40"
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={isChecked}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedRoles([...selectedRoles, role.name]);
                          } else {
                            setSelectedRoles(selectedRoles.filter((r) => r !== role.name));
                          }
                        }}
                        className="mt-0.5 size-4 rounded border-border text-primary focus:ring-primary"
                      />
                      <div className="flex-1">
                        <div className="flex items-center justify-between">
                          <span className="font-semibold text-sm">{role.label}</span>
                          <span className="font-mono text-[10px] text-muted-foreground">
                            {role.name}
                          </span>
                        </div>
                        <p className="mt-0.5 text-xs text-muted-foreground">{role.description}</p>
                      </div>
                    </label>
                  );
                })}
              </div>

              <DialogFooter className="mt-6">
                <Button variant="outline" onClick={() => setRoleModalMember(null)}>
                  Cancel
                </Button>
                <Button onClick={handleSaveRoles} disabled={busy === "roles-save"}>
                  Save Roles
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        )}

        {/* DIALOG 2: PERMISSIONS INSPECTOR */}
        {permissionModalMember && (
          <Dialog
            open={Boolean(permissionModalMember)}
            onOpenChange={() => setPermissionModalMember(null)}
          >
            <DialogContent className="max-w-lg">
              <DialogHeader>
                <DialogTitle className="font-display text-xl font-bold">
                  Granted Cryptographic Privileges
                </DialogTitle>
                <DialogDescription>
                  Active permissions for{" "}
                  <strong className="text-foreground">
                    {permissionModalMember.display_name || permissionModalMember.email}
                  </strong>{" "}
                  across all assigned roles (
                  {permissionModalMember.roles.join(", ")}).
                </DialogDescription>
              </DialogHeader>

              <div className="mt-4 space-y-2 max-h-[360px] overflow-y-auto pr-1">
                {PERMISSIONS_CATALOGUE.map((perm) => {
                  const hasPerm = permissionModalMember.permissions.includes(perm.key);
                  return (
                    <div
                      key={perm.key}
                      className={`flex items-center justify-between p-2.5 rounded-md border text-xs ${
                        hasPerm
                          ? "border-emerald-500/30 bg-emerald-500/5 text-foreground"
                          : "border-border/40 text-muted-foreground/50"
                      }`}
                    >
                      <div>
                        <span className="font-mono font-bold">{perm.key}</span>
                        <p className="text-[11px] text-muted-foreground">{perm.label}</p>
                      </div>
                      <Badge
                        variant="outline"
                        className={
                          hasPerm
                            ? "border-emerald-500 text-emerald-600 dark:text-emerald-400"
                            : "opacity-40"
                        }
                      >
                        {hasPerm ? "Granted" : "Restricted"}
                      </Badge>
                    </div>
                  );
                })}
              </div>

              <DialogFooter className="mt-4">
                <Button onClick={() => setPermissionModalMember(null)}>Close</Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        )}
      </section>
    </AppLayout>
  );
}
