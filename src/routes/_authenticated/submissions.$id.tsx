import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { ArrowLeft, MessageSquareWarning, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import { toast } from "sonner";

import { AppLayout } from "@/components/app-layout";
import { SubmissionForm, emptyDraft, parseSampleCsv, validateDraft, type SubmissionDraft } from "@/components/submission-form";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { STATUS_LABEL, STATUS_STYLE, type SubmissionRow } from "@/lib/submissions";
import { toCsv } from "@/lib/download";

export const Route = createFileRoute("/_authenticated/submissions/$id")({
  head: () => ({ meta: [{ title: "Submission review status | IYEOB" }, { name: "description", content: "Review status, feedback, and editing for your IYEOB dataset submission." }] }),
  component: SubmissionDetailPage,
});

function rowToDraft(row: SubmissionRow): SubmissionDraft {
  const sample = (row.sample_data as unknown as Record<string, string | number>[]) ?? [];
  const headers = Object.keys(sample[0] ?? {});
  return {
    ...emptyDraft,
    title: row.title,
    slug: row.slug,
    domain: row.domain,
    task: row.task,
    difficulty: row.difficulty,
    country: row.country,
    format: row.format,
    license: row.license,
    version: row.version,
    authors: row.authors,
    rows_count: row.rows_count,
    description: row.description,
    intended_use: row.intended_use,
    methodology: row.methodology,
    limitations: row.limitations,
    assumptions: row.assumptions,
    data_dictionary: (row.data_dictionary as unknown as SubmissionDraft["data_dictionary"]) ?? [],
    sample_data: sample,
    sample_raw: headers.length ? toCsv(sample, headers) : "",
  };
}

function SubmissionDetailPage() {
  const { id } = Route.useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState<SubmissionDraft | null>(null);
  const [errors, setErrors] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  const { data: row, isLoading } = useQuery({
    queryKey: ["submission", id],
    queryFn: async () => {
      const { data, error } = await supabase.from("dataset_submissions").select("*").eq("id", id).maybeSingle();
      if (error) throw error;
      return data as SubmissionRow | null;
    },
  });

  useEffect(() => { if (row) setDraft(rowToDraft(row)); }, [row]);

  if (isLoading || !draft) {
    return <AppLayout><div className="mx-auto max-w-4xl px-5 py-20 text-sm text-muted-foreground">Loading submission…</div></AppLayout>;
  }
  if (!row) {
    return <AppLayout><div className="mx-auto max-w-4xl px-5 py-20 text-center"><h1 className="font-display text-3xl font-bold">Submission not found</h1><Button className="mt-6" asChild><Link to="/submissions">Back to my submissions</Link></Button></div></AppLayout>;
  }

  const editable = row.status === "draft" || row.status === "rejected" || row.status === "submitted";

  const save = async (status: "draft" | "submitted") => {
    const issues = status === "submitted" ? validateDraft(draft) : [];
    setErrors(issues);
    if (issues.length) { toast.error("Please fix the highlighted fields."); return; }
    setBusy(true);
    const { error } = await supabase
      .from("dataset_submissions")
      .update({
        title: draft.title, slug: draft.slug, short_title: draft.title.slice(0, 40), domain: draft.domain,
        task: draft.task, difficulty: draft.difficulty, country: draft.country, format: draft.format,
        license: draft.license, version: draft.version, authors: draft.authors, rows_count: draft.rows_count,
        description: draft.description, intended_use: draft.intended_use, methodology: draft.methodology,
        limitations: draft.limitations, assumptions: draft.assumptions,
        data_dictionary: draft.data_dictionary.filter((column) => column.name.trim()),
        sample_data: draft.sample_data.length ? draft.sample_data : parseSampleCsv(draft.sample_raw),
        status,
      })
      .eq("id", id);
    setBusy(false);
    if (error) { toast.error(error.message); return; }
    toast.success(status === "submitted" ? "Sent for review" : "Changes saved");
    void queryClient.invalidateQueries({ queryKey: ["submission", id] });
    void queryClient.invalidateQueries({ queryKey: ["my-submissions"] });
  };

  const remove = async () => {
    setBusy(true);
    const { error } = await supabase.from("dataset_submissions").delete().eq("id", id);
    setBusy(false);
    if (error) { toast.error(error.message); return; }
    toast.success("Submission deleted");
    void navigate({ to: "/submissions" });
  };

  return (
    <AppLayout>
      <section className="mx-auto max-w-4xl px-5 py-12 lg:px-8">
        <Link to="/submissions" className="inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground hover:text-primary">
          <ArrowLeft className="size-4" />My submissions
        </Link>

        <div className="mt-6 flex flex-wrap items-center justify-between gap-3">
          <h1 className="font-display text-4xl font-extrabold">{row.title}</h1>
          <span className={`rounded-full px-3 py-1 text-[11px] font-bold uppercase tracking-wider ${STATUS_STYLE[row.status]}`}>{STATUS_LABEL[row.status]}</span>
        </div>

        <ol className="mt-7 flex flex-wrap gap-2 text-xs font-semibold">
          {(["draft", "submitted", "under_review", row.status === "rejected" ? "rejected" : "approved"] as const).map((step) => (
            <li key={step} className={`border px-3 py-1.5 ${row.status === step ? "border-primary text-primary" : "border-border text-muted-foreground"}`}>
              {STATUS_LABEL[step]}
            </li>
          ))}
        </ol>

        {row.review_notes && (
          <div className="mt-7 flex gap-3 border border-border bg-card p-5 text-sm">
            <MessageSquareWarning className="mt-0.5 size-5 shrink-0 text-highlight-foreground" />
            <p><strong>Reviewer feedback: </strong>{row.review_notes}</p>
          </div>
        )}

        {row.status === "approved" && (
          <p className="mt-7 border border-border bg-card p-5 text-sm">
            Published in the repository — <Link to="/datasets/$slug" params={{ slug: row.slug }} className="font-semibold text-primary">view the public page</Link>.
          </p>
        )}

        {errors.length > 0 && (
          <ul className="mt-8 border border-destructive/40 bg-destructive/5 p-5 text-sm text-destructive">
            {errors.map((issue) => <li key={issue} className="ml-4 list-disc">{issue}</li>)}
          </ul>
        )}

        <div className="mt-10"><SubmissionForm draft={draft} onChange={setDraft} disabled={!editable || busy} /></div>

        {editable && (
          <div className="mt-12 flex flex-wrap gap-3 border-t border-border pt-7">
            <Button onClick={() => void save("submitted")} disabled={busy}>{row.status === "rejected" ? "Resubmit for review" : "Submit for review"}</Button>
            <Button variant="outline" onClick={() => void save("draft")} disabled={busy}>Save changes</Button>
            <Button variant="ghost" className="text-destructive" onClick={() => void remove()} disabled={busy}><Trash2 />Delete</Button>
          </div>
        )}
        {!editable && <p className="mt-10 border-t border-border pt-7 text-sm text-muted-foreground">This submission is locked while it is {STATUS_LABEL[row.status].toLowerCase()}.</p>}
      </section>
    </AppLayout>
  );
}
