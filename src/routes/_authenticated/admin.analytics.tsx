import { useQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft } from "lucide-react";
import { useMemo, useState } from "react";
import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";

import { AppLayout } from "@/components/app-layout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { supabase } from "@/integrations/supabase/client";
import { describeFilters } from "@/lib/analytics";

export const Route = createFileRoute("/_authenticated/admin/analytics")({
  head: () => ({ meta: [{ title: "Usage analytics | IYEOB Admin" }, { name: "description", content: "Dataset views, searches, downloads, and filter usage over time." }] }),
  component: AnalyticsPage,
});

type EventRow = {
  id: string;
  event_type: string;
  dataset_slug: string | null;
  search_query: string | null;
  filters: Record<string, string> | null;
  created_at: string;
};

function isoDaysAgo(days: number) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date.toISOString().slice(0, 10);
}

function AnalyticsPage() {
  const [from, setFrom] = useState(isoDaysAgo(29));
  const [to, setTo] = useState(new Date().toISOString().slice(0, 10));

  const { data, isLoading } = useQuery({
    queryKey: ["analytics", from, to],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("analytics_events")
        .select("id, event_type, dataset_slug, search_query, filters, created_at")
        .gte("created_at", `${from}T00:00:00Z`)
        .lte("created_at", `${to}T23:59:59Z`)
        .order("created_at", { ascending: true })
        .limit(5000);
      if (error) throw error;
      return data as unknown as EventRow[];
    },
  });

  const events = useMemo(() => data ?? [], [data]);

  const series = useMemo(() => {
    const byDay = new Map<string, { date: string; views: number; searches: number; downloads: number }>();
    const start = new Date(from);
    const end = new Date(to);
    for (let day = new Date(start); day <= end; day.setDate(day.getDate() + 1)) {
      const key = day.toISOString().slice(0, 10);
      byDay.set(key, { date: key.slice(5), views: 0, searches: 0, downloads: 0 });
    }
    for (const event of events) {
      const key = event.created_at.slice(0, 10);
      const bucket = byDay.get(key);
      if (!bucket) continue;
      if (event.event_type === "dataset_view") bucket.views += 1;
      if (event.event_type === "search") bucket.searches += 1;
      if (event.event_type === "download") bucket.downloads += 1;
    }
    return [...byDay.values()];
  }, [events, from, to]);

  const totals = {
    views: events.filter((e) => e.event_type === "dataset_view").length,
    searches: events.filter((e) => e.event_type === "search").length,
    downloads: events.filter((e) => e.event_type === "download").length,
  };

  const topDatasets = useMemo(() => {
    const map = new Map<string, { slug: string; views: number; downloads: number }>();
    for (const event of events) {
      if (!event.dataset_slug) continue;
      const entry = map.get(event.dataset_slug) ?? { slug: event.dataset_slug, views: 0, downloads: 0 };
      if (event.event_type === "dataset_view") entry.views += 1;
      if (event.event_type === "download") entry.downloads += 1;
      map.set(event.dataset_slug, entry);
    }
    return [...map.values()].sort((a, b) => b.views + b.downloads - (a.views + a.downloads)).slice(0, 10);
  }, [events]);

  const topFilters = useMemo(() => {
    const map = new Map<string, number>();
    for (const event of events) {
      if (event.event_type !== "filter" && event.event_type !== "search") continue;
      const label = describeFilters(event.filters ?? {});
      map.set(label, (map.get(label) ?? 0) + 1);
    }
    return [...map.entries()].map(([label, count]) => ({ label, count })).sort((a, b) => b.count - a.count).slice(0, 10);
  }, [events]);

  const topQueries = useMemo(() => {
    const map = new Map<string, number>();
    for (const event of events) {
      const query = event.search_query?.trim().toLowerCase();
      if (!query) continue;
      map.set(query, (map.get(query) ?? 0) + 1);
    }
    return [...map.entries()].map(([label, count]) => ({ label, count })).sort((a, b) => b.count - a.count).slice(0, 10);
  }, [events]);

  return (
    <AppLayout>
      <section className="mx-auto max-w-6xl px-5 py-12 lg:px-8">
        <Link to="/admin" className="inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground hover:text-primary">
          <ArrowLeft className="size-4" />Review queue
        </Link>
        <h1 className="mt-6 font-display text-4xl font-extrabold">Repository analytics</h1>
        <p className="mt-3 text-sm text-muted-foreground">Views, searches, downloads, and the filter combinations researchers use most.</p>

        <div className="mt-8 flex flex-wrap items-end gap-4 border border-border bg-card p-5">
          <div className="space-y-2"><Label>From</Label><Input type="date" value={from} max={to} onChange={(e) => setFrom(e.target.value)} /></div>
          <div className="space-y-2"><Label>To</Label><Input type="date" value={to} min={from} onChange={(e) => setTo(e.target.value)} /></div>
          <div className="flex gap-2">
            {[["7 days", 6], ["30 days", 29], ["90 days", 89]].map(([label, days]) => (
              <Button key={String(label)} variant="outline" size="sm" onClick={() => { setFrom(isoDaysAgo(days as number)); setTo(new Date().toISOString().slice(0, 10)); }}>
                {label}
              </Button>
            ))}
          </div>
        </div>

        <div className="mt-6 grid gap-4 sm:grid-cols-3">
          {[["Dataset views", totals.views], ["Searches", totals.searches], ["Downloads", totals.downloads]].map(([label, value]) => (
            <div key={String(label)} className="border border-border bg-card p-5">
              <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{label}</span>
              <div className="mt-2 font-display text-3xl font-extrabold">{value}</div>
            </div>
          ))}
        </div>

        <div className="mt-6 border border-border bg-card p-5">
          <h2 className="font-display text-lg font-bold">Activity over time</h2>
          <div className="mt-5 h-72 w-full">
            {isLoading ? <p className="text-sm text-muted-foreground">Loading…</p> : (
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={series} margin={{ left: -20, right: 8, top: 8 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 11 }} />
                  <Tooltip />
                  <Line type="monotone" dataKey="views" stroke="var(--color-primary)" strokeWidth={2} dot={false} name="Views" />
                  <Line type="monotone" dataKey="searches" stroke="var(--color-muted-foreground)" strokeWidth={2} dot={false} name="Searches" />
                  <Line type="monotone" dataKey="downloads" stroke="var(--color-highlight-foreground)" strokeWidth={2} dot={false} name="Downloads" />
                </LineChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>

        <div className="mt-6 grid gap-5 lg:grid-cols-2">
          <Panel title="Top datasets">
            <Table head={["Dataset", "Views", "Downloads"]} rows={topDatasets.map((row) => [row.slug, String(row.views), String(row.downloads)])} />
          </Panel>
          <Panel title="Most-used filter combinations">
            <Table head={["Filters", "Uses"]} rows={topFilters.map((row) => [row.label, String(row.count)])} />
          </Panel>
          <Panel title="Top search queries">
            <Table head={["Query", "Searches"]} rows={topQueries.map((row) => [row.label, String(row.count)])} />
          </Panel>
        </div>
      </section>
    </AppLayout>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="border border-border bg-card p-5">
      <h2 className="font-display text-lg font-bold">{title}</h2>
      <div className="mt-4">{children}</div>
    </div>
  );
}

function Table({ head, rows }: { head: string[]; rows: string[][] }) {
  if (!rows.length) return <p className="text-sm text-muted-foreground">No activity in this period yet.</p>;
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead className="bg-muted text-xs uppercase text-muted-foreground">
          <tr>{head.map((cell) => <th key={cell} className="px-3 py-2">{cell}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={index} className="border-t border-border">
              {row.map((cell, cellIndex) => <td key={cellIndex} className="px-3 py-2">{cell}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
