import { createFileRoute, Link, notFound } from "@tanstack/react-router";
import { ArrowLeft, Check, Copy, Database, Download, FileJson, Search, ShieldCheck } from "lucide-react";
import { useMemo, useState } from "react";
import { toast } from "sonner";

import { AppLayout } from "@/components/app-layout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Toaster } from "@/components/ui/sonner";
import { datasetBySlug } from "@/lib/datasets";

export const Route = createFileRoute("/datasets/$slug")({
  loader: ({ params }) => {
    const dataset = datasetBySlug(params.slug);
    if (!dataset) throw notFound();
    return dataset;
  },
  head: ({ loaderData }) => {
    const title = loaderData ? `${loaderData.title} Synthetic Dataset | IYEOB` : "Dataset unavailable | IYEOB";
    const description = loaderData?.description ?? "This IYEOB synthetic dataset is unavailable.";
    return { meta: [{ title }, { name: "description", content: description }, { property: "og:title", content: title }, { property: "og:description", content: description }, { property: "og:type", content: "website" }, { name: "twitter:card", content: "summary_large_image" }] };
  },
  component: DatasetDetailPage,
  notFoundComponent: () => <AppLayout><div className="mx-auto max-w-3xl px-5 py-28 text-center"><h1 className="font-display text-4xl font-bold">Dataset unavailable</h1><p className="mt-4 text-muted-foreground">This release may have moved or is no longer published.</p><Button className="mt-7" asChild><Link to="/datasets">Browse datasets</Link></Button></div></AppLayout>,
});

function DatasetDetailPage() {
  const dataset = Route.useLoaderData();
  const [columnQuery, setColumnQuery] = useState("");
  const columns = useMemo(() => dataset.columns.filter((column) => `${column.name} ${column.description} ${column.type}`.toLowerCase().includes(columnQuery.toLowerCase())), [dataset.columns, columnQuery]);
  const citation = `${dataset.title}. IYEOB Synthetic Data Repository, version ${dataset.version}, 2026. ${dataset.license}.`;

  const download = (format: "csv" | "json") => {
    const content = format === "json" ? JSON.stringify(dataset.preview, null, 2) : [Object.keys(dataset.preview[0] ?? {}).join(","), ...dataset.preview.map((row) => Object.values(row).join(","))].join("\n");
    const blob = new Blob([content], { type: format === "json" ? "application/json" : "text/csv" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a"); anchor.href = url; anchor.download = `${dataset.slug}-sample.${format}`; anchor.click(); URL.revokeObjectURL(url);
    toast.success(`${format.toUpperCase()} sample downloaded`);
  };

  const copyCitation = async () => { await navigator.clipboard.writeText(citation); toast.success("Citation copied"); };

  return <AppLayout><Toaster />
    <section className="border-b border-border bg-card"><div className="mx-auto max-w-7xl px-5 py-10 lg:px-8"><Link to="/datasets" className="inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground hover:text-primary"><ArrowLeft className="size-4"/>All datasets</Link><div className="mt-8 flex flex-col justify-between gap-8 lg:flex-row lg:items-end"><div className="max-w-3xl"><div className="flex flex-wrap items-center gap-2"><span className="inline-flex items-center gap-1.5 rounded-full bg-synthetic px-2.5 py-1 text-[11px] font-bold uppercase tracking-wider text-synthetic-foreground"><ShieldCheck className="size-3.5"/>Synthetic data</span><span className="text-xs font-bold uppercase tracking-wider text-primary">{dataset.domain}</span></div><h1 className="mt-5 font-display text-4xl font-extrabold sm:text-5xl">{dataset.title}</h1><p className="mt-5 text-lg leading-8 text-muted-foreground">{dataset.description}</p><div className="mt-6 flex flex-wrap gap-x-6 gap-y-2 text-sm text-muted-foreground"><span>{dataset.country}</span><span>{dataset.task}</span><span>{dataset.difficulty}</span><span>Version {dataset.version}</span><span>{dataset.license}</span></div></div><div className="flex gap-2"><Button variant="outline" onClick={() => download("json")}><FileJson/>JSON</Button><Button onClick={() => download("csv")}><Download/>Download CSV</Button></div></div></div></section>
    <div className="bg-highlight px-5 py-3 text-center text-sm font-semibold text-highlight-foreground"><strong>Synthetic data notice:</strong> No real people or organizations are represented. This dataset is not an official statistic or empirical observation.</div>
    <section className="mx-auto max-w-7xl px-5 py-12 lg:px-8"><div className="grid gap-10 lg:grid-cols-[1fr_320px]"><div><Tabs defaultValue="overview"><TabsList className="h-auto w-full justify-start overflow-x-auto border-b border-border bg-transparent p-0"><Tab value="overview">Overview</Tab><Tab value="dictionary">Data dictionary</Tab><Tab value="preview">Preview</Tab><Tab value="methodology">Methodology</Tab></TabsList>
      <TabsContent value="overview" className="pt-8"><Section title="What this dataset represents"><p>{dataset.description}</p><h3>Intended use</h3><p>{dataset.intendedUse}</p><h3>Ethical considerations</h3><p>Use this dataset for learning, prototyping, and research. Do not use synthetic outputs to infer facts about individuals, communities, companies, or Nigerian population statistics.</p></Section><div className="mt-9 grid gap-4 sm:grid-cols-3">{[["Rows",dataset.rows.toLocaleString()],["Variables",dataset.columns.length],["Size",dataset.size]].map(([label,value])=><div key={label} className="border border-border bg-card p-5"><span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{label}</span><div className="mt-2 font-display text-2xl font-extrabold">{value}</div></div>)}</div><Section title="Research questions"> <ul>{dataset.researchQuestions.map((item)=><li key={item}>{item}</li>)}</ul></Section></TabsContent>
      <TabsContent value="dictionary" className="pt-8"><div className="relative mb-5"><Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"/><Input value={columnQuery} onChange={(e)=>setColumnQuery(e.target.value)} placeholder="Search variables" className="pl-10"/></div><div className="overflow-x-auto border border-border"><table className="w-full min-w-[720px] text-left text-sm"><thead className="bg-muted text-xs uppercase text-muted-foreground"><tr>{["Variable","Type","Description","Example","Role"].map((x)=><th className="px-4 py-3" key={x}>{x}</th>)}</tr></thead><tbody>{columns.map((c)=><tr key={c.name} className="border-t border-border"><td className="px-4 py-4 font-mono font-semibold text-primary">{c.name}</td><td className="px-4 py-4">{c.type}</td><td className="px-4 py-4 text-muted-foreground">{c.description}</td><td className="px-4 py-4 font-mono">{c.example}</td><td className="px-4 py-4">{c.role}</td></tr>)}</tbody></table></div></TabsContent>
      <TabsContent value="preview" className="pt-8"><p className="mb-5 text-sm text-muted-foreground">A small sample from this synthetic release.</p><div className="overflow-x-auto border border-border"><table className="w-full min-w-max text-left text-sm"><thead className="bg-muted"><tr>{Object.keys(dataset.preview[0] ?? {}).map((key)=><th className="px-4 py-3 font-mono text-xs" key={key}>{key}</th>)}</tr></thead><tbody>{dataset.preview.map((row,index)=><tr key={index} className="border-t border-border">{Object.values(row).map((value,i)=><td className="px-4 py-4" key={i}>{String(value)}</td>)}</tr>)}</tbody></table></div></TabsContent>
      <TabsContent value="methodology" className="pt-8"><Section title="Synthetic generation methodology"><p>{dataset.methodology}</p><h3>Assumptions and relationships</h3><ul>{dataset.assumptions.map((item)=><li key={item}>{item}</li>)}</ul><h3>Validation</h3><p>Schema, range, logical relationship, privacy, and reproducibility checks are run against every version before publication.</p><h3>Limitations</h3><ul>{dataset.limitations.map((item)=><li key={item}>{item}</li>)}</ul></Section></TabsContent></Tabs></div>
      <aside className="space-y-5"><div className="border border-border bg-card p-6 shadow-sm"><div className="flex items-center justify-between"><div><span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Construction quality</span><div className="mt-1 font-display text-4xl font-extrabold">{dataset.quality}<span className="text-base text-muted-foreground">/100</span></div></div><Database className="size-7 text-primary"/></div><div className="mt-6 space-y-5"><Metric label="Completeness" value={dataset.completeness}/><Metric label="Privacy preservation" value={dataset.privacy}/><Metric label="Statistical fidelity" value={dataset.fidelity}/><Metric label="Schema validity" value={100}/></div><p className="mt-6 border-t border-border pt-4 text-xs leading-5 text-muted-foreground">Quality measures synthetic construction—not proof of real-world representation.</p></div><div className="border border-border bg-card p-6"><h2 className="font-display text-lg font-bold">Cite this dataset</h2><p className="mt-3 text-sm leading-6 text-muted-foreground">{citation}</p><Button variant="outline" className="mt-5 w-full" onClick={copyCitation}><Copy/>Copy citation</Button></div></aside></div></section>
  </AppLayout>;
}

function Tab({ value, children }: { value: string; children: React.ReactNode }) { return <TabsTrigger value={value} className="rounded-none border-b-2 border-transparent px-4 py-3 data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:shadow-none">{children}</TabsTrigger> }
function Metric({ label, value }: { label: string; value: number }) { return <div><div className="mb-2 flex justify-between text-xs font-semibold"><span>{label}</span><span>{value}%</span></div><Progress value={value} className="h-1.5"/></div> }
function Section({ title, children }: { title: string; children: React.ReactNode }) { return <article className="prose-block"><h2 className="font-display text-2xl font-bold">{title}</h2><div className="mt-4 space-y-4 text-sm leading-7 text-muted-foreground [&_h3]:mt-8 [&_h3]:font-display [&_h3]:text-lg [&_h3]:font-bold [&_h3]:text-foreground [&_li]:mb-2 [&_li]:ml-5 [&_li]:list-disc">{children}</div></article> }