import { supabase } from "@/integrations/supabase/client";

export type AnalyticsEvent = {
  event_type: "dataset_view" | "search" | "download" | "filter";
  dataset_slug?: string | null;
  search_query?: string | null;
  filters?: Record<string, string> | null;
  file_format?: string | null;
};

/** Fire-and-forget usage logging. Never blocks or breaks the UI. */
export function trackEvent(event: AnalyticsEvent) {
  if (typeof window === "undefined") return;
  void supabase
    .from("analytics_events")
    .insert({
      event_type: event.event_type,
      dataset_slug: event.dataset_slug ?? null,
      search_query: event.search_query ?? null,
      filters: event.filters ?? {},
      file_format: event.file_format ?? null,
    })
    .then(() => undefined);
}

export function describeFilters(filters: Record<string, string>) {
  const active = Object.entries(filters).filter(([, value]) => value && value !== "all");
  if (!active.length) return "No filters";
  return active.map(([key, value]) => `${key}: ${value}`).join(" · ");
}
