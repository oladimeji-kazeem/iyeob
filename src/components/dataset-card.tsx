import { Link } from "@tanstack/react-router";
import { ArrowUpRight, Database, ShieldCheck } from "lucide-react";

import type { Dataset } from "@/lib/datasets";

export function DatasetCard({ dataset }: { dataset: Dataset }) {
  return (
    <Link
      to="/datasets/$slug"
      params={{ slug: dataset.slug }}
      className="dataset-card group flex min-h-80 flex-col border border-border bg-card p-6 shadow-sm transition-all duration-300 hover:-translate-y-1 hover:border-primary/40 hover:shadow-xl"
    >
      <div className="flex items-start justify-between gap-4">
        <span className="inline-flex items-center gap-1.5 rounded-full bg-synthetic px-2.5 py-1 text-[11px] font-bold uppercase tracking-wider text-synthetic-foreground">
          <ShieldCheck className="size-3.5" /> Synthetic data
        </span>
        <span className="text-xs font-semibold text-muted-foreground">v{dataset.version}</span>
      </div>
      <div className="mt-7 text-xs font-bold uppercase tracking-[0.15em] text-primary">{dataset.domain}</div>
      <h3 className="mt-3 font-display text-2xl font-bold leading-tight text-foreground">{dataset.shortTitle}</h3>
      <p className="mt-3 line-clamp-3 text-sm leading-6 text-muted-foreground">{dataset.description}</p>
      <div className="mt-auto pt-7">
        <div className="flex flex-wrap gap-x-4 gap-y-2 border-t border-border pt-5 text-xs font-medium text-muted-foreground">
          <span className="flex items-center gap-1.5"><Database className="size-3.5" />{dataset.rows.toLocaleString()} rows</span>
          <span>{dataset.columns.length} variables</span>
          <span>{dataset.task}</span>
        </div>
        <div className="mt-5 flex items-center justify-between">
          <div>
            <span className="text-xs text-muted-foreground">Quality </span>
            <span className="font-display text-lg font-extrabold text-foreground">{dataset.quality}</span>
            <span className="text-xs text-muted-foreground">/100</span>
          </div>
          <span className="flex items-center gap-1 text-sm font-bold text-primary opacity-80 transition-opacity group-hover:opacity-100">
            View dataset <ArrowUpRight className="size-4 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
          </span>
        </div>
      </div>
    </Link>
  );
}