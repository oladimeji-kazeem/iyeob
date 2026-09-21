import type { Dataset, DatasetColumn } from "@/lib/datasets";
import type { Database } from "@/integrations/supabase/types";

export type SubmissionRow = Database["public"]["Tables"]["dataset_submissions"]["Row"];
export type SubmissionStatus = SubmissionRow["status"];

export const STATUS_FLOW: SubmissionStatus[] = ["draft", "submitted", "under_review", "approved", "rejected"];

export const STATUS_LABEL: Record<SubmissionStatus, string> = {
  draft: "Draft",
  submitted: "Submitted",
  under_review: "Under review",
  approved: "Approved",
  rejected: "Rejected",
};

export const STATUS_STYLE: Record<SubmissionStatus, string> = {
  draft: "bg-muted text-muted-foreground",
  submitted: "bg-primary/10 text-primary",
  under_review: "bg-highlight text-highlight-foreground",
  approved: "bg-synthetic text-synthetic-foreground",
  rejected: "bg-destructive/10 text-destructive",
};

export function slugify(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "")
    .slice(0, 80);
}

function splitLines(value: string) {
  return value
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function documentationScore(row: SubmissionRow) {
  const checks = [
    row.description.length > 60,
    row.intended_use.length > 30,
    row.methodology.length > 60,
    row.limitations.length > 30,
    row.assumptions.length > 10,
    Array.isArray(row.data_dictionary) && row.data_dictionary.length > 0,
    Array.isArray(row.sample_data) && row.sample_data.length > 0,
  ];
  return Math.round((checks.filter(Boolean).length / checks.length) * 100);
}

/** Turns an approved community submission into the same shape the catalog renders. */
export function submissionToDataset(row: SubmissionRow): Dataset {
  const columns = (row.data_dictionary as unknown as DatasetColumn[]) ?? [];
  const preview = (row.sample_data as unknown as Record<string, string | number>[]) ?? [];
  const score = documentationScore(row);

  return {
    slug: row.slug,
    title: row.title,
    shortTitle: row.short_title || row.title,
    domain: row.domain,
    task: row.task,
    difficulty: (row.difficulty as Dataset["difficulty"]) ?? "Intermediate",
    country: row.country,
    rows: row.rows_count,
    size: `${Math.max(1, Math.round((row.rows_count * Math.max(columns.length, 1) * 12) / 1024 / 1024))} MB`,
    version: row.version,
    quality: score,
    completeness: score,
    privacy: 100,
    fidelity: Math.max(60, score - 5),
    description: row.description,
    intendedUse: row.intended_use,
    methodology: row.methodology,
    assumptions: splitLines(row.assumptions),
    limitations: splitLines(row.limitations),
    researchQuestions: [],
    license: row.license,
    authors: row.authors ? row.authors.split(",").map((a) => a.trim()).filter(Boolean) : undefined,
    columns,
    preview,
  };
}
