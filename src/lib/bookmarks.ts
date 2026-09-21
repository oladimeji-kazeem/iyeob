import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";

export type BookmarkRow = {
  id: string;
  dataset_slug: string;
  dataset_title: string;
  created_at: string;
};

export function useBookmarks() {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: ["bookmarks", user?.id],
    enabled: Boolean(user?.id),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("bookmarks")
        .select("id, dataset_slug, dataset_title, created_at")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data as BookmarkRow[];
    },
  });

  const bookmarks = query.data ?? [];
  const slugs = new Set(bookmarks.map((row) => row.dataset_slug));

  const toggle = useMutation({
    mutationFn: async ({ slug, title }: { slug: string; title: string }) => {
      if (!user) throw new Error("Sign in to bookmark datasets");
      if (slugs.has(slug)) {
        const { error } = await supabase.from("bookmarks").delete().eq("dataset_slug", slug).eq("user_id", user.id);
        if (error) throw error;
        return "removed" as const;
      }
      const { error } = await supabase
        .from("bookmarks")
        .insert({ user_id: user.id, dataset_slug: slug, dataset_title: title });
      if (error) throw error;
      return "added" as const;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["bookmarks"] }),
  });

  return {
    bookmarks,
    isLoading: query.isLoading,
    isBookmarked: (slug: string) => slugs.has(slug),
    toggle,
  };
}
