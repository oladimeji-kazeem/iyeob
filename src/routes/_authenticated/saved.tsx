import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { Bookmark, Search, Trash2 } from "lucide-react";
import { toast } from "sonner";

import { AppLayout } from "@/components/app-layout";
import { Button } from "@/components/ui/button";
import { useBookmarks } from "@/lib/bookmarks";
import { describeSavedSearch, useSavedSearches } from "@/lib/saved-searches";

export const Route = createFileRoute("/_authenticated/saved")({
  head: () => ({
    meta: [
      { title: "Saved datasets & searches | IYEOB" },
      { name: "description", content: "Your bookmarked synthetic datasets and saved search filters on IYEOB." },
    ],
  }),
  component: SavedPage,
});

function SavedPage() {
  const navigate = useNavigate();
  const { bookmarks, isLoading, toggle } = useBookmarks();
  const { searches, isLoading: searchesLoading, remove } = useSavedSearches();

  return (
    <AppLayout>
      <section className="mx-auto max-w-5xl px-5 py-14 lg:px-8">
        <span className="text-xs font-extrabold uppercase tracking-[0.18em] text-primary">Your workspace</span>
        <h1 className="mt-3 font-display text-4xl font-extrabold">Saved datasets &amp; searches</h1>
        <p className="mt-3 text-sm text-muted-foreground">Bookmarked datasets and one-click search presets.</p>

        <h2 className="mt-12 font-display text-2xl font-bold">Bookmarked datasets</h2>
        {isLoading && <p className="mt-4 text-sm text-muted-foreground">Loading bookmarks…</p>}
        {!isLoading && !bookmarks.length && (
          <div className="mt-4 border border-dashed border-border py-16 text-center">
            <p className="text-sm text-muted-foreground">No bookmarks yet — tap the bookmark icon on any dataset.</p>
            <Button className="mt-5" asChild><Link to="/datasets">Browse datasets</Link></Button>
          </div>
        )}
        <div className="mt-4 space-y-3">
          {bookmarks.map((row) => (
            <div key={row.id} className="flex flex-wrap items-center justify-between gap-3 border border-border bg-card p-5">
              <Link to="/datasets/$slug" params={{ slug: row.dataset_slug }} className="flex items-center gap-3 font-semibold hover:text-primary">
                <Bookmark className="size-4 fill-primary text-primary" />{row.dataset_title || row.dataset_slug}
              </Link>
              <Button
                variant="ghost"
                size="sm"
                className="text-destructive"
                onClick={() => toggle.mutate({ slug: row.dataset_slug, title: row.dataset_title }, { onSuccess: () => toast.success("Bookmark removed") })}
              >
                <Trash2 />Remove
              </Button>
            </div>
          ))}
        </div>

        <h2 className="mt-14 font-display text-2xl font-bold">Saved searches</h2>
        {searchesLoading && <p className="mt-4 text-sm text-muted-foreground">Loading saved searches…</p>}
        {!searchesLoading && !searches.length && (
          <div className="mt-4 border border-dashed border-border py-16 text-center">
            <p className="text-sm text-muted-foreground">Save a search from the dataset catalogue to re-apply it in one click.</p>
          </div>
        )}
        <div className="mt-4 space-y-3">
          {searches.map((row) => (
            <div key={row.id} className="flex flex-wrap items-center justify-between gap-3 border border-border bg-card p-5">
              <div>
                <p className="font-semibold">{row.name}</p>
                <p className="mt-1 text-xs text-muted-foreground">{describeSavedSearch(row)}</p>
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => void navigate({ to: "/datasets", search: { saved: row.id } })}
                >
                  <Search />Apply
                </Button>
                <Button variant="ghost" size="sm" className="text-destructive" onClick={() => remove.mutate(row.id, { onSuccess: () => toast.success("Saved search deleted") })}>
                  <Trash2 />
                </Button>
              </div>
            </div>
          ))}
        </div>
      </section>
    </AppLayout>
  );
}
