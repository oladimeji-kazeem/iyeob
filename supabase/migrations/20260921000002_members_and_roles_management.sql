-- ============================================================
-- IYEOB MEMBERS, ROLES, PERMISSIONS & ACCESS MANAGEMENT
-- Migration: 20260921000002_members_and_roles_management.sql
-- ============================================================

BEGIN;

-- 1. Ensure admin_invites supports preset roles
ALTER TABLE public.admin_invites
ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'admin';

-- 2. Ensure RLS policies on users allows admins to manage user records
DROP POLICY IF EXISTS "Admins can update users" ON public.users;
CREATE POLICY "Admins can update users"
ON public.users
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can read all users" ON public.users;
CREATE POLICY "Admins can read all users"
ON public.users
FOR SELECT TO authenticated
USING (public.is_admin() OR auth.uid() = id);

-- 3. Comprehensive member listing RPC with roles, permissions, organisation & status
CREATE OR REPLACE FUNCTION public.list_workspace_members_full()
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    display_name TEXT,
    status TEXT,
    roles TEXT[],
    permissions TEXT[],
    organisation_id UUID,
    organisation_name TEXT,
    created_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    email_verified BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        u.id AS user_id,
        u.email::TEXT,
        COALESCE(u.display_name, trim(concat(u.first_name, ' ', u.last_name)), u.email)::TEXT AS display_name,
        u.status::TEXT,
        COALESCE(ARRAY(
            SELECT DISTINCT r.name::TEXT
            FROM public.user_roles ur
            JOIN public.roles r ON r.id = ur.role_id
            WHERE ur.user_id = u.id
            ORDER BY r.name::TEXT
        ), ARRAY['USER']::TEXT[]) AS roles,
        COALESCE(ARRAY(
            SELECT DISTINCT p.name::TEXT
            FROM public.user_roles ur
            JOIN public.role_permissions rp ON rp.role_id = ur.role_id
            JOIN public.permissions p ON p.id = rp.permission_id
            WHERE ur.user_id = u.id
            ORDER BY p.name::TEXT
        ), '{}'::TEXT[]) AS permissions,
        u.organisation_id,
        org.name::TEXT AS organisation_name,
        u.created_at,
        u.last_login_at,
        u.email_verified
    FROM public.users u
    LEFT JOIN public.organisations org ON org.id = u.organisation_id
    WHERE public.is_admin()
    ORDER BY u.created_at DESC;
$$;

-- 4. Role Assignment RPC
CREATE OR REPLACE FUNCTION public.assign_user_role(_user_id UUID, _role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    _email TEXT;
    _target_role_id UUID;
    _clean_role TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can assign roles.';
    END IF;

    _clean_role := upper(trim(_role));

    -- Find role ID
    SELECT id INTO _target_role_id
    FROM public.roles
    WHERE upper(name) = _clean_role;

    IF _target_role_id IS NULL THEN
        RAISE EXCEPTION 'Role % does not exist.', _clean_role;
    END IF;

    -- Insert into user_roles
    INSERT INTO public.user_roles (user_id, role_id, role)
    VALUES (_user_id, _target_role_id, lower(_clean_role))
    ON CONFLICT (user_id, role_id) DO UPDATE SET role = lower(_clean_role);

    -- Audit log
    SELECT email INTO _email FROM auth.users WHERE id = _user_id;
    PERFORM public.write_audit(
        'role.assigned',
        'user',
        _user_id::TEXT,
        _email,
        jsonb_build_object('role', _clean_role)
    );
END;
$$;

-- 5. Role Revocation RPC
CREATE OR REPLACE FUNCTION public.remove_user_role(_user_id UUID, _role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    _email TEXT;
    _target_role_id UUID;
    _admin_role_id UUID;
    _admin_count INT;
    _clean_role TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can revoke roles.';
    END IF;

    _clean_role := upper(trim(_role));

    -- If removing admin role, enforce at least one admin remains
    IF _clean_role = 'ADMIN' THEN
        SELECT id INTO _admin_role_id FROM public.roles WHERE upper(name) = 'ADMIN';
        SELECT count(*) INTO _admin_count
        FROM public.user_roles
        WHERE role_id = _admin_role_id OR upper(coalesce(role, '')) = 'ADMIN';

        IF _admin_count <= 1 THEN
            RAISE EXCEPTION 'Cannot revoke the last remaining administrator in the workspace.';
        END IF;
    END IF;

    -- Find role ID
    SELECT id INTO _target_role_id
    FROM public.roles
    WHERE upper(name) = _clean_role;

    IF _target_role_id IS NOT NULL THEN
        DELETE FROM public.user_roles
        WHERE user_id = _user_id
          AND (role_id = _target_role_id OR upper(coalesce(role, '')) = _clean_role);
    ELSE
        DELETE FROM public.user_roles
        WHERE user_id = _user_id
          AND upper(coalesce(role, '')) = _clean_role;
    END IF;

    -- Audit log
    SELECT email INTO _email FROM auth.users WHERE id = _user_id;
    PERFORM public.write_audit(
        'role.revoked',
        'user',
        _user_id::TEXT,
        _email,
        jsonb_build_object('role', _clean_role)
    );
END;
$$;

-- 6. Set User Status RPC
CREATE OR REPLACE FUNCTION public.set_user_status(_user_id UUID, _status TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    _email TEXT;
    _clean_status user_status;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can modify user access status.';
    END IF;

    _clean_status := upper(trim(_status))::user_status;

    -- Cannot suspend self
    IF _clean_status = 'SUSPENDED' AND _user_id = auth.uid() THEN
        RAISE EXCEPTION 'You cannot suspend your own administrative account.';
    END IF;

    UPDATE public.users
    SET status = _clean_status,
        updated_at = NOW()
    WHERE id = _user_id;

    SELECT email INTO _email FROM auth.users WHERE id = _user_id;
    PERFORM public.write_audit(
        'user.status_changed',
        'user',
        _user_id::TEXT,
        _email,
        jsonb_build_object('status', _clean_status::TEXT)
    );
END;
$$;

-- 7. Set User Organisation RPC
CREATE OR REPLACE FUNCTION public.set_user_organisation(_user_id UUID, _organisation_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    _email TEXT;
    _org_name TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can assign member organisations.';
    END IF;

    UPDATE public.users
    SET organisation_id = _organisation_id,
        updated_at = NOW()
    WHERE id = _user_id;

    SELECT name INTO _org_name FROM public.organisations WHERE id = _organisation_id;
    SELECT email INTO _email FROM auth.users WHERE id = _user_id;

    PERFORM public.write_audit(
        'user.organisation_assigned',
        'user',
        _user_id::TEXT,
        _email,
        jsonb_build_object('organisation_id', _organisation_id, 'organisation_name', _org_name)
    );
END;
$$;

-- 8. List all system roles and their permission matrix
CREATE OR REPLACE FUNCTION public.list_all_system_roles_and_permissions()
RETURNS TABLE (
    role_id UUID,
    role_name TEXT,
    description TEXT,
    user_count BIGINT,
    permissions TEXT[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        r.id AS role_id,
        r.name::TEXT AS role_name,
        r.description::TEXT,
        (
            SELECT count(DISTINCT ur.user_id)
            FROM public.user_roles ur
            WHERE ur.role_id = r.id OR upper(coalesce(ur.role, '')) = upper(r.name)
        ) AS user_count,
        COALESCE(ARRAY(
            SELECT p.name::TEXT
            FROM public.role_permissions rp
            JOIN public.permissions p ON p.id = rp.permission_id
            WHERE rp.role_id = r.id
            ORDER BY p.name::TEXT
        ), '{}'::TEXT[]) AS permissions
    FROM public.roles r
    ORDER BY
        CASE upper(r.name)
            WHEN 'ADMIN' THEN 1
            WHEN 'PUBLISHER' THEN 2
            WHEN 'REVIEWER' THEN 3
            WHEN 'DATA_EDITOR' THEN 4
            WHEN 'EDITOR' THEN 5
            WHEN 'RESEARCHER' THEN 6
            WHEN 'DEVELOPER' THEN 7
            ELSE 8
        END;
$$;

-- 9. Grants
GRANT EXECUTE ON FUNCTION public.list_workspace_members_full() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_user_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_user_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_organisation(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_all_system_roles_and_permissions() TO authenticated;

COMMIT;
