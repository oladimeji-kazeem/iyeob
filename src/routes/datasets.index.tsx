import { createFileRoute } from "@tanstack/react-router";
import { Search, SlidersHorizontal } from "lucide-react";
import { useMemo, useState } from "react";

import { AppLayout } from "@/components/app-layout";
import { DatasetCard } from "@/components/dataset-card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { datasets } from "@/lib/datasets";

export const Route = createFileRoute("/datasets/")({
  head: () => ({ meta: [
    { title: "Synthetic Dataset Repository | IYEOB" },
    { name: "description", content: "Search and filter documented synthetic datasets built for Nigerian and African AI research." },
    { property: "og:title", content: "Synthetic Dataset Repository | IYEOB" },
    { property: "og:description", content: "Search and filter documented synthetic datasets built for Nigerian and African AI research." },
    { property: "og:type", content: "website" }, { name: "twitter:card", content: "summary_large_image" },
  ]}), component: DatasetsPage,
});

function DatasetsPage() {
  const [query, setQuery] = useState("");
  const [domain, setDomain] = useState("all");
  const [task, setTask] = useState("all");
  const [difficulty, setDifficulty] = useState("all");
  const [sort, setSort] = useState("quality");
  const filtered = useMemo(() => datasets.filter((dataset) => {
    const textMatch = `${dataset.title} ${dataset.domain} ${dataset.description}`.toLowerCase().includes(query.toLowerCase());
    return textMatch && (domain === "all" || dataset.domain === domain) && (task === "all" || dataset.task.includes(task)) && (difficulty === "all" || dataset.difficulty === difficulty);
  }).sort((a, b) => sort === "rows" ? b.rows - a.rows : sort === "newest" ? b.version.localeCompare(a.version) : b.quality - a.quality), [query, domain, task, difficulty, sort]);

  return <AppLayout><section className="border-b border-border bg-card"><div className="mx-auto max-w-7xl px-5 py-16 lg:px-8"><span className="text-xs font-extrabold uppercase tracking-[0.18em] text-primary">Open repository · Nigeria</span><h1 className="mt-3 font-display text-4xl font-extrabold sm:text-5xl">Synthetic datasets, clearly documented.</h1><p className="mt-5 max-w-2xl text-lg leading-7 text-muted-foreground">Discover privacy-preserving datasets for research and model development. No real personal data, ever.</p></div></section>
    <section className="mx-auto max-w-7xl px-5 py-10 lg:px-8">
      <div className="border border-border bg-card p-4 shadow-sm"><div className="relative"><Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" /><Input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search datasets, domains, or use cases" className="h-12 pl-10" aria-label="Search datasets" /></div><div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-5"><Filter value={domain} onChange={setDomain} placeholder="Domain" options={["all", ...new Set(datasets.map((d) => d.domain))]} /><Filter value={task} onChange={setTask} placeholder="Task" options={["all", "Classification", "Regression"]} /><Filter value={difficulty} onChange={setDifficulty} placeholder="Difficulty" options={["all", "Beginner", "Intermediate", "Advanced"]} /><Filter value="Nigeria" onChange={() => undefined} placeholder="Country" options={["Nigeria"]} /><Filter value={sort} onChange={setSort} placeholder="Sort" options={["quality", "rows", "newest"]} /></div></div>
      <div className="mt-8 flex items-center justify-between"><p className="text-sm font-semibold"><span className="text-primary">{filtered.length}</span> datasets found</p><span className="flex items-center gap-2 text-xs text-muted-foreground"><SlidersHorizontal className="size-4" />Filters update instantly</span></div>
      {filtered.length ? <div className="mt-5 grid gap-5 md:grid-cols-2 lg:grid-cols-3">{filtered.map((dataset) => <DatasetCard dataset={dataset} key={dataset.slug} />)}</div> : <div className="mt-5 border border-dashed border-border py-24 text-center"><h2 className="font-display text-xl font-bold">No datasets found</h2><p className="mt-2 text-sm text-muted-foreground">Try a different keyword or clear a filter.</p></div>}
    </section></AppLayout>;
}

function Filter({ value, onChange, options, placeholder }: { value: string; onChange: (value: string) => void; options: string[]; placeholder: string }) {
  return <Select value={value} onValueChange={onChange}><SelectTrigger className="h-10"><SelectValue placeholder={placeholder} /></SelectTrigger><SelectContent>{options.map((option) => <SelectItem value={option} key={option}>{option === "all" ? `All ${placeholder.toLowerCase()}s` : option.charAt(0).toUpperCase() + option.slice(1)}</SelectItem>)}</SelectContent></Select>;
}