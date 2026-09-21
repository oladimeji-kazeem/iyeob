import { useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, ScrollText } from "lucide-react";
import { useMemo, useState } from "react";

import { AppLayout } from "@/components/app-layout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/admin/audit")({
  head: () => ({
    meta: [
      { title: "Audit log | IYEOB Admin" },
      { name: "description", content: "Every dataset edit, review decision, publication change, and role change in the workspace." },
    ],
  }),
  component: AuditPage,
});

type AuditRow = {
  id: string;
  actor_id: string | null;
  actor_email: string | null;
  event_type: string;
  entity_type: string;
  entity_id: string | null;
  entity_label: string | null;
  details: Record<string, unknown>;
  created_at: string;
};

const EVENT_LABEL: Record<string, string> = {
  "submission.created": "Submission created",
  "submission.status_changed": "Review status changed",
  "submission.deleted": "Submission deleted",
  "dataset.metadata_edited": "Dataset metadata edited",
  "publication.published": "Dataset published",
  "publication.unpublished": "Dataset unpublished",
  "role.granted": "Role granted",
  "role.revoked": "Role revoked",
};

function describe(row: AuditRow) {
  const details = row.details ?? {};
  if (row.event_type === "dataset.metadata_edited") {
    const fields = Array.isArray(details["fields"]) ? (details["fields"] as string[]) : [];
    return `Fields changed: ${fields.join(", ") || "—"}`;
  }
  if (row.event_type.startsWith("submission.status") || row.event_type.startsWith("publication.")) {
    const notes = typeof details["notes"] === "string" ? details["notes"] : "";
    return `${String(details["from"] ?? "—")} → ${String(details["to"] ?? "—")}${notes ? ` · "${notes}"` : ""}`;
  }
  if (row.event_type.startsWith("role.")) {
    return `${String(details["role"] ?? "admin")}${details["reason"] ? ` · ${String(details["reason"])}` : ""}`;
  }
  return typeof details["status"] === "string" ? `Status: ${details["status"]}` : "";
}

function AuditPage() {
  const [actor, setActor] = useState("");
  const [eventType, setEventType] = useState("all");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["audit-log"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("audit_log")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) throw error;
      return data as unknown as AuditRow[];
    },
  });

  const rows = useMemo(() => {
    const fromTime = from ? new Date(`${from}T00:00:00`).getTime() : null;
    const toTime = to ? new Date(`${to}T23:59:59`).getTime() : null;
    return (data ?? []).filter((row) => {
      const time = new Date(row.created_at).getTime();
      if (fromTime && time < fromTime) return false;
      if (toTime && time > toTime) return false;
      if (eventType !== "all" && row.event_type !== eventType) return false;
      if (actor.trim() && !(row.actor_email ?? "").toLowerCase().includes(actor.trim().toLowerCase())) return false;
      return true;
    });
  }, [data, actor, eventType, from, to]);

  const eventTypes = Array.from(new Set((data ?? []).map((row) => row.event_type)));

  return (
    <AppLayout>
      <section className="mx-auto max-w-6xl px-5 py-14 lg:px-8">
        <Link to="/admin" className="inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground hover:text-primary">
          <ArrowLeft className="size-4" />Review queue
        </Link>
        <h1 className="mt-6 flex items-center gap-3 font-display text-4xl font-extrabold"><ScrollText className="size-8 text-primary" />Audit log</h1>
        <p className="mt-3 max-w-2xl text-sm text-muted-foreground">
          A permanent record of dataset edits, review decisions, publication changes, and role changes.
        </p>

        <div className="mt-9 grid gap-3 border border-border bg-card p-4 sm:grid-cols-2 lg:grid-cols-4">
          <Input value={actor} onChange={(event) => setActor(event.target.value)} placeholder="Filter by actor email" aria-label="Filter by actor" className="h-10" />
          <Select value={eventType} onValueChange={setEventType}>
            <SelectTrigger className="h-10"><SelectValue placeholder="Event type" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All event types</SelectItem>
              {eventTypes.map((type) => <SelectItem key={type} value={type}>{EVENT_LABEL[type] ?? type}</SelectItem>)}
            </SelectContent>
          </Select>
          <Input type="date" value={from} onChange={(event) => setFrom(event.target.value)} aria-label="From date" className="h-10" />
          <Input type="date" value={to} onChange={(event) => setTo(event.target.value)} aria-label="To date" className="h-10" />
        </div>

        <div className="mt-4 flex items-center justify-between gap-3">
          <p className="text-sm text-muted-foreground">{rows.length} event{rows.length === 1 ? "" : "s"}</p>
          {(actor || eventType !== "all" || from || to) && (
            <Button variant="ghost" size="sm" onClick={() => { setActor(""); setEventType("all"); setFrom(""); setTo(""); }}>Clear filters</Button>
          )}
        </div>

        <div className="mt-4 border border-border bg-card">
          {isLoading && <p className="px-6 py-10 text-sm text-muted-foreground">Loading audit events…</p>}
          {!isLoading && !rows.length && <p className="px-6 py-16 text-center text-sm text-muted-foreground">No events match these filters.</p>}
          <ul className="divide-y divide-border">
            {rows.map((row) => (
              <li key={row.id} className="px-6 py-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <span className="font-semibold">{EVENT_LABEL[row.event_type] ?? row.event_type}</span>
                  <span className="text-xs text-muted-foreground">{new Date(row.created_at).toLocaleString()}</span>
                </div>
                <p className="mt-1 text-sm text-muted-foreground">
                  <strong className="text-foreground">{row.entity_label ?? row.entity_type}</strong>
                  {describe(row) ? ` — ${describe(row)}` : ""}
                </p>
                <p className="mt-1 text-xs text-muted-foreground">by {row.actor_email ?? "system"}</p>
              </li>
            ))}
          </ul>
        </div>
      </section>
    </AppLayout>
  );
}
