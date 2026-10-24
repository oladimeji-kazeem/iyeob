import { createFileRoute, Outlet, redirect } from "@tanstack/react-router";

import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/admin")({
  beforeLoad: async () => {
    const { data: userData } = await supabase.auth.getUser();
    if (!userData.user) throw redirect({ to: "/auth" });
    let isAdmin = false;
    try {
      const { data: rpcIsAdmin } = await supabase.rpc("is_admin");
      if (rpcIsAdmin) isAdmin = true;
    } catch {
      // Fallback to table check below
    }

    if (!isAdmin) {
      const { data: roles } = await supabase
        .from("user_roles")
        .select("role")
        .eq("user_id", userData.user.id);
      isAdmin = (roles ?? []).some((r: { role?: string }) => r.role?.toLowerCase() === "admin");
    }

    if (!isAdmin) throw redirect({ to: "/submissions" });
    return {};
  },
  component: () => <Outlet />,
});
