import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowRight, Boxes, Braces, Database, Network, ShieldCheck, Sparkles } from "lucide-react";

import { AppLayout } from "@/components/app-layout";
import { DatasetCard } from "@/components/dataset-card";
import { Button } from "@/components/ui/button";
import { datasets } from "@/lib/datasets";

export const Route = createFileRoute("/")({
  head: () => ({ meta: [
    { title: "IYEOB — Synthetic Data Infrastructure for Africa" },
    { name: "description", content: "Discover research-ready synthetic Nigerian datasets for responsible AI development." },
    { property: "og:title", content: "IYEOB — Synthetic Data Infrastructure for Africa" },
    { property: "og:description", content: "Discover research-ready synthetic Nigerian datasets for responsible AI development." },
    { property: "og:type", content: "website" },
    { name: "twitter:card", content: "summary_large_image" },
  ]}),
  component: HomePage,
});

function HomePage() {
  return (
    <AppLayout>
      <section className="hero-atmosphere relative min-h-[calc(100vh-4.5rem)] overflow-hidden text-primary-foreground">
        <div className="data-grid absolute inset-0 opacity-40" />
        <DataNetwork />
        <div className="relative mx-auto flex min-h-[calc(100vh-4.5rem)] max-w-7xl items-center px-5 py-20 lg:px-8">
          <div className="max-w-3xl">
            <div className="mb-7 inline-flex items-center gap-2 rounded-full border border-primary-foreground/20 bg-primary-foreground/10 px-3 py-1.5 text-xs font-bold uppercase tracking-wider backdrop-blur">
              <ShieldCheck className="size-4 text-highlight" /> Zero real personal data
            </div>
            <h1 className="font-display text-5xl font-extrabold leading-[1.04] sm:text-6xl lg:text-7xl">Build AI with data designed for Nigeria.</h1>
            <p className="mt-7 max-w-2xl text-lg leading-8 text-primary-foreground/75 sm:text-xl">Synthetic data infrastructure for researchers, developers, students and organizations building the next generation of African AI.</p>
            <div className="mt-9 flex flex-wrap gap-3">
              <Button size="lg" className="bg-highlight text-highlight-foreground hover:bg-highlight/90" asChild><Link to="/datasets">Explore datasets <ArrowRight /></Link></Button>
              <Button size="lg" variant="outline" className="border-primary-foreground/30 bg-primary-foreground/5 text-primary-foreground hover:bg-primary-foreground/10 hover:text-primary-foreground" asChild><Link to="/developers">Build with IYEOB <Braces /></Link></Button>
            </div>
            <div className="mt-14 flex flex-wrap gap-x-10 gap-y-4 text-sm text-primary-foreground/60">
              <span><strong className="font-display text-2xl text-primary-foreground">5</strong><br />open datasets</span>
              <span><strong className="font-display text-2xl text-primary-foreground">80K</strong><br />synthetic records</span>
              <span><strong className="font-display text-2xl text-primary-foreground">100%</strong><br />privacy-preserving</span>
            </div>
          </div>
        </div>
      </section>

      <section className="border-b border-border bg-card py-20">
        <div className="mx-auto max-w-7xl px-5 lg:px-8">
          <div className="max-w-2xl"><span className="text-xs font-extrabold uppercase tracking-[0.18em] text-primary">The platform path</span><h2 className="mt-3 font-display text-3xl font-extrabold sm:text-4xl">Local Data. Local Intelligence. Local AI.</h2><p className="mt-4 leading-7 text-muted-foreground">Nigeria is our starting point. IYEOB is building the trusted infrastructure layer for an Africa-first AI ecosystem.</p></div>
          <div className="mt-12 grid gap-3 md:grid-cols-4">
            {[
              [Database, "01", "Synthetic Data", "Research-ready, documented datasets"],
              [Braces, "02", "APIs", "Programmatic access and workflows"],
              [Boxes, "03", "Localized Models", "Models grounded in local contexts"],
              [Network, "04", "Evaluation & Control", "Responsible quality and oversight"],
            ].map(([Icon, number, title, body], index) => {
              const IconComponent = Icon as typeof Database;
              return <div key={title as string} className={`relative border p-6 ${index === 0 ? "border-primary bg-accent" : "border-border bg-background"}`}><div className="flex items-center justify-between"><IconComponent className="size-6 text-primary" /><span className="font-display text-xs font-bold text-muted-foreground">{number as string}</span></div><h3 className="mt-10 font-display text-lg font-bold">{title as string}</h3><p className="mt-2 text-sm leading-6 text-muted-foreground">{body as string}</p>{index < 3 && <ArrowRight className="absolute -right-5 top-1/2 z-10 hidden size-5 text-primary md:block" />}</div>;
            })}
          </div>
        </div>
      </section>

      <section className="py-24">
        <div className="mx-auto max-w-7xl px-5 lg:px-8">
          <div className="flex flex-col justify-between gap-5 sm:flex-row sm:items-end"><div><span className="text-xs font-extrabold uppercase tracking-[0.18em] text-primary">Repository</span><h2 className="mt-3 font-display text-3xl font-extrabold sm:text-4xl">Explore synthetic datasets</h2><p className="mt-3 max-w-xl text-muted-foreground">Structured for discovery, transparent by design, and ready for responsible experimentation.</p></div><Button variant="outline" asChild><Link to="/datasets">View all datasets <ArrowRight /></Link></Button></div>
          <div className="mt-10 grid gap-5 md:grid-cols-2 lg:grid-cols-3">{datasets.slice(0, 3).map((dataset) => <DatasetCard dataset={dataset} key={dataset.slug} />)}</div>
        </div>
      </section>

      <section className="bg-accent py-20"><div className="mx-auto flex max-w-5xl flex-col items-center px-5 text-center"><Sparkles className="size-8 text-primary" /><h2 className="mt-5 font-display text-3xl font-extrabold">Synthetic by design. Transparent by default.</h2><p className="mt-4 max-w-2xl leading-7 text-muted-foreground">Every IYEOB dataset includes its methodology, assumptions, relationships, validation approach, limitations, version, licence, and citation. Synthetic quality does not imply real-world statistical representation.</p></div></section>
    </AppLayout>
  );
}

function DataNetwork() {
  return <div className="pointer-events-none absolute inset-y-0 right-0 hidden w-1/2 lg:block" aria-hidden="true"><div className="signal-pulse absolute right-[16%] top-[22%] size-72 rounded-full border border-primary-foreground/15" /><div className="signal-pulse absolute right-[25%] top-[32%] size-48 rounded-full border border-highlight/30 [animation-delay:600ms]" /><div className="absolute right-[35%] top-[45%] size-4 rounded-full bg-highlight shadow-[0_0_40px_var(--highlight)]" /><div className="absolute right-[12%] top-[28%] size-2 rounded-full bg-primary-foreground" /><div className="absolute right-[22%] top-[68%] size-3 rounded-full bg-primary" /><div className="absolute right-[48%] top-[24%] h-px w-60 rotate-[20deg] bg-gradient-to-r from-transparent via-primary-foreground/40 to-transparent" /><div className="absolute right-[10%] top-[54%] h-px w-72 -rotate-[34deg] bg-gradient-to-r from-transparent via-highlight/50 to-transparent" /></div>;
}