-- Roles
CREATE TYPE public.app_role AS ENUM ('admin', 'contributor');
CREATE TYPE public.submission_status AS ENUM ('draft', 'submitted', 'under_review', 'approved', 'rejected');

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  full_name text,
  organization text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own profile read" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "own profile insert" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "own profile update" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own roles read" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE POLICY "admins read roles" ON public.user_roles FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Auto profile + default contributor role
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''))
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'contributor')
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Submissions
CREATE TABLE public.dataset_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  short_title text NOT NULL DEFAULT '',
  domain text NOT NULL,
  task text NOT NULL DEFAULT 'Classification',
  difficulty text NOT NULL DEFAULT 'Intermediate',
  country text NOT NULL DEFAULT 'Nigeria',
  format text NOT NULL DEFAULT 'CSV',
  license text NOT NULL DEFAULT 'CC BY 4.0',
  version text NOT NULL DEFAULT '1.0.0',
  authors text NOT NULL DEFAULT '',
  rows_count integer NOT NULL DEFAULT 0,
  description text NOT NULL,
  intended_use text NOT NULL,
  methodology text NOT NULL,
  limitations text NOT NULL,
  assumptions text NOT NULL DEFAULT '',
  data_dictionary jsonb NOT NULL DEFAULT '[]'::jsonb,
  sample_data jsonb NOT NULL DEFAULT '[]'::jsonb,
  status public.submission_status NOT NULL DEFAULT 'draft',
  review_notes text,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  submitted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dataset_submissions TO authenticated;
GRANT SELECT ON public.dataset_submissions TO anon;
GRANT ALL ON public.dataset_submissions TO service_role;
ALTER TABLE public.dataset_submissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public reads approved" ON public.dataset_submissions FOR SELECT TO anon, authenticated USING (status = 'approved');
CREATE POLICY "owners read own" ON public.dataset_submissions FOR SELECT TO authenticated USING (auth.uid() = submitted_by);
CREATE POLICY "admins read all" ON public.dataset_submissions FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "owners insert own" ON public.dataset_submissions FOR INSERT TO authenticated WITH CHECK (auth.uid() = submitted_by);
CREATE POLICY "owners update own editable" ON public.dataset_submissions FOR UPDATE TO authenticated
  USING (auth.uid() = submitted_by AND status IN ('draft','rejected','submitted'))
  WITH CHECK (auth.uid() = submitted_by);
CREATE POLICY "admins update all" ON public.dataset_submissions FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "owners delete own drafts" ON public.dataset_submissions FOR DELETE TO authenticated
  USING (auth.uid() = submitted_by AND status IN ('draft','rejected'));
CREATE POLICY "admins delete any" ON public.dataset_submissions FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
CREATE TRIGGER dataset_submissions_touch BEFORE UPDATE ON public.dataset_submissions
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Analytics
CREATE TABLE public.analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  dataset_slug text,
  search_query text,
  filters jsonb NOT NULL DEFAULT '{}'::jsonb,
  file_format text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX analytics_events_created_idx ON public.analytics_events (created_at DESC);
CREATE INDEX analytics_events_type_idx ON public.analytics_events (event_type);
GRANT INSERT ON public.analytics_events TO anon, authenticated;
GRANT SELECT ON public.analytics_events TO authenticated;
GRANT ALL ON public.analytics_events TO service_role;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone logs events" ON public.analytics_events FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "admins read analytics" ON public.analytics_events FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));