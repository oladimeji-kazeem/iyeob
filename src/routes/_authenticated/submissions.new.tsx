import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { ArrowLeft } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

import { AppLayout } from "@/components/app-layout";
import { SubmissionForm, emptyDraft, validateDraft, type SubmissionDraft } from "@/components/submission-form";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";
import { slugify } from "@/lib/submissions";

export const Route = createFileRoute("/_authenticated/submissions/new")({
  head: () => ({ meta: [{ title: "Submit a synthetic dataset | IYEOB" }, { name: "description", content: "Register a documented synthetic dataset for IYEOB review and publication." }] }),
  component: NewSubmissionPage,
});

function NewSubmissionPage() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [draft, setDraft] = useState<SubmissionDraft>(emptyDraft);
  const [errors, setErrors] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  const save = async (status: "draft" | "submitted") => {
    if (!user) return;
    const issues = status === "submitted" ? validateDraft(draft) : draft.title.trim() ? [] : ["Add a title before saving a draft."];
    setErrors(issues);
    if (issues.length) {
      toast.error("Please fix the highlighted fields.");
      return;
    }
    setBusy(true);
    const { data, error } = await supabase
      .from("dataset_submissions")
      .insert({
        slug: draft.slug || slugify(draft.title),
        title: draft.title,
        short_title: draft.title.slice(0, 40),
        domain: draft.domain,
        task: draft.task,
        difficulty: draft.difficulty,
        country: draft.country,
        format: draft.format,
        license: draft.license,
        version: draft.version,
        authors: draft.authors,
        rows_count: draft.rows_count,
        description: draft.description,
        intended_use: draft.intended_use,
        methodology: draft.methodology,
        limitations: draft.limitations,
        assumptions: draft.assumptions,
        data_dictionary: draft.data_dictionary.filter((column) => column.name.trim()),
        sample_data: draft.sample_data,
        status,
        submitted_by: user.id,
      })
      .select("id")
      .single();
    setBusy(false);
    if (error) {
      toast.error(error.message.includes("duplicate") ? "That URL slug is already taken." : error.message);
      return;
    }
    toast.success(status === "draft" ? "Draft saved" : "Submitted for review");
    void navigate({ to: "/submissions/$id", params: { id: data.id } });
  };

  return (
    <AppLayout>
      <section className="mx-auto max-w-4xl px-5 py-12 lg:px-8">
        <Link to="/submissions" className="inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground hover:text-primary">
          <ArrowLeft className="size-4" />My submissions
        </Link>
        <h1 className="mt-6 font-display text-4xl font-extrabold">Submit a synthetic dataset</h1>
        <p className="mt-3 max-w-2xl text-sm leading-6 text-muted-foreground">
          Only fully synthetic data is accepted. Never upload records derived from real people or organizations.
        </p>

        {errors.length > 0 && (
          <ul className="mt-8 border border-destructive/40 bg-destructive/5 p-5 text-sm text-destructive">
            {errors.map((issue) => <li key={issue} className="ml-4 list-disc">{issue}</li>)}
          </ul>
        )}

        <div className="mt-10"><SubmissionForm draft={draft} onChange={setDraft} disabled={busy} /></div>

        <div className="mt-12 flex flex-wrap gap-3 border-t border-border pt-7">
          <Button onClick={() => void save("submitted")} disabled={busy}>Submit for review</Button>
          <Button variant="outline" onClick={() => void save("draft")} disabled={busy}>Save as draft</Button>
        </div>
      </section>
    </AppLayout>
  );
}
