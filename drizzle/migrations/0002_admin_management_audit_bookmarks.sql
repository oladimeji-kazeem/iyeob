-- 1. Admin read access to profiles (needed for member management UI)
CREATE POLICY "admins read all profiles" ON public.profiles
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- 2. Audit log -------------------------------------------------------------
CREATE TABLE public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid,
  actor_email text,
  event_type text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  entity_label text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.audit_log TO authenticated;
GRANT ALL ON public.audit_log TO service_role;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admins read audit log" ON public.audit_log
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE INDEX audit_log_created_idx ON public.audit_log (created_at DESC);
CREATE INDEX audit_log_event_idx ON public.audit_log (event_type);
CREATE INDEX audit_log_actor_idx ON public.audit_log (actor_id);

CREATE OR REPLACE FUNCTION public.write_audit(
  _event_type text, _entity_type text, _entity_id text,
  _entity_label text, _details jsonb
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _email text;
BEGIN
  SELECT email INTO _email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.audit_log (actor_id, actor_email, event_type, entity_type, entity_id, entity_label, details)
  VALUES (auth.uid(), _email, _event_type, _entity_type, _entity_id, _entity_label, COALESCE(_details, '{}'::jsonb));
END;
$$;

-- Automatic audit of submission lifecycle + metadata edits
CREATE OR REPLACE FUNCTION public.audit_submission_changes()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _email text; _changed text[];
BEGIN
  SELECT email INTO _email FROM auth.users WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_log (actor_id, actor_email, event_type, entity_type, entity_id, entity_label, details)
    VALUES (auth.uid(), _email, 'submission.created', 'dataset', NEW.id::text, NEW.title,
            jsonb_build_object('status', NEW.status));
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_log (actor_id, actor_email, event_type, entity_type, entity_id, entity_label, details)
    VALUES (auth.uid(), _email, 'submission.deleted', 'dataset', OLD.id::text, OLD.title,
            jsonb_build_object('status', OLD.status));
    RETURN OLD;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.audit_log (actor_id, actor_email, event_type, entity_type, entity_id, entity_label, details)
    VALUES (auth.uid(), _email,
            CASE WHEN NEW.status = 'approved' THEN 'publication.published'
                 WHEN OLD.status = 'approved' THEN 'publication.unpublished'
                 ELSE 'submission.status_changed' END,
            'dataset', NEW.id::text, NEW.title,
            jsonb_build_object('from', OLD.status, 'to', NEW.status, 'notes', NEW.review_notes));
  END IF;

  _changed := ARRAY(
    SELECT k FROM (VALUES
      ('title', NEW.title IS DISTINCT FROM OLD.title),
      ('description', NEW.description IS DISTINCT FROM OLD.description),
      ('domain', NEW.domain IS DISTINCT FROM OLD.domain),
      ('task', NEW.task IS DISTINCT FROM OLD.task),
      ('format', NEW.format IS DISTINCT FROM OLD.format),
      ('license', NEW.license IS DISTINCT FROM OLD.license),
      ('version', NEW.version IS DISTINCT FROM OLD.version),
      ('methodology', NEW.methodology IS DISTINCT FROM OLD.methodology),
      ('limitations', NEW.limitations IS DISTINCT FROM OLD.limitations),
      ('intended_use', NEW.intended_use IS DISTINCT FROM OLD.intended_use),
      ('data_dictionary', NEW.data_dictionary IS DISTINCT FROM OLD.data_dictionary),
      ('sample_data', NEW.sample_data IS DISTINCT FROM OLD.sample_data)
    ) AS t(k, changed) WHERE changed
  );

  IF array_length(_changed, 1) > 0 THEN
    INSERT INTO public.audit_log (actor_id, actor_email, event_type, entity_type, entity_id, entity_label, details)
    VALUES (auth.uid(), _email, 'dataset.metadata_edited', 'dataset', NEW.id::text, NEW.title,
            jsonb_build_object('fields', to_jsonb(_changed)));
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER dataset_submissions_audit
AFTER INSERT OR UPDATE OR DELETE ON public.dataset_submissions
FOR EACH ROW EXECUTE FUNCTION public.audit_submission_changes();

-- 3. Admin invitations ------------------------------------------------------
CREATE TABLE public.admin_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  invited_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, DELETE ON public.admin_invites TO authenticated;
GRANT ALL ON public.admin_invites TO service_role;
ALTER TABLE public.admin_invites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admins read invites" ON public.admin_invites
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "admins create invites" ON public.admin_invites
  FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "admins delete invites" ON public.admin_invites
  FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- 4. Role management with safeguards ---------------------------------------
CREATE OR REPLACE FUNCTION public.grant_admin(_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _email text;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Only administrators can change roles';
  END IF;
  INSERT INTO public.user_roles (user_id, role) VALUES (_user_id, 'admin')
  ON CONFLICT (user_id, role) DO NOTHING;
  SELECT email INTO _email FROM auth.users WHERE id = _user_id;
  PERFORM public.write_audit('role.granted', 'user', _user_id::text, _email, jsonb_build_object('role', 'admin'));
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_admin(_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _email text; _admin_count int;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Only administrators can change roles';
  END IF;
  SELECT count(*) INTO _admin_count FROM public.user_roles WHERE role = 'admin';
  IF _admin_count <= 1 THEN
    RAISE EXCEPTION 'Cannot revoke the last remaining administrator';
  END IF;
  DELETE FROM public.user_roles WHERE user_id = _user_id AND role = 'admin';
  SELECT email INTO _email FROM auth.users WHERE id = _user_id;
  PERFORM public.write_audit('role.revoked', 'user', _user_id::text, _email, jsonb_build_object('role', 'admin'));
END;
$$;

-- Invited emails become administrators automatically on signup; the
-- first-user bootstrap is retained for a brand new workspace.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''))
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'contributor')
  ON CONFLICT (user_id, role) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE role = 'admin') THEN
    INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'admin')
    ON CONFLICT (user_id, role) DO NOTHING;
    INSERT INTO public.audit_log (actor_id, actor_email, event_type, entity_type, entity_id, entity_label, details)
    VALUES (NEW.id, NEW.email, 'role.granted', 'user', NEW.id::text, NEW.email,
            jsonb_build_object('role', 'admin', 'reason', 'workspace bootstrap'));
  ELSIF EXISTS (SELECT 1 FROM public.admin_invites WHERE lower(email) = lower(NEW.email) AND accepted_at IS NULL) THEN
    INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'admin')
    ON CONFLICT (user_id, role) DO NOTHING;
    UPDATE public.admin_invites SET accepted_at = now() WHERE lower(email) = lower(NEW.email);
    INSERT INTO public.audit_log (actor_id, actor_email, event_type, entity_type, entity_id, entity_label, details)
    VALUES (NEW.id, NEW.email, 'role.granted', 'user', NEW.id::text, NEW.email,
            jsonb_build_object('role', 'admin', 'reason', 'invitation accepted'));
  END IF;

  RETURN NEW;
END;
$$;

-- Admin-visible member directory (email + roles) without exposing auth schema
CREATE OR REPLACE FUNCTION public.list_workspace_members()
RETURNS TABLE (user_id uuid, email text, full_name text, roles text[], created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.id, p.email, p.full_name,
         COALESCE(ARRAY(SELECT r.role::text FROM public.user_roles r WHERE r.user_id = p.id ORDER BY r.role::text), '{}'),
         p.created_at
  FROM public.profiles p
  WHERE public.has_role(auth.uid(), 'admin')
  ORDER BY p.created_at;
$$;

-- 5. Bookmarks & saved searches --------------------------------------------
CREATE TABLE public.bookmarks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dataset_slug text NOT NULL,
  dataset_title text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, dataset_slug)
);

GRANT SELECT, INSERT, DELETE ON public.bookmarks TO authenticated;
GRANT ALL ON public.bookmarks TO service_role;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own bookmarks read" ON public.bookmarks FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own bookmarks insert" ON public.bookmarks FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own bookmarks delete" ON public.bookmarks FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE TABLE public.saved_searches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  query text NOT NULL DEFAULT '',
  filters jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_searches TO authenticated;
GRANT ALL ON public.saved_searches TO service_role;
ALTER TABLE public.saved_searches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own searches read" ON public.saved_searches FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own searches insert" ON public.saved_searches FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own searches update" ON public.saved_searches FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own searches delete" ON public.saved_searches FOR DELETE TO authenticated USING (auth.uid() = user_id);