import { Plus, Trash2 } from "lucide-react";
import { cloneElement, isValidElement, useId, useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import type { DatasetColumn } from "@/lib/datasets";
import { slugify } from "@/lib/submissions";

export type SubmissionDraft = {
  title: string;
  slug: string;
  domain: string;
  task: string;
  difficulty: string;
  country: string;
  format: string;
  license: string;
  version: string;
  authors: string;
  rows_count: number;
  description: string;
  intended_use: string;
  methodology: string;
  limitations: string;
  assumptions: string;
  data_dictionary: DatasetColumn[];
  sample_data: Record<string, string | number>[];
  sample_raw: string;
};

export const emptyDraft: SubmissionDraft = {
  title: "",
  slug: "",
  domain: "Financial Services",
  task: "Classification",
  difficulty: "Intermediate",
  country: "Nigeria",
  format: "CSV",
  license: "CC BY 4.0",
  version: "1.0.0",
  authors: "",
  rows_count: 1000,
  description: "",
  intended_use: "",
  methodology: "",
  limitations: "",
  assumptions: "",
  data_dictionary: [{ name: "", type: "string", description: "", example: "", role: "Feature" }],
  sample_data: [],
  sample_raw: "",
};

export function parseSampleCsv(raw: string): Record<string, string | number>[] {
  const lines = raw.split("\n").map((line) => line.trim()).filter(Boolean);
  if (lines.length < 2) return [];
  const headers = lines[0]!.split(",").map((h) => h.trim());
  return lines.slice(1, 26).map((line) => {
    const cells = line.split(",").map((c) => c.trim());
    return Object.fromEntries(
      headers.map((header, index) => {
        const value = cells[index] ?? "";
        const numeric = value !== "" && !Number.isNaN(Number(value));
        return [header, numeric ? Number(value) : value];
      }),
    );
  });
}

export function validateDraft(draft: SubmissionDraft): string[] {
  const errors: string[] = [];
  if (draft.title.trim().length < 6) errors.push("Title must be at least 6 characters.");
  if (!draft.domain.trim()) errors.push("Category is required.");
  if (!draft.format.trim()) errors.push("Format is required.");
  if (draft.description.trim().length < 60) errors.push("Description must be at least 60 characters.");
  if (draft.intended_use.trim().length < 30) errors.push("Intended use must be at least 30 characters.");
  if (draft.methodology.trim().length < 60) errors.push("Methodology must be at least 60 characters.");
  if (draft.limitations.trim().length < 30) errors.push("Limitations must be at least 30 characters.");
  const columns = draft.data_dictionary.filter((column) => column.name.trim());
  if (columns.length < 2) errors.push("Add at least two data dictionary entries with a name and type.");
  if (columns.some((column) => !column.type.trim())) errors.push("Every data dictionary entry needs a type.");
  if (!draft.sample_data.length) errors.push("Paste sample data with a header row and at least one data row.");
  if (draft.rows_count < 1) errors.push("Row count must be at least 1.");
  return errors;
}

export function SubmissionForm({
  draft,
  onChange,
  disabled,
}: {
  draft: SubmissionDraft;
  onChange: (next: SubmissionDraft) => void;
  disabled?: boolean;
}) {
  const [sampleError, setSampleError] = useState("");
  const set = <K extends keyof SubmissionDraft>(key: K, value: SubmissionDraft[K]) =>
    onChange({ ...draft, [key]: value });

  const setColumn = (index: number, patch: Partial<DatasetColumn>) => {
    const next = draft.data_dictionary.map((column, i) => (i === index ? { ...column, ...patch } : column));
    set("data_dictionary", next);
  };

  return (
    <fieldset disabled={disabled} className="space-y-10 disabled:opacity-70">
      <Block title="Dataset identity" hint="How this release is listed in the repository.">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Title" required>
            <Input
              value={draft.title}
              onChange={(e) =>
                onChange({ ...draft, title: e.target.value, slug: draft.slug || slugify(e.target.value) })
              }
              placeholder="Nigerian Retail Transactions"
            />
          </Field>
          <Field label="URL slug" required>
            <Input value={draft.slug} onChange={(e) => set("slug", slugify(e.target.value))} placeholder="nigerian-retail-transactions" />
          </Field>
          <Field label="Category / domain" required>
            <Picker value={draft.domain} onChange={(v) => set("domain", v)} options={["Financial Services", "Telecommunications", "Education", "Insurance", "Agriculture", "Health", "Energy", "Retail", "Transport"]} />
          </Field>
          <Field label="Format" required>
            <Picker value={draft.format} onChange={(v) => set("format", v)} options={["CSV", "JSON", "CSV + JSON"]} />
          </Field>
          <Field label="Task type" required>
            <Picker value={draft.task} onChange={(v) => set("task", v)} options={["Classification", "Regression", "Classification / Regression", "Clustering", "Forecasting"]} />
          </Field>
          <Field label="Difficulty">
            <Picker value={draft.difficulty} onChange={(v) => set("difficulty", v)} options={["Beginner", "Intermediate", "Advanced"]} />
          </Field>
          <Field label="Country">
            <Input value={draft.country} onChange={(e) => set("country", e.target.value)} />
          </Field>
          <Field label="Licence">
            <Picker value={draft.license} onChange={(v) => set("license", v)} options={["CC BY 4.0", "CC BY-SA 4.0", "CC0 1.0", "ODC-BY 1.0"]} />
          </Field>
          <Field label="Version">
            <Input value={draft.version} onChange={(e) => set("version", e.target.value)} placeholder="1.0.0" />
          </Field>
          <Field label="Row count">
            <Input type="number" min={1} value={draft.rows_count} onChange={(e) => set("rows_count", Number(e.target.value))} />
          </Field>
          <Field label="Authors (comma separated)">
            <Input value={draft.authors} onChange={(e) => set("authors", e.target.value)} placeholder="A. Bello, C. Okafor" />
          </Field>
        </div>
      </Block>

      <Block title="Documentation" hint="Every published IYEOB dataset documents what it is for and where it falls short.">
        <div className="space-y-4">
          <Field label="Description" required>
            <Textarea rows={4} value={draft.description} onChange={(e) => set("description", e.target.value)} placeholder="What this synthetic dataset represents…" />
          </Field>
          <Field label="Intended use" required>
            <Textarea rows={3} value={draft.intended_use} onChange={(e) => set("intended_use", e.target.value)} />
          </Field>
          <Field label="Methodology" required>
            <Textarea rows={4} value={draft.methodology} onChange={(e) => set("methodology", e.target.value)} placeholder="How the synthetic records were generated and which relationships were modelled…" />
          </Field>
          <Field label="Assumptions (one per line)">
            <Textarea rows={3} value={draft.assumptions} onChange={(e) => set("assumptions", e.target.value)} />
          </Field>
          <Field label="Limitations (one per line)" required>
            <Textarea rows={3} value={draft.limitations} onChange={(e) => set("limitations", e.target.value)} />
          </Field>
        </div>
      </Block>

      <Block title="Data dictionary" hint="Name and type are required for each variable.">
        <div className="space-y-3">
          {draft.data_dictionary.map((column, index) => (
            <div key={index} className="grid gap-2 border border-border bg-card p-3 sm:grid-cols-[1.1fr_0.8fr_1.6fr_0.8fr_0.8fr_auto]">
              <Input placeholder="Variable name" value={column.name} onChange={(e) => setColumn(index, { name: e.target.value })} />
              <Input placeholder="Type" value={column.type} onChange={(e) => setColumn(index, { type: e.target.value })} />
              <Input placeholder="Description" value={column.description} onChange={(e) => setColumn(index, { description: e.target.value })} />
              <Input placeholder="Example" value={column.example} onChange={(e) => setColumn(index, { example: e.target.value })} />
              <Picker value={column.role} onChange={(v) => setColumn(index, { role: v as DatasetColumn["role"] })} options={["Feature", "Target", "Identifier"]} />
              <Button type="button" variant="ghost" size="icon" aria-label="Remove variable" onClick={() => set("data_dictionary", draft.data_dictionary.filter((_, i) => i !== index))}>
                <Trash2 />
              </Button>
            </div>
          ))}
          <Button type="button" variant="outline" onClick={() => set("data_dictionary", [...draft.data_dictionary, { name: "", type: "string", description: "", example: "", role: "Feature" }])}>
            <Plus />Add variable
          </Button>
        </div>
      </Block>

      <Block title="Sample data" hint="Paste up to 25 comma-separated rows, header row first. This becomes the public preview and download sample.">
        <Textarea
          rows={7}
          className="font-mono text-xs"
          value={draft.sample_raw}
          placeholder={"customer_id,state,amount\nCUS-1,Lagos,24000"}
          onChange={(e) => {
            const raw = e.target.value;
            const parsed = parseSampleCsv(raw);
            setSampleError(raw.trim() && !parsed.length ? "Needs a header row plus at least one data row." : "");
            onChange({ ...draft, sample_raw: raw, sample_data: parsed });
          }}
        />
        <p className="mt-2 text-xs text-muted-foreground">
          {sampleError ? <span className="text-destructive">{sampleError}</span> : `${draft.sample_data.length} sample rows parsed.`}
        </p>
      </Block>
    </fieldset>
  );
}

function Block({ title, hint, children }: { title: string; hint: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="font-display text-xl font-bold">{title}</h2>
      <p className="mb-5 mt-1 text-sm text-muted-foreground">{hint}</p>
      {children}
    </section>
  );
}

function Field({ label, required, children }: { label: string; required?: boolean; children: React.ReactNode }) {
  const id = useId();
  const control = isValidElement(children) ? cloneElement(children as React.ReactElement<{ id?: string }>, { id }) : children;
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>
        {label}
        {required && <span className="ml-1 text-destructive">*</span>}
      </Label>
      {control}
    </div>
  );
}

function Picker({ value, onChange, options, id }: { value: string; onChange: (value: string) => void; options: string[]; id?: string }) {
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger id={id}><SelectValue /></SelectTrigger>
      <SelectContent>{options.map((option) => <SelectItem key={option} value={option}>{option}</SelectItem>)}</SelectContent>
    </Select>
  );
}
