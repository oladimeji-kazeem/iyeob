import { useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { FilePlus2, MessageSquareWarning } from "lucide-react";

import { AppLayout } from "@/components/app-layout";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";
import { STATUS_LABEL, STATUS_STYLE, type SubmissionRow } from "@/lib/submissions";

export const Route = createFileRoute("/_authenticated/submissions/")({
  head: () => ({ meta: [{ title: "My submissions | IYEOB" }, { name: "description", content: "Track the review status of the synthetic datasets you submitted to IYEOB." }] }),
  component: SubmissionsPage,
});

function SubmissionsPage() {
  const { user, isAdmin } = useAuth();
  const { data, isLoading } = useQuery({
    queryKey: ["my-submissions", user?.id],
    enabled: Boolean(user?.id),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("dataset_submissions")
        .select("*")
        .eq("submitted_by", user!.id)
        .order("updated_at", { ascending: false });
      if (error) throw error;
      return data as SubmissionRow[];
    },
  });

  return (
    <AppLayout>
      <section className="mx-auto max-w-5xl px-5 py-14 lg:px-8">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <span className="text-xs font-extrabold uppercase tracking-[0.18em] text-primary">Contributor workspace</span>
            <h1 className="mt-3 font-display text-4xl font-extrabold">My submissions</h1>
            <p className="mt-3 text-sm text-muted-foreground">Draft, submit, and follow the review of your synthetic datasets.</p>
          </div>
          <div className="flex gap-2">
            {isAdmin && <Button variant="outline" asChild><Link to="/admin">Admin review</Link></Button>}
            <Button asChild><Link to="/submissions/new"><FilePlus2 />New submission</Link></Button>
          </div>
        </div>

        <div className="mt-10 space-y-4">
          {isLoading && <p className="text-sm text-muted-foreground">Loading your submissions…</p>}
          {!isLoading && !data?.length && (
            <div className="border border-dashed border-border py-20 text-center">
              <h2 className="font-display text-xl font-bold">No submissions yet</h2>
              <p className="mt-2 text-sm text-muted-foreground">Register your first synthetic dataset to start the review process.</p>
              <Button className="mt-6" asChild><Link to="/submissions/new">Start a submission</Link></Button>
            </div>
          )}
          {data?.map((row) => (
            <Link
              key={row.id}
              to="/submissions/$id"
              params={{ id: row.id }}
              className="block border border-border bg-card p-6 transition-colors hover:border-primary/40"
            >
              <div className="flex flex-wrap items-center justify-between gap-3">
                <h2 className="font-display text-xl font-bold">{row.title}</h2>
                <span className={`rounded-full px-3 py-1 text-[11px] font-bold uppercase tracking-wider ${STATUS_STYLE[row.status]}`}>
                  {STATUS_LABEL[row.status]}
                </span>
              </div>
              <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-xs text-muted-foreground">
                <span>{row.domain}</span><span>{row.format}</span><span>v{row.version}</span>
                <span>Updated {new Date(row.updated_at).toLocaleDateString()}</span>
              </div>
              {row.review_notes && (
                <p className="mt-4 flex gap-2 border-t border-border pt-4 text-sm text-muted-foreground">
                  <MessageSquareWarning className="mt-0.5 size-4 shrink-0 text-highlight-foreground" />
                  <span><strong className="text-foreground">Reviewer feedback: </strong>{row.review_notes}</span>
                </p>
              )}
            </Link>
          ))}
        </div>
      </section>
    </AppLayout>
  );
}
