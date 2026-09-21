import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { BarChart3, Check, Eye, ScrollText, Trash2, Users, X } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

import { AppLayout } from "@/components/app-layout";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";
import { STATUS_LABEL, STATUS_STYLE, type SubmissionRow, type SubmissionStatus } from "@/lib/submissions";

export const Route = createFileRoute("/_authenticated/admin/")({
  head: () => ({ meta: [{ title: "Submission review queue | IYEOB Admin" }, { name: "description", content: "Review, approve, reject, and manage synthetic dataset submissions." }] }),
  component: AdminPage,
});

function AdminPage() {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<"pending" | SubmissionStatus | "all">("pending");
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-submissions"],
    queryFn: async () => {
      const { data, error } = await supabase.from("dataset_submissions").select("*").order("updated_at", { ascending: false });
      if (error) throw error;
      return data as SubmissionRow[];
    },
  });

  const visible = (data ?? []).filter((row) =>
    filter === "all" ? true : filter === "pending" ? row.status === "submitted" || row.status === "under_review" : row.status === filter,
  );

  const setStatus = async (row: SubmissionRow, status: SubmissionStatus) => {
    const note = notes[row.id]?.trim() ?? "";
    if (status === "rejected" && !note) { toast.error("Add a reason before rejecting."); return; }
    setBusy(row.id);
    const { error } = await supabase
      .from("dataset_submissions")
      .update({
        status,
        review_notes: note || row.review_notes,
        reviewed_by: user?.id ?? null,
        reviewed_at: new Date().toISOString(),
      })
      .eq("id", row.id);
    setBusy(null);
    if (error) { toast.error(error.message); return; }
    toast.success(`Marked ${STATUS_LABEL[status].toLowerCase()}`);
    setNotes((prev) => ({ ...prev, [row.id]: "" }));
    void queryClient.invalidateQueries({ queryKey: ["admin-submissions"] });
    void queryClient.invalidateQueries({ queryKey: ["published-datasets"] });
  };

  const remove = async (row: SubmissionRow) => {
    setBusy(row.id);
    const { error } = await supabase.from("dataset_submissions").delete().eq("id", row.id);
    setBusy(null);
    if (error) { toast.error(error.message); return; }
    toast.success("Dataset removed");
    void queryClient.invalidateQueries({ queryKey: ["admin-submissions"] });
    void queryClient.invalidateQueries({ queryKey: ["published-datasets"] });
  };

  const counts = {
    pending: (data ?? []).filter((r) => r.status === "submitted" || r.status === "under_review").length,
    approved: (data ?? []).filter((r) => r.status === "approved").length,
    rejected: (data ?? []).filter((r) => r.status === "rejected").length,
  };

  return (
    <AppLayout>
      <section className="mx-auto max-w-6xl px-5 py-14 lg:px-8">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <span className="text-xs font-extrabold uppercase tracking-[0.18em] text-primary">Administrator</span>
            <h1 className="mt-3 font-display text-4xl font-extrabold">Review queue</h1>
            <p className="mt-3 text-sm text-muted-foreground">Validate documentation, approve for publication, or return with reasons.</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button variant="outline" asChild><Link to="/admin/analytics"><BarChart3 />Analytics</Link></Button>
            <Button variant="outline" asChild><Link to="/admin/members"><Users />Administrators</Link></Button>
            <Button variant="outline" asChild><Link to="/admin/audit"><ScrollText />Audit log</Link></Button>
          </div>
        </div>

        <div className="mt-9 grid gap-4 sm:grid-cols-3">
          {[["Awaiting review", counts.pending], ["Published", counts.approved], ["Rejected", counts.rejected]].map(([label, value]) => (
            <div key={String(label)} className="border border-border bg-card p-5">
              <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{label}</span>
              <div className="mt-2 font-display text-3xl font-extrabold">{value}</div>
            </div>
          ))}
        </div>

        <div className="mt-9 max-w-xs">
          <Select value={filter} onValueChange={(value) => setFilter(value as typeof filter)}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="pending">Awaiting review</SelectItem>
              <SelectItem value="all">All submissions</SelectItem>
              <SelectItem value="draft">Drafts</SelectItem>
              <SelectItem value="approved">Published</SelectItem>
              <SelectItem value="rejected">Rejected</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="mt-6 space-y-5">
          {isLoading && <p className="text-sm text-muted-foreground">Loading submissions…</p>}
          {!isLoading && !visible.length && (
            <div className="border border-dashed border-border py-20 text-center">
              <h2 className="font-display text-xl font-bold">Nothing here</h2>
              <p className="mt-2 text-sm text-muted-foreground">No submissions match this view.</p>
            </div>
          )}
          {visible.map((row) => (
            <article key={row.id} className="border border-border bg-card p-6">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <h2 className="font-display text-xl font-bold">{row.title}</h2>
                <span className={`rounded-full px-3 py-1 text-[11px] font-bold uppercase tracking-wider ${STATUS_STYLE[row.status]}`}>{STATUS_LABEL[row.status]}</span>
              </div>
              <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-xs text-muted-foreground">
                <span>{row.domain}</span><span>{row.task}</span><span>{row.format}</span><span>v{row.version}</span>
                <span>{row.rows_count.toLocaleString()} rows</span>
                <span>{(row.data_dictionary as unknown[]).length} variables</span>
                <span>Updated {new Date(row.updated_at).toLocaleDateString()}</span>
              </div>
              <p className="mt-4 line-clamp-3 text-sm leading-6 text-muted-foreground">{row.description}</p>

              <ValidationChecklist row={row} />

              {row.status !== "approved" && (
                <Textarea
                  className="mt-5"
                  rows={2}
                  placeholder="Feedback for the contributor (required to reject)"
                  value={notes[row.id] ?? ""}
                  onChange={(event) => setNotes((prev) => ({ ...prev, [row.id]: event.target.value }))}
                />
              )}

              <div className="mt-5 flex flex-wrap gap-2">
                {row.status === "submitted" && (
                  <Button variant="outline" disabled={busy === row.id} onClick={() => void setStatus(row, "under_review")}><Eye />Start review</Button>
                )}
                {row.status !== "approved" && row.status !== "draft" && (
                  <>
                    <Button disabled={busy === row.id} onClick={() => void setStatus(row, "approved")}><Check />Approve &amp; publish</Button>
                    <Button variant="outline" className="text-destructive" disabled={busy === row.id} onClick={() => void setStatus(row, "rejected")}><X />Reject</Button>
                  </>
                )}
                {row.status === "approved" && (
                  <Button variant="outline" asChild><Link to="/datasets/$slug" params={{ slug: row.slug }}>View public page</Link></Button>
                )}
                <Button variant="ghost" className="text-destructive" disabled={busy === row.id} onClick={() => void remove(row)}><Trash2 />Delete</Button>
              </div>
            </article>
          ))}
        </div>
      </section>
    </AppLayout>
  );
}

function ValidationChecklist({ row }: { row: SubmissionRow }) {
  const checks: [string, boolean][] = [
    ["Description documented", row.description.trim().length >= 60],
    ["Intended use stated", row.intended_use.trim().length >= 30],
    ["Methodology documented", row.methodology.trim().length >= 60],
    ["Limitations stated", row.limitations.trim().length >= 30],
    ["Data dictionary complete", (row.data_dictionary as unknown[]).length >= 2],
    ["Sample data provided", (row.sample_data as unknown[]).length > 0],
  ];
  return (
    <ul className="mt-5 grid gap-2 border-t border-border pt-5 text-xs sm:grid-cols-2">
      {checks.map(([label, ok]) => (
        <li key={label} className={`flex items-center gap-2 ${ok ? "text-muted-foreground" : "text-destructive"}`}>
          {ok ? <Check className="size-3.5" /> : <X className="size-3.5" />}{label}
        </li>
      ))}
    </ul>
  );
}
