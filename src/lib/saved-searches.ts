import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";

export type SavedSearchFilters = { domain: string; task: string; difficulty: string; sort: string };

export type SavedSearchRow = {
  id: string;
  name: string;
  query: string;
  filters: SavedSearchFilters;
  created_at: string;
};

export function describeSavedSearch(row: SavedSearchRow) {
  const parts: string[] = [];
  if (row.query) parts.push(`"${row.query}"`);
  const { domain, task, difficulty, sort } = row.filters ?? ({} as SavedSearchFilters);
  if (domain && domain !== "all") parts.push(domain);
  if (task && task !== "all") parts.push(task);
  if (difficulty && difficulty !== "all") parts.push(difficulty);
  if (sort) parts.push(`sorted by ${sort}`);
  return parts.length ? parts.join(" · ") : "All datasets";
}

export function useSavedSearches() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: ["saved-searches", user?.id],
    enabled: Boolean(user?.id),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("saved_searches")
        .select("id, name, query, filters, created_at")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data as unknown as SavedSearchRow[];
    },
  });

  const save = useMutation({
    mutationFn: async ({ name, query: text, filters }: { name: string; query: string; filters: SavedSearchFilters }) => {
      if (!user) throw new Error("Sign in to save searches");
      const { error } = await supabase
        .from("saved_searches")
        .insert({ user_id: user.id, name, query: text, filters });
      if (error) throw error;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["saved-searches"] }),
  });

  const remove = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("saved_searches").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["saved-searches"] }),
  });

  return { searches: query.data ?? [], isLoading: query.isLoading, save, remove };
}
