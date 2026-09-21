import { useQuery } from "@tanstack/react-query";

import { supabase } from "@/integrations/supabase/client";
import { datasets as seededDatasets, type Dataset } from "@/lib/datasets";
import { submissionToDataset, type SubmissionRow } from "@/lib/submissions";

async function fetchApproved(): Promise<Dataset[]> {
  const { data, error } = await supabase
    .from("dataset_submissions")
    .select("*")
    .eq("status", "approved")
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data as SubmissionRow[]).map(submissionToDataset);
}

/** Seeded Nigerian datasets plus community submissions approved by an administrator. */
export function usePublishedDatasets() {
  const query = useQuery({ queryKey: ["published-datasets"], queryFn: fetchApproved });
  const approved = query.data ?? [];
  const seededSlugs = new Set(seededDatasets.map((dataset) => dataset.slug));
  return {
    datasets: [...seededDatasets, ...approved.filter((dataset) => !seededSlugs.has(dataset.slug))],
    isLoading: query.isLoading,
  };
}

export function usePublishedDataset(slug: string) {
  const { datasets, isLoading } = usePublishedDatasets();
  return { dataset: datasets.find((dataset) => dataset.slug === slug) ?? null, isLoading };
}
