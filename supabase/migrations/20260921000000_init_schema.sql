-- ============================================================
-- IYEOB — AFRICAN DATA & AI INFRASTRUCTURE
-- SUPABASE / POSTGRESQL DATABASE SCHEMA
--
-- Stage 1: Synthetic Data Repository
-- Future-ready for:
--   Stage 2: Data APIs
--   Stage 3: Localized ML Models
--   Stage 4: Marketplace
--   Stage 5: AI Evaluation & Control
--
-- PostgreSQL / Supabase
-- ============================================================

BEGIN;

-- ============================================================
-- 0. EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- 1. ENUM TYPES
-- ============================================================

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'user_status'
    ) THEN
        CREATE TYPE user_status AS ENUM (
            'ACTIVE',
            'SUSPENDED',
            'INVITED',
            'DEACTIVATED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'dataset_status'
    ) THEN
        CREATE TYPE dataset_status AS ENUM (
            'DRAFT',
            'QUALITY_CHECK',
            'UNDER_REVIEW',
            'APPROVED',
            'PUBLISHED',
            'UPDATED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'dataset_visibility'
    ) THEN
        CREATE TYPE dataset_visibility AS ENUM (
            'PUBLIC',
            'PRIVATE',
            'UNLISTED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'version_status'
    ) THEN
        CREATE TYPE version_status AS ENUM (
            'DRAFT',
            'PROCESSING',
            'READY',
            'PUBLISHED',
            'ARCHIVED',
            'FAILED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'quality_status'
    ) THEN
        CREATE TYPE quality_status AS ENUM (
            'PENDING',
            'RUNNING',
            'PASSED',
            'FAILED',
            'REQUIRES_REVIEW'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'review_status'
    ) THEN
        CREATE TYPE review_status AS ENUM (
            'PENDING',
            'IN_PROGRESS',
            'APPROVED',
            'REJECTED',
            'CHANGES_REQUIRED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'submission_status'
    ) THEN
        CREATE TYPE submission_status AS ENUM (
            'draft',
            'submitted',
            'under_review',
            'approved',
            'rejected'
        );
    END IF;

END $$;


-- ============================================================
-- 2. GENERIC UPDATED_AT TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


-- ============================================================
-- 3. COUNTRIES
-- ============================================================

CREATE TABLE IF NOT EXISTS countries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    iso2 CHAR(2) NOT NULL UNIQUE,
    iso3 CHAR(3) NOT NULL UNIQUE,

    name VARCHAR(150) NOT NULL UNIQUE,
    continent VARCHAR(100) NOT NULL DEFAULT 'Africa',

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 4. REGIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS regions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    country_id UUID NOT NULL
        REFERENCES countries(id)
        ON DELETE RESTRICT,

    parent_region_id UUID NULL
        REFERENCES regions(id)
        ON DELETE RESTRICT,

    name VARCHAR(150) NOT NULL,
    code VARCHAR(50),

    region_type VARCHAR(50) NOT NULL DEFAULT 'ADMINISTRATIVE',

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_region_country_name
        UNIQUE (country_id, name)
);


-- ============================================================
-- 5. ORGANISATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS organisations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,

    description TEXT,
    website_url TEXT,

    organisation_type VARCHAR(100),

    country_id UUID NULL
        REFERENCES countries(id)
        ON DELETE SET NULL,

    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);


-- ============================================================
-- 6. USERS
--
-- Supabase Auth remains the authentication provider.
-- This table stores IYEOB application profile information.
-- id must correspond to auth.users.id.
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY
        REFERENCES auth.users(id)
        ON DELETE CASCADE,

    email VARCHAR(320) UNIQUE,

    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(200),

    organisation_id UUID NULL
        REFERENCES organisations(id)
        ON DELETE SET NULL,

    status user_status NOT NULL DEFAULT 'ACTIVE',

    email_verified BOOLEAN NOT NULL DEFAULT FALSE,

    last_login_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

-- Profiles table (compatible with auth & member listing)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  full_name text,
  organization text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'own profile read') THEN
    CREATE POLICY "own profile read" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'own profile insert') THEN
    CREATE POLICY "own profile insert" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'own profile update') THEN
    CREATE POLICY "own profile update" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);
  END IF;
END $$;



-- ============================================================
-- 7. ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 8. PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 9. USER ROLES
-- ============================================================

DROP TABLE IF EXISTS user_roles CASCADE;

CREATE TABLE user_roles (
    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE CASCADE,

    role VARCHAR(50), -- Backward-compatible role name string ('admin', 'contributor', etc.)

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, role_id)
);


-- ============================================================
-- 10. ROLE PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL
        REFERENCES roles(id)
        ON DELETE CASCADE,

    permission_id UUID NOT NULL
        REFERENCES permissions(id)
        ON DELETE CASCADE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (role_id, permission_id)
);


-- ============================================================
-- 11. DOMAINS
-- ============================================================

CREATE TABLE IF NOT EXISTS domains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    parent_domain_id UUID NULL
        REFERENCES domains(id)
        ON DELETE RESTRICT,

    name VARCHAR(150) NOT NULL,
    slug VARCHAR(150) NOT NULL UNIQUE,

    description TEXT,

    icon VARCHAR(100),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    display_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 12. LICENCES
-- ============================================================

CREATE TABLE IF NOT EXISTS licenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(255) NOT NULL UNIQUE,
    short_name VARCHAR(100),

    description TEXT,
    url TEXT,

    commercial_use BOOLEAN NOT NULL DEFAULT FALSE,
    modification_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    redistribution_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    attribution_required BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 13. DATASETS
-- ============================================================

CREATE TABLE IF NOT EXISTS datasets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    owner_organisation_id UUID NULL
        REFERENCES organisations(id)
        ON DELETE SET NULL,

    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,

    short_description VARCHAR(500),
    description TEXT,

    dataset_type VARCHAR(100) NOT NULL DEFAULT 'TABULAR',

    task_type VARCHAR(100),

    country_id UUID NOT NULL
        REFERENCES countries(id)
        ON DELETE RESTRICT,

    region_id UUID NULL
        REFERENCES regions(id)
        ON DELETE RESTRICT,

    domain_id UUID NOT NULL
        REFERENCES domains(id)
        ON DELETE RESTRICT,

    status dataset_status NOT NULL DEFAULT 'DRAFT',

    visibility dataset_visibility NOT NULL DEFAULT 'PUBLIC',

    -- Stage 1 policy:
    -- IYEOB datasets are synthetic.
    synthetic BOOLEAN NOT NULL DEFAULT TRUE,

    is_featured BOOLEAN NOT NULL DEFAULT FALSE,

    license_id UUID NULL
        REFERENCES licenses(id)
        ON DELETE SET NULL,

    current_version_id UUID NULL,

    created_by UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    updated_by UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    published_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT chk_dataset_synthetic
        CHECK (synthetic = TRUE)
);


-- ============================================================
-- 14. DATASET VERSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    version VARCHAR(50) NOT NULL,

    version_major INTEGER NOT NULL DEFAULT 1,
    version_minor INTEGER NOT NULL DEFAULT 0,
    version_patch INTEGER NOT NULL DEFAULT 0,

    status version_status NOT NULL DEFAULT 'DRAFT',

    row_count BIGINT NOT NULL DEFAULT 0,
    column_count INTEGER NOT NULL DEFAULT 0,

    file_size_bytes BIGINT NOT NULL DEFAULT 0,

    generation_method TEXT,
    generation_seed VARCHAR(255),

    schema_hash VARCHAR(128),
    content_hash VARCHAR(128),

    release_notes TEXT,
    limitations TEXT,
    assumptions TEXT,

    created_by UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    published_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_dataset_version
        UNIQUE (dataset_id, version),

    CONSTRAINT chk_version_numbers
        CHECK (
            version_major >= 0
            AND version_minor >= 0
            AND version_patch >= 0
        ),

    CONSTRAINT chk_row_count
        CHECK (row_count >= 0),

    CONSTRAINT chk_column_count
        CHECK (column_count >= 0),

    CONSTRAINT chk_file_size
        CHECK (file_size_bytes >= 0)
);


-- Add circular FK after both tables exist.

ALTER TABLE datasets
DROP CONSTRAINT IF EXISTS fk_datasets_current_version;

ALTER TABLE datasets
ADD CONSTRAINT fk_datasets_current_version
FOREIGN KEY (current_version_id)
REFERENCES dataset_versions(id)
ON DELETE SET NULL;


-- ============================================================
-- 15. DATASET FILES
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_version_id UUID NOT NULL
        REFERENCES dataset_versions(id)
        ON DELETE CASCADE,

    file_name VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255),

    storage_provider VARCHAR(50) NOT NULL DEFAULT 'SUPABASE_STORAGE',
    storage_bucket VARCHAR(255),
    storage_key TEXT NOT NULL,

    file_type VARCHAR(50),
    mime_type VARCHAR(100),

    file_size_bytes BIGINT NOT NULL DEFAULT 0,

    checksum_sha256 CHAR(64),

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_dataset_file_size
        CHECK (file_size_bytes >= 0)
);


-- ============================================================
-- 16. DATASET VARIABLES / DATA DICTIONARY
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_variables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_version_id UUID NOT NULL
        REFERENCES dataset_versions(id)
        ON DELETE CASCADE,

    name VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),

    description TEXT,

    data_type VARCHAR(50) NOT NULL,
    semantic_type VARCHAR(100),

    nullable BOOLEAN NOT NULL DEFAULT TRUE,

    unique_value_count BIGINT,

    min_value NUMERIC,
    max_value NUMERIC,
    mean_value NUMERIC,
    median_value NUMERIC,

    example_values JSONB,

    is_target BOOLEAN NOT NULL DEFAULT FALSE,
    is_identifier BOOLEAN NOT NULL DEFAULT FALSE,
    is_sensitive BOOLEAN NOT NULL DEFAULT FALSE,

    measurement_unit VARCHAR(100),

    display_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_dataset_variable
        UNIQUE (dataset_version_id, name)
);


-- ============================================================
-- 17. TAGS
-- ============================================================

CREATE TABLE IF NOT EXISTS tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,

    description TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 18. DATASET TAGS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_tags (
    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    tag_id UUID NOT NULL
        REFERENCES tags(id)
        ON DELETE CASCADE,

    PRIMARY KEY (dataset_id, tag_id)
);


-- ============================================================
-- 19. DATASET METHODOLOGY
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_methodologies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_version_id UUID NOT NULL
        REFERENCES dataset_versions(id)
        ON DELETE CASCADE,

    generation_method VARCHAR(255),

    generation_description TEXT,

    source_inspiration TEXT,
    source_references TEXT,

    synthetic_generation_process TEXT,

    constraints_applied JSONB,
    relationships_modelled JSONB,

    random_seed VARCHAR(255),

    privacy_considerations TEXT,
    bias_considerations TEXT,

    known_limitations TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_methodology_version
        UNIQUE (dataset_version_id)
);


-- ============================================================
-- 20. QUALITY ASSESSMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_quality_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_version_id UUID NOT NULL
        REFERENCES dataset_versions(id)
        ON DELETE CASCADE,

    overall_score NUMERIC(5,2),

    completeness_score NUMERIC(5,2),
    consistency_score NUMERIC(5,2),
    schema_validity_score NUMERIC(5,2),
    relationship_coherence_score NUMERIC(5,2),
    distribution_quality_score NUMERIC(5,2),
    duplicate_score NUMERIC(5,2),
    missing_value_score NUMERIC(5,2),

    row_count BIGINT,
    column_count INTEGER,

    missing_cells BIGINT DEFAULT 0,
    duplicate_rows BIGINT DEFAULT 0,
    invalid_values BIGINT DEFAULT 0,

    status quality_status NOT NULL DEFAULT 'PENDING',

    assessed_by UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    assessed_at TIMESTAMPTZ NULL,

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_quality_scores
        CHECK (
            (overall_score IS NULL OR overall_score BETWEEN 0 AND 100)
            AND
            (completeness_score IS NULL OR completeness_score BETWEEN 0 AND 100)
            AND
            (consistency_score IS NULL OR consistency_score BETWEEN 0 AND 100)
            AND
            (schema_validity_score IS NULL OR schema_validity_score BETWEEN 0 AND 100)
            AND
            (relationship_coherence_score IS NULL OR relationship_coherence_score BETWEEN 0 AND 100)
            AND
            (distribution_quality_score IS NULL OR distribution_quality_score BETWEEN 0 AND 100)
            AND
            (duplicate_score IS NULL OR duplicate_score BETWEEN 0 AND 100)
            AND
            (missing_value_score IS NULL OR missing_value_score BETWEEN 0 AND 100)
        )
);


-- ============================================================
-- 21. QUALITY CHECKS
-- ============================================================

CREATE TABLE IF NOT EXISTS quality_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    quality_assessment_id UUID NOT NULL
        REFERENCES dataset_quality_assessments(id)
        ON DELETE CASCADE,

    check_type VARCHAR(100) NOT NULL,
    check_name VARCHAR(255) NOT NULL,

    status VARCHAR(50) NOT NULL,

    expected_value JSONB,
    actual_value JSONB,

    threshold NUMERIC,

    severity VARCHAR(50),

    message TEXT,

    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 22. DATASET CITATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_citations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    citation_type VARCHAR(50) NOT NULL,

    title TEXT,

    authors TEXT,
    publication_year INTEGER,

    publisher TEXT,
    journal TEXT,
    doi TEXT,
    url TEXT,

    citation_text TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 23. RESEARCH QUESTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS research_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    title VARCHAR(255) NOT NULL,

    question TEXT NOT NULL,
    description TEXT,

    difficulty VARCHAR(50),

    research_area VARCHAR(150),

    recommended_methods JSONB,

    expected_target VARCHAR(255),

    display_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 24. DATASET RECOMMENDATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    recommended_dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    relationship_type VARCHAR(50) NOT NULL,

    reason TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_no_self_recommendation
        CHECK (dataset_id <> recommended_dataset_id),

    CONSTRAINT uq_dataset_recommendation
        UNIQUE (dataset_id, recommended_dataset_id)
);


-- ============================================================
-- 25. ALGORITHMS
-- ============================================================

CREATE TABLE IF NOT EXISTS algorithms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(150) NOT NULL UNIQUE,
    slug VARCHAR(150) NOT NULL UNIQUE,

    description TEXT,

    category VARCHAR(100),
    difficulty VARCHAR(50),

    documentation_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 26. DATASET ALGORITHMS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_algorithms (
    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    algorithm_id UUID NOT NULL
        REFERENCES algorithms(id)
        ON DELETE CASCADE,

    recommended BOOLEAN NOT NULL DEFAULT FALSE,

    reason TEXT,

    difficulty VARCHAR(50),

    PRIMARY KEY (dataset_id, algorithm_id)
);


-- ============================================================
-- 27. DATASET REVIEWS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    dataset_version_id UUID NULL
        REFERENCES dataset_versions(id)
        ON DELETE CASCADE,

    reviewer_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE RESTRICT,

    review_type VARCHAR(50) NOT NULL,

    status review_status NOT NULL DEFAULT 'PENDING',

    comments TEXT,

    reviewed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 28. DOWNLOAD EVENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS download_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE RESTRICT,

    dataset_version_id UUID NOT NULL
        REFERENCES dataset_versions(id)
        ON DELETE RESTRICT,

    user_id UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    organisation_id UUID NULL
        REFERENCES organisations(id)
        ON DELETE SET NULL,

    file_id UUID NULL
        REFERENCES dataset_files(id)
        ON DELETE SET NULL,

    ip_hash VARCHAR(128),
    user_agent TEXT,

    country_code CHAR(2),

    download_status VARCHAR(50) NOT NULL DEFAULT 'SUCCESS',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 29. DATASET VIEW EVENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_view_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE RESTRICT,

    user_id UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    session_id VARCHAR(255),

    referrer TEXT,

    country_code CHAR(2),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 30. SEARCH EVENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS search_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    query TEXT,

    filters JSONB,

    results_count INTEGER NOT NULL DEFAULT 0,

    clicked_dataset_id UUID NULL
        REFERENCES datasets(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 31. AUDIT LOGS
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    organisation_id UUID NULL
        REFERENCES organisations(id)
        ON DELETE SET NULL,

    action VARCHAR(150) NOT NULL,

    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NULL,

    old_values JSONB,
    new_values JSONB,

    ip_hash VARCHAR(128),
    user_agent TEXT,

    request_id VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 32. SYSTEM SETTINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    key VARCHAR(255) NOT NULL UNIQUE,

    value JSONB NOT NULL,

    description TEXT,

    is_public BOOLEAN NOT NULL DEFAULT FALSE,

    updated_by UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 33. FUTURE — API PRODUCTS
-- ============================================================

CREATE TABLE IF NOT EXISTS api_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NULL
        REFERENCES datasets(id)
        ON DELETE SET NULL,

    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,

    description TEXT,

    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS api_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    api_product_id UUID NOT NULL
        REFERENCES api_products(id)
        ON DELETE CASCADE,

    version VARCHAR(50) NOT NULL,

    endpoint TEXT,

    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (api_product_id, version)
);


CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    organisation_id UUID NULL
        REFERENCES organisations(id)
        ON DELETE CASCADE,

    name VARCHAR(255) NOT NULL,

    key_prefix VARCHAR(32) NOT NULL,

    key_hash TEXT NOT NULL UNIQUE,

    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',

    last_used_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ NULL
);


-- ============================================================
-- 34. FUTURE — ML MODELS
-- ============================================================

CREATE TABLE IF NOT EXISTS models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,

    description TEXT,

    model_type VARCHAR(100),

    organisation_id UUID NULL
        REFERENCES organisations(id)
        ON DELETE SET NULL,

    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT',

    created_by UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS model_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    model_id UUID NOT NULL
        REFERENCES models(id)
        ON DELETE CASCADE,

    version VARCHAR(50) NOT NULL,

    framework VARCHAR(100),
    framework_version VARCHAR(100),

    artifact_uri TEXT,

    checksum VARCHAR(128),

    parameters_count BIGINT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (model_id, version)
);


CREATE TABLE IF NOT EXISTS model_datasets (
    model_version_id UUID NOT NULL
        REFERENCES model_versions(id)
        ON DELETE CASCADE,

    dataset_version_id UUID NOT NULL
        REFERENCES dataset_versions(id)
        ON DELETE RESTRICT,

    relationship VARCHAR(50) NOT NULL,

    PRIMARY KEY (model_version_id, dataset_version_id, relationship)
);


-- ============================================================
-- 35. FUTURE — MODEL EVALUATION
-- ============================================================

CREATE TABLE IF NOT EXISTS model_evaluations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    model_version_id UUID NOT NULL
        REFERENCES model_versions(id)
        ON DELETE CASCADE,

    dataset_version_id UUID NOT NULL
        REFERENCES dataset_versions(id)
        ON DELETE RESTRICT,

    evaluation_type VARCHAR(100),

    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',

    overall_score NUMERIC(8,4),

    evaluated_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS model_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    evaluation_id UUID NOT NULL
        REFERENCES model_evaluations(id)
        ON DELETE CASCADE,

    metric_name VARCHAR(100) NOT NULL,

    metric_value NUMERIC(18,8),

    threshold NUMERIC(18,8),

    pass_status BOOLEAN,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 36. FUTURE — AI CONTROL
-- ============================================================

CREATE TABLE IF NOT EXISTS control_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    model_version_id UUID NULL
        REFERENCES model_versions(id)
        ON DELETE CASCADE,

    api_version_id UUID NULL
        REFERENCES api_versions(id)
        ON DELETE CASCADE,

    assessment_type VARCHAR(100) NOT NULL,

    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',

    overall_risk_score NUMERIC(8,4),

    created_by UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_control_target
        CHECK (
            model_version_id IS NOT NULL
            OR api_version_id IS NOT NULL
        )
);


CREATE TABLE IF NOT EXISTS risk_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    control_assessment_id UUID NOT NULL
        REFERENCES control_assessments(id)
        ON DELETE CASCADE,

    risk_type VARCHAR(100) NOT NULL,

    severity VARCHAR(50),
    likelihood VARCHAR(50),

    risk_score NUMERIC(8,4),

    description TEXT,
    mitigation TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS model_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    model_version_id UUID NOT NULL
        REFERENCES model_versions(id)
        ON DELETE RESTRICT,

    control_assessment_id UUID NULL
        REFERENCES control_assessments(id)
        ON DELETE SET NULL,

    incident_type VARCHAR(100) NOT NULL,

    severity VARCHAR(50),

    title VARCHAR(255) NOT NULL,
    description TEXT,

    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ NULL,

    status VARCHAR(50) NOT NULL DEFAULT 'OPEN',

    root_cause TEXT,
    corrective_action TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 37. FUTURE — COMMERCIAL LAYER
-- ============================================================

CREATE TABLE IF NOT EXISTS plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name VARCHAR(100) NOT NULL UNIQUE,

    description TEXT,

    monthly_price NUMERIC(12,2) NOT NULL DEFAULT 0,
    annual_price NUMERIC(12,2) NOT NULL DEFAULT 0,

    dataset_download_limit BIGINT,
    api_request_limit BIGINT,

    features JSONB NOT NULL DEFAULT '{}'::JSONB,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organisation_id UUID NOT NULL
        REFERENCES organisations(id)
        ON DELETE CASCADE,

    plan_id UUID NOT NULL
        REFERENCES plans(id)
        ON DELETE RESTRICT,

    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organisation_id UUID NOT NULL
        REFERENCES organisations(id)
        ON DELETE CASCADE,

    user_id UUID NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    usage_type VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),

    resource_id UUID NULL,

    quantity BIGINT NOT NULL DEFAULT 1,

    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 38. NOTIFICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    type VARCHAR(100) NOT NULL,

    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,

    entity_type VARCHAR(100),
    entity_id UUID,

    read_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 38B. COMMUNITY SUBMISSIONS & TELEMETRY
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    short_title TEXT NOT NULL DEFAULT '',
    domain TEXT NOT NULL,
    task TEXT NOT NULL DEFAULT 'Classification',
    difficulty TEXT NOT NULL DEFAULT 'Intermediate',
    country TEXT NOT NULL DEFAULT 'Nigeria',
    format TEXT NOT NULL DEFAULT 'CSV',
    license TEXT NOT NULL DEFAULT 'CC BY 4.0',
    version TEXT NOT NULL DEFAULT '1.0.0',
    authors TEXT NOT NULL DEFAULT '',
    rows_count INTEGER NOT NULL DEFAULT 0,
    description TEXT NOT NULL,
    intended_use TEXT NOT NULL,
    methodology TEXT NOT NULL,
    limitations TEXT NOT NULL,
    assumptions TEXT NOT NULL DEFAULT '',
    data_dictionary JSONB NOT NULL DEFAULT '[]'::jsonb,
    sample_data JSONB NOT NULL DEFAULT '[]'::jsonb,
    status submission_status NOT NULL DEFAULT 'draft',
    review_notes TEXT,
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    submitted_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    dataset_slug TEXT,
    search_query TEXT,
    filters JSONB NOT NULL DEFAULT '{}'::jsonb,
    file_format TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 39. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_users_organisation
    ON users(organisation_id);

CREATE INDEX IF NOT EXISTS idx_users_status
    ON users(status);

CREATE INDEX IF NOT EXISTS idx_regions_country
    ON regions(country_id);

CREATE INDEX IF NOT EXISTS idx_regions_parent
    ON regions(parent_region_id);

CREATE INDEX IF NOT EXISTS idx_domains_parent
    ON domains(parent_domain_id);

CREATE INDEX IF NOT EXISTS idx_datasets_country
    ON datasets(country_id);

CREATE INDEX IF NOT EXISTS idx_datasets_region
    ON datasets(region_id);

CREATE INDEX IF NOT EXISTS idx_datasets_domain
    ON datasets(domain_id);

CREATE INDEX IF NOT EXISTS idx_datasets_status
    ON datasets(status);

CREATE INDEX IF NOT EXISTS idx_datasets_visibility
    ON datasets(visibility);

CREATE INDEX IF NOT EXISTS idx_datasets_created
    ON datasets(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_datasets_featured
    ON datasets(is_featured)
    WHERE is_featured = TRUE;

CREATE INDEX IF NOT EXISTS idx_dataset_versions_dataset
    ON dataset_versions(dataset_id);

CREATE INDEX IF NOT EXISTS idx_dataset_versions_status
    ON dataset_versions(status);

CREATE INDEX IF NOT EXISTS idx_dataset_files_version
    ON dataset_files(dataset_version_id);

CREATE INDEX IF NOT EXISTS idx_dataset_variables_version
    ON dataset_variables(dataset_version_id);

CREATE INDEX IF NOT EXISTS idx_quality_version
    ON dataset_quality_assessments(dataset_version_id);

CREATE INDEX IF NOT EXISTS idx_quality_status
    ON dataset_quality_assessments(status);

CREATE INDEX IF NOT EXISTS idx_download_dataset
    ON download_events(dataset_id);

CREATE INDEX IF NOT EXISTS idx_download_version
    ON download_events(dataset_version_id);

CREATE INDEX IF NOT EXISTS idx_download_created
    ON download_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_dataset_views_dataset
    ON dataset_view_events(dataset_id);

CREATE INDEX IF NOT EXISTS idx_dataset_views_created
    ON dataset_view_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_search_created
    ON search_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_entity
    ON audit_logs(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_audit_user
    ON audit_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_audit_created
    ON audit_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user
    ON notifications(user_id, read_at);

CREATE INDEX IF NOT EXISTS idx_submissions_status
    ON dataset_submissions(status);

CREATE INDEX IF NOT EXISTS idx_submissions_submitted_by
    ON dataset_submissions(submitted_by);

CREATE INDEX IF NOT EXISTS idx_analytics_created
    ON analytics_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_type
    ON analytics_events(event_type);

-- Full text / fuzzy search
CREATE INDEX IF NOT EXISTS idx_datasets_title_trgm
    ON datasets USING gin(title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_datasets_description_trgm
    ON datasets USING gin(description gin_trgm_ops);


-- ============================================================
-- 40. UPDATED_AT TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS trg_countries_updated_at ON countries;
CREATE TRIGGER trg_countries_updated_at
BEFORE UPDATE ON countries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_regions_updated_at ON regions;
CREATE TRIGGER trg_regions_updated_at
BEFORE UPDATE ON regions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_organisations_updated_at ON organisations;
CREATE TRIGGER trg_organisations_updated_at
BEFORE UPDATE ON organisations
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_domains_updated_at ON domains;
CREATE TRIGGER trg_domains_updated_at
BEFORE UPDATE ON domains
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_licenses_updated_at ON licenses;
CREATE TRIGGER trg_licenses_updated_at
BEFORE UPDATE ON licenses
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_datasets_updated_at ON datasets;
CREATE TRIGGER trg_datasets_updated_at
BEFORE UPDATE ON datasets
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_dataset_versions_updated_at ON dataset_versions;
CREATE TRIGGER trg_dataset_versions_updated_at
BEFORE UPDATE ON dataset_versions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_dataset_files_updated_at ON dataset_files;
CREATE TRIGGER trg_dataset_files_updated_at
BEFORE UPDATE ON dataset_files
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_dataset_variables_updated_at ON dataset_variables;
CREATE TRIGGER trg_dataset_variables_updated_at
BEFORE UPDATE ON dataset_variables
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_methodologies_updated_at ON dataset_methodologies;
CREATE TRIGGER trg_methodologies_updated_at
BEFORE UPDATE ON dataset_methodologies
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_quality_updated_at ON dataset_quality_assessments;
CREATE TRIGGER trg_quality_updated_at
BEFORE UPDATE ON dataset_quality_assessments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_citations_updated_at ON dataset_citations;
CREATE TRIGGER trg_citations_updated_at
BEFORE UPDATE ON dataset_citations
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_questions_updated_at ON research_questions;
CREATE TRIGGER trg_questions_updated_at
BEFORE UPDATE ON research_questions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_reviews_updated_at ON dataset_reviews;
CREATE TRIGGER trg_reviews_updated_at
BEFORE UPDATE ON dataset_reviews
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_api_products_updated_at ON api_products;
CREATE TRIGGER trg_api_products_updated_at
BEFORE UPDATE ON api_products
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_api_versions_updated_at ON api_versions;
CREATE TRIGGER trg_api_versions_updated_at
BEFORE UPDATE ON api_versions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_models_updated_at ON models;
CREATE TRIGGER trg_models_updated_at
BEFORE UPDATE ON models
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_control_updated_at ON control_assessments;
CREATE TRIGGER trg_control_updated_at
BEFORE UPDATE ON control_assessments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_incidents_updated_at ON model_incidents;
CREATE TRIGGER trg_incidents_updated_at
BEFORE UPDATE ON model_incidents
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_plans_updated_at ON plans;
CREATE TRIGGER trg_plans_updated_at
BEFORE UPDATE ON plans
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER trg_subscriptions_updated_at
BEFORE UPDATE ON subscriptions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_dataset_submissions_updated_at ON dataset_submissions;
CREATE TRIGGER trg_dataset_submissions_updated_at
BEFORE UPDATE ON dataset_submissions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================================================
-- 41. SUPABASE AUTH → IYEOB PROFILE TRIGGER (WITH AUTO-ADMIN)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_role_id UUID;
    v_user_role_id UUID;
    v_is_first_user BOOLEAN;
BEGIN

    INSERT INTO public.users (
        id,
        email,
        first_name,
        last_name,
        display_name,
        email_verified
    )
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data ->> 'first_name',
        NEW.raw_user_meta_data ->> 'last_name',
        COALESCE(
            NEW.raw_user_meta_data ->> 'display_name',
            NEW.raw_user_meta_data ->> 'full_name'
        ),
        COALESCE(NEW.email_confirmed_at IS NOT NULL, FALSE)
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(
            NEW.raw_user_meta_data ->> 'display_name',
            NEW.raw_user_meta_data ->> 'full_name'
        )
    )
    ON CONFLICT (id) DO NOTHING;

    -- Fetch role IDs
    SELECT id INTO v_admin_role_id FROM public.roles WHERE name = 'ADMIN';
    SELECT id INTO v_user_role_id FROM public.roles WHERE name = 'USER';

    -- The very first user to sign up automatically becomes the ADMIN
    SELECT NOT EXISTS (
        SELECT 1 FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE r.name = 'ADMIN'
    ) INTO v_is_first_user;

    IF v_is_first_user AND v_admin_role_id IS NOT NULL THEN
        INSERT INTO public.user_roles (user_id, role_id, role)
        VALUES (NEW.id, v_admin_role_id, 'admin')
        ON CONFLICT DO NOTHING;
    ELSIF v_user_role_id IS NOT NULL THEN
        INSERT INTO public.user_roles (user_id, role_id, role)
        VALUES (NEW.id, v_user_role_id, 'user')
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS on_auth_user_created
ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- 42. SEED COUNTRIES
-- ============================================================

INSERT INTO countries (iso2, iso3, name)
VALUES
    ('NG', 'NGA', 'Nigeria'),
    ('GH', 'GHA', 'Ghana'),
    ('KE', 'KEN', 'Kenya'),
    ('ZA', 'ZAF', 'South Africa'),
    ('RW', 'RWA', 'Rwanda'),
    ('TZ', 'TZA', 'Tanzania'),
    ('UG', 'UGA', 'Uganda'),
    ('ET', 'ETH', 'Ethiopia'),
    ('EG', 'EGY', 'Egypt')
ON CONFLICT (iso2) DO NOTHING;


-- ============================================================
-- 43. SEED DOMAINS
-- ============================================================

INSERT INTO domains
    (name, slug, description, display_order)
VALUES
    ('Banking & Finance', 'banking-finance',
        'Financial services, banking, credit, payments and investment.',
        1),

    ('Telecommunications', 'telecommunications',
        'Mobile networks, telecom operations, customer behaviour and connectivity.',
        2),

    ('Insurance', 'insurance',
        'Insurance underwriting, claims, risk and policy analytics.',
        3),

    ('Agriculture', 'agriculture',
        'Agricultural productivity, crops, farmers and food systems.',
        4),

    ('Education', 'education',
        'Students, learning, academic performance and education systems.',
        5),

    ('Healthcare', 'healthcare',
        'Healthcare operations, diagnostics and health-related datasets.',
        6),

    ('Government', 'government',
        'Public-sector and government intelligence datasets.',
        7),

    ('Energy', 'energy',
        'Energy production, consumption and infrastructure.',
        8),

    ('Transportation', 'transportation',
        'Mobility, logistics and transportation intelligence.',
        9),

    ('Retail', 'retail',
        'Retail, consumer behaviour and commerce.',
        10),

    ('Climate', 'climate',
        'Climate, environment and sustainability.',
        11),

    ('Employment', 'employment',
        'Employment, labour markets and workforce intelligence.',
        12),

    ('AI Governance', 'ai-governance',
        'Artificial intelligence governance, evaluation, safety and control.',
        13)

ON CONFLICT (slug) DO NOTHING;


-- ============================================================
-- 44. SEED LICENCES
-- ============================================================

INSERT INTO licenses
(
    name,
    short_name,
    description,
    url,
    commercial_use,
    modification_allowed,
    redistribution_allowed,
    attribution_required
)
VALUES

(
    'Creative Commons Attribution 4.0 International',
    'CC BY 4.0',
    'Creative Commons Attribution 4.0 International licence.',
    'https://creativecommons.org/licenses/by/4.0/',
    TRUE,
    TRUE,
    TRUE,
    TRUE
),

(
    'Creative Commons Attribution-NonCommercial 4.0 International',
    'CC BY-NC 4.0',
    'Creative Commons Attribution-NonCommercial 4.0 International licence.',
    'https://creativecommons.org/licenses/by-nc/4.0/',
    FALSE,
    TRUE,
    TRUE,
    TRUE
)

ON CONFLICT (name) DO NOTHING;


-- ============================================================
-- 45. SEED ROLES
-- ============================================================

INSERT INTO roles (name, description)
VALUES
    ('ADMIN', 'Full system administration privileges.'),
    ('EDITOR', 'Dataset creation and editorial management.'),
    ('REVIEWER', 'Dataset quality and publication review.'),
    ('RESEARCHER', 'Research and dataset usage privileges.'),
    ('DEVELOPER', 'Developer and API-oriented privileges.'),
    ('USER', 'Standard IYEOB user.')
ON CONFLICT (name) DO NOTHING;


-- ============================================================
-- 46. SEED PERMISSIONS
-- ============================================================

INSERT INTO permissions (name, description)
VALUES
    ('dataset:create', 'Create datasets.'),
    ('dataset:read', 'Read datasets.'),
    ('dataset:update', 'Update datasets.'),
    ('dataset:delete', 'Archive/delete datasets.'),
    ('dataset:publish', 'Publish datasets.'),
    ('dataset:archive', 'Archive datasets.'),
    ('dataset:quality_check', 'Run dataset quality checks.'),
    ('dataset:review', 'Review datasets.'),
    ('user:manage', 'Manage users.'),
    ('organisation:manage', 'Manage organisations.'),
    ('analytics:read', 'View analytics.'),
    ('audit:read', 'View audit logs.')
ON CONFLICT (name) DO NOTHING;


-- ============================================================
-- 47. SEED ALGORITHMS
-- ============================================================

INSERT INTO algorithms
(
    name,
    slug,
    description,
    category,
    difficulty
)
VALUES
(
    'Logistic Regression',
    'logistic-regression',
    'Linear classification algorithm.',
    'CLASSIFICATION',
    'BEGINNER'
),
(
    'Decision Tree',
    'decision-tree',
    'Tree-based supervised learning algorithm.',
    'CLASSIFICATION',
    'BEGINNER'
),
(
    'Random Forest',
    'random-forest',
    'Ensemble of decision trees.',
    'CLASSIFICATION',
    'INTERMEDIATE'
),
(
    'XGBoost',
    'xgboost',
    'Gradient boosting algorithm.',
    'CLASSIFICATION',
    'INTERMEDIATE'
),
(
    'Multi-Layer Perceptron',
    'mlp',
    'Feed-forward artificial neural network.',
    'DEEP_LEARNING',
    'INTERMEDIATE'
),
(
    'Support Vector Machine',
    'svm',
    'Maximum-margin supervised learning algorithm.',
    'CLASSIFICATION',
    'INTERMEDIATE'
),
(
    'Linear Regression',
    'linear-regression',
    'Linear regression algorithm.',
    'REGRESSION',
    'BEGINNER'
),
(
    'K-Means',
    'k-means',
    'Unsupervised clustering algorithm.',
    'CLUSTERING',
    'BEGINNER'
)
ON CONFLICT (slug) DO NOTHING;


-- ============================================================
-- 48. SEED TAGS
-- ============================================================

INSERT INTO tags (name, slug, description)
VALUES
    ('Synthetic', 'synthetic', 'Synthetic dataset.'),
    ('Machine Learning', 'machine-learning', 'Suitable for machine learning.'),
    ('Classification', 'classification', 'Classification task.'),
    ('Regression', 'regression', 'Regression task.'),
    ('Tabular', 'tabular', 'Tabular dataset.'),
    ('Research', 'research', 'Suitable for research.'),
    ('Beginner', 'beginner', 'Suitable for beginners.'),
    ('Nigeria', 'nigeria', 'Nigeria-focused dataset.'),
    ('Africa', 'africa', 'Africa-focused dataset.'),
    ('Benchmark', 'benchmark', 'Suitable for benchmarking.')
ON CONFLICT (slug) DO NOTHING;


-- ============================================================
-- 49. DEFAULT SYSTEM SETTINGS
-- ============================================================

INSERT INTO system_settings
    (key, value, description, is_public)
VALUES
(
    'site_name',
    '"IYEOB"',
    'Application name.',
    TRUE
),
(
    'default_country',
    '"NG"',
    'Default country for Stage 1.',
    TRUE
),
(
    'synthetic_data_only',
    'true',
    'Stage 1 accepts synthetic datasets only.',
    TRUE
),
(
    'registration_enabled',
    'true',
    'Whether public registration is enabled.',
    TRUE
),
(
    'maintenance_mode',
    'false',
    'Application maintenance mode.',
    TRUE
)
ON CONFLICT (key) DO NOTHING;


-- ============================================================
-- 50. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;

ALTER TABLE datasets ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_variables ENABLE ROW LEVEL SECURITY;

ALTER TABLE dataset_quality_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quality_checks ENABLE ROW LEVEL SECURITY;

ALTER TABLE research_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_citations ENABLE ROW LEVEL SECURITY;

ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_tags ENABLE ROW LEVEL SECURITY;

ALTER TABLE countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE domains ENABLE ROW LEVEL SECURITY;
ALTER TABLE licenses ENABLE ROW LEVEL SECURITY;

ALTER TABLE dataset_algorithms ENABLE ROW LEVEL SECURITY;
ALTER TABLE algorithms ENABLE ROW LEVEL SECURITY;

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Grants
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT INSERT, UPDATE, DELETE ON dataset_submissions TO authenticated;
GRANT INSERT ON analytics_events TO anon, authenticated;


-- ============================================================
-- 51. PUBLIC DATASET POLICIES
-- ============================================================

DROP POLICY IF EXISTS "Public can read published datasets"
ON datasets;

CREATE POLICY "Public can read published datasets"
ON datasets
FOR SELECT
USING (
    status IN ('PUBLISHED', 'UPDATED')
    AND visibility = 'PUBLIC'
    AND deleted_at IS NULL
);


DROP POLICY IF EXISTS "Public can read published dataset versions"
ON dataset_versions;

CREATE POLICY "Public can read published dataset versions"
ON dataset_versions
FOR SELECT
USING (
    status = 'PUBLISHED'
);


DROP POLICY IF EXISTS "Public can read dataset variables"
ON dataset_variables;

CREATE POLICY "Public can read dataset variables"
ON dataset_variables
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM dataset_versions dv
        JOIN datasets d
          ON d.id = dv.dataset_id
        WHERE dv.id = dataset_variables.dataset_version_id
          AND dv.status = 'PUBLISHED'
          AND d.status IN ('PUBLISHED', 'UPDATED')
          AND d.visibility = 'PUBLIC'
          AND d.deleted_at IS NULL
    )
);


-- ============================================================
-- 52. PUBLIC TAXONOMY POLICIES
-- ============================================================

CREATE POLICY "Public can read active countries"
ON countries
FOR SELECT
USING (is_active = TRUE);


CREATE POLICY "Public can read active regions"
ON regions
FOR SELECT
USING (is_active = TRUE);


CREATE POLICY "Public can read active domains"
ON domains
FOR SELECT
USING (is_active = TRUE);


CREATE POLICY "Public can read licenses"
ON licenses
FOR SELECT
USING (TRUE);


CREATE POLICY "Public can read tags"
ON tags
FOR SELECT
USING (TRUE);


CREATE POLICY "Public can read algorithms"
ON algorithms
FOR SELECT
USING (TRUE);


-- ============================================================
-- 53. PUBLIC RESEARCH / DOCUMENTATION POLICIES
-- ============================================================

CREATE POLICY "Public can read research questions"
ON research_questions
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM datasets d
        WHERE d.id = research_questions.dataset_id
          AND d.status IN ('PUBLISHED', 'UPDATED')
          AND d.visibility = 'PUBLIC'
          AND d.deleted_at IS NULL
    )
);


CREATE POLICY "Public can read citations"
ON dataset_citations
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM datasets d
        WHERE d.id = dataset_citations.dataset_id
          AND d.status IN ('PUBLISHED', 'UPDATED')
          AND d.visibility = 'PUBLIC'
          AND d.deleted_at IS NULL
    )
);


-- ============================================================
-- 54. USER SELF-READ POLICY & USER ROLES
-- ============================================================

CREATE POLICY "Users can read own profile"
ON users
FOR SELECT
USING (
    auth.uid() = id
);

CREATE POLICY "Users can read own roles"
ON user_roles
FOR SELECT
USING (
    auth.uid() = user_id
);


-- ============================================================
-- 55. ADMIN HELPER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN roles r
          ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid()
          AND r.name = 'ADMIN'
    );
$$;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = _user_id
          AND LOWER(r.name) = LOWER(_role)
    );
$$;


-- ============================================================
-- 56. ADMIN DATASET MANAGEMENT
-- ============================================================

CREATE POLICY "Admins can manage datasets"
ON datasets
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());


CREATE POLICY "Admins can manage dataset versions"
ON dataset_versions
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());


CREATE POLICY "Admins can manage dataset files"
ON dataset_files
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());


CREATE POLICY "Admins can manage dataset variables"
ON dataset_variables
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());


CREATE POLICY "Admins can manage quality assessments"
ON dataset_quality_assessments
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());


CREATE POLICY "Admins can manage quality checks"
ON quality_checks
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());


CREATE POLICY "Admins can manage research questions"
ON research_questions
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());


CREATE POLICY "Admins can manage citations"
ON dataset_citations
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "Admins can read all roles"
ON user_roles
FOR SELECT
USING (public.is_admin());


-- ============================================================
-- 56B. SUBMISSIONS & ANALYTICS POLICIES
-- ============================================================

CREATE POLICY "public reads approved submissions" ON dataset_submissions
    FOR SELECT TO anon, authenticated USING (status = 'approved');

CREATE POLICY "owners read own submissions" ON dataset_submissions
    FOR SELECT TO authenticated USING (auth.uid() = submitted_by);

CREATE POLICY "admins read all submissions" ON dataset_submissions
    FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "owners insert own submissions" ON dataset_submissions
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = submitted_by);

CREATE POLICY "owners update own submissions" ON dataset_submissions
    FOR UPDATE TO authenticated
    USING (auth.uid() = submitted_by AND status IN ('draft','rejected','submitted'))
    WITH CHECK (auth.uid() = submitted_by);

CREATE POLICY "admins update all submissions" ON dataset_submissions
    FOR UPDATE TO authenticated
    USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "owners delete own draft submissions" ON dataset_submissions
    FOR DELETE TO authenticated
    USING (auth.uid() = submitted_by AND status IN ('draft','rejected'));

CREATE POLICY "admins delete any submissions" ON dataset_submissions
    FOR DELETE TO authenticated
    USING (public.is_admin());

CREATE POLICY "anyone logs analytics events" ON analytics_events
    FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "admins read analytics events" ON analytics_events
    FOR SELECT TO authenticated USING (public.is_admin());


-- ============================================================
-- 57. DATASET PUBLICATION SAFETY FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_dataset_publication()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.status IN ('PUBLISHED', 'UPDATED') THEN

        IF NEW.synthetic IS NOT TRUE THEN
            RAISE EXCEPTION
                'IYEOB Stage 1 only permits synthetic datasets';
        END IF;

        IF NEW.current_version_id IS NULL THEN
            RAISE EXCEPTION
                'A published dataset must have a current version';
        END IF;

        IF NEW.license_id IS NULL THEN
            RAISE EXCEPTION
                'A published dataset must have a licence';
        END IF;

        IF NEW.published_at IS NULL THEN
            NEW.published_at = NOW();
        END IF;

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_validate_dataset_publication
ON datasets;

CREATE TRIGGER trg_validate_dataset_publication
BEFORE INSERT OR UPDATE ON datasets
FOR EACH ROW
EXECUTE FUNCTION public.validate_dataset_publication();


-- ============================================================
-- 58. DATASET SEARCH VIEW
-- ============================================================

CREATE OR REPLACE VIEW public.published_datasets AS

SELECT
    d.id,
    d.title,
    d.slug,
    d.short_description,
    d.description,
    d.dataset_type,
    d.task_type,

    c.iso2 AS country_code,
    c.name AS country_name,

    r.name AS region_name,

    dom.name AS domain_name,
    dom.slug AS domain_slug,

    d.status,
    d.visibility,
    d.synthetic,
    d.is_featured,

    d.current_version_id,

    dv.version,
    dv.row_count,
    dv.column_count,

    d.published_at,
    d.created_at,
    d.updated_at

FROM datasets d

JOIN countries c
    ON c.id = d.country_id

JOIN domains dom
    ON dom.id = d.domain_id

LEFT JOIN regions r
    ON r.id = d.region_id

LEFT JOIN dataset_versions dv
    ON dv.id = d.current_version_id

WHERE
    d.status IN ('PUBLISHED', 'UPDATED')
    AND d.visibility = 'PUBLIC'
    AND d.deleted_at IS NULL;


-- ============================================================
-- 59. DATASET STATISTICS VIEW
-- ============================================================

CREATE OR REPLACE VIEW public.dataset_statistics AS

SELECT
    d.id AS dataset_id,

    COUNT(DISTINCT dv.id) AS version_count,

    COALESCE(
        SUM(DISTINCT de_count.download_count),
        0
    ) AS total_downloads

FROM datasets d

LEFT JOIN dataset_versions dv
    ON dv.dataset_id = d.id

LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS download_count
    FROM download_events de
    WHERE de.dataset_id = d.id
) de_count
    ON TRUE

GROUP BY d.id;


-- ============================================================
-- 59B. AUDIT LOG, ADMIN INVITES, BOOKMARKS & SAVED SEARCHES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_email text,
  event_type text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  entity_label text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS audit_log_created_idx ON public.audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_event_idx ON public.audit_log (event_type);
CREATE INDEX IF NOT EXISTS audit_log_entity_idx ON public.audit_log (entity_type, entity_id);

GRANT SELECT, INSERT ON public.audit_log TO authenticated;
GRANT ALL ON public.audit_log TO service_role;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admins read audit log" ON public.audit_log
  FOR SELECT TO authenticated USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.write_audit(
  _event text, _entity_type text, _entity_id text, _entity_label text, _details jsonb DEFAULT '{}'::jsonb
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _email text;
BEGIN
  SELECT email INTO _email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.audit_log (actor_id, actor_email, event_type, entity_type, entity_id, entity_label, details)
  VALUES (auth.uid(), _email, _event, _entity_type, _entity_id, _entity_label, COALESCE(_details, '{}'::jsonb));
END;
$$;

CREATE TABLE IF NOT EXISTS public.admin_invites (
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
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY "admins create invites" ON public.admin_invites
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY "admins delete invites" ON public.admin_invites
  FOR DELETE TO authenticated USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.grant_admin(_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _email text; _admin_role_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can change roles';
  END IF;
  SELECT id INTO _admin_role_id FROM public.roles WHERE name = 'ADMIN';
  IF _admin_role_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role_id, role) VALUES (_user_id, _admin_role_id, 'admin')
    ON CONFLICT DO NOTHING;
  END IF;
  SELECT email INTO _email FROM auth.users WHERE id = _user_id;
  PERFORM public.write_audit('role.granted', 'user', _user_id::text, _email, jsonb_build_object('role', 'admin'));
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_admin(_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _email text; _admin_count int; _admin_role_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can change roles';
  END IF;
  SELECT id INTO _admin_role_id FROM public.roles WHERE name = 'ADMIN';
  SELECT count(*) INTO _admin_count FROM public.user_roles WHERE role_id = _admin_role_id OR role = 'admin';
  IF _admin_count <= 1 THEN
    RAISE EXCEPTION 'Cannot revoke the last remaining administrator';
  END IF;
  DELETE FROM public.user_roles WHERE user_id = _user_id AND (role_id = _admin_role_id OR role = 'admin');
  SELECT email INTO _email FROM auth.users WHERE id = _user_id;
  PERFORM public.write_audit('role.revoked', 'user', _user_id::text, _email, jsonb_build_object('role', 'admin'));
END;
$$;

CREATE OR REPLACE FUNCTION public.list_workspace_members()
RETURNS TABLE (user_id uuid, email text, full_name text, roles text[], created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u.id, u.email, u.display_name,
         COALESCE(ARRAY(
           SELECT r.name
           FROM public.user_roles ur
           JOIN public.roles r ON r.id = ur.role_id
           WHERE ur.user_id = u.id
           ORDER BY r.name
         ), '{}'),
         u.created_at
  FROM public.users u
  WHERE public.is_admin()
  ORDER BY u.created_at;
$$;

CREATE TABLE IF NOT EXISTS public.bookmarks (
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

CREATE TABLE IF NOT EXISTS public.saved_searches (
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


-- ============================================================
-- 60. CMS EXTENSION ENUMS
-- ============================================================

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'cms_content_status'
    ) THEN
        CREATE TYPE cms_content_status AS ENUM (
            'DRAFT',
            'EDITORIAL_REVIEW',
            'QUALITY_CHECK',
            'FACT_CHECK',
            'APPROVED',
            'SCHEDULED',
            'PUBLISHED',
            'UPDATED',
            'ARCHIVED',
            'REJECTED'
        );
    END IF;


    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'workflow_action_type'
    ) THEN
        CREATE TYPE workflow_action_type AS ENUM (
            'CREATE',
            'EDIT',
            'SUBMIT',
            'ASSIGN',
            'REVIEW',
            'REQUEST_CHANGES',
            'QUALITY_CHECK',
            'FACT_CHECK',
            'APPROVE',
            'REJECT',
            'SCHEDULE',
            'PUBLISH',
            'UNPUBLISH',
            'ARCHIVE',
            'RESTORE',
            'UPLOAD',
            'VALIDATE'
        );
    END IF;


    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'cms_block_type'
    ) THEN
        CREATE TYPE cms_block_type AS ENUM (
            'TEXT',
            'IMAGE',
            'VIDEO',
            'STATISTIC',
            'CALLOUT',
            'QUOTE',
            'TABLE',
            'CODE',
            'CHART',
            'DATA_DICTIONARY',
            'RESEARCH_QUESTION',
            'KEY_FACT',
            'WARNING',
            'DOWNLOAD',
            'CTA',
            'FAQ'
        );
    END IF;


    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'media_type'
    ) THEN
        CREATE TYPE media_type AS ENUM (
            'IMAGE',
            'VIDEO',
            'AUDIO',
            'DOCUMENT',
            'DIAGRAM',
            'CHART',
            'OTHER'
        );
    END IF;


    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'ingestion_status'
    ) THEN
        CREATE TYPE ingestion_status AS ENUM (
            'UPLOADED',
            'QUEUED',
            'VALIDATING',
            'PROCESSING',
            'QUALITY_CHECK',
            'READY_FOR_REVIEW',
            'APPROVED',
            'REJECTED',
            'FAILED'
        );
    END IF;


    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'product_type'
    ) THEN
        CREATE TYPE product_type AS ENUM (
            'DATASET',
            'API',
            'MODEL',
            'EVALUATION',
            'CONTROL'
        );
    END IF;

END $$;


-- ============================================================
-- 61. CMS DATASET CONTENT
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    version INTEGER NOT NULL DEFAULT 1,

    headline TEXT NOT NULL,

    short_description TEXT,

    introduction TEXT,

    overview TEXT,

    narration TEXT,

    problem_statement TEXT,

    purpose TEXT,

    background TEXT,

    use_cases TEXT,

    business_context TEXT,

    research_context TEXT,

    methodology_summary TEXT,

    interpretation TEXT,

    limitations TEXT,

    assumptions TEXT,

    ethical_considerations TEXT,

    privacy_considerations TEXT,

    bias_considerations TEXT,

    intended_use TEXT,

    prohibited_use TEXT,

    target_audience TEXT,

    getting_started TEXT,

    citation_instructions TEXT,

    seo_title TEXT,

    seo_description TEXT,

    seo_keywords TEXT[],

    canonical_url TEXT,

    open_graph_title TEXT,

    open_graph_description TEXT,

    open_graph_image_url TEXT,

    content_status cms_content_status NOT NULL DEFAULT 'DRAFT',

    created_by UUID REFERENCES users(id),

    updated_by UUID REFERENCES users(id),

    published_by UUID REFERENCES users(id),

    published_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_dataset_content_version
        UNIQUE(dataset_id, version),

    CONSTRAINT dataset_content_publish_check
        CHECK (
            (
                content_status <> 'PUBLISHED'
            )
            OR
            (
                published_at IS NOT NULL
                AND (published_by IS NOT NULL OR created_by IS NOT NULL)
            )
        )
);


-- ============================================================
-- 62. CMS DATASET CONTENT SECTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_content_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_content_id UUID NOT NULL
        REFERENCES dataset_content(id)
        ON DELETE CASCADE,

    section_key TEXT NOT NULL,

    title TEXT NOT NULL,

    content TEXT,

    display_order INTEGER NOT NULL DEFAULT 0,

    is_visible BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_dataset_content_section
        UNIQUE(dataset_content_id, section_key)
);


-- ============================================================
-- 63. CMS CONTENT BLOCKS
-- ============================================================

CREATE TABLE IF NOT EXISTS content_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_content_id UUID NOT NULL
        REFERENCES dataset_content(id)
        ON DELETE CASCADE,

    block_type cms_block_type NOT NULL,

    title TEXT,

    content TEXT,

    structured_data JSONB NOT NULL DEFAULT '{}'::JSONB,

    display_order INTEGER NOT NULL DEFAULT 0,

    is_visible BOOLEAN NOT NULL DEFAULT TRUE,

    created_by UUID REFERENCES users(id),

    updated_by UUID REFERENCES users(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 64. CMS DATASET MEDIA
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    dataset_content_id UUID
        REFERENCES dataset_content(id)
        ON DELETE SET NULL,

    media_type media_type NOT NULL,

    title TEXT NOT NULL,

    alt_text TEXT,

    caption TEXT,

    description TEXT,

    storage_bucket TEXT NOT NULL,

    storage_key TEXT NOT NULL,

    mime_type TEXT,

    file_size_bytes BIGINT,

    width INTEGER,

    height INTEGER,

    checksum_sha256 TEXT,

    display_order INTEGER NOT NULL DEFAULT 0,

    created_by UUID REFERENCES users(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_dataset_media_storage
        UNIQUE(storage_bucket, storage_key)
);


-- ============================================================
-- 65. CMS CONTENT WORKFLOW
-- ============================================================

CREATE TABLE IF NOT EXISTS content_workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    content_id UUID NOT NULL
        REFERENCES dataset_content(id)
        ON DELETE CASCADE,

    current_status cms_content_status NOT NULL DEFAULT 'DRAFT',

    assigned_to UUID REFERENCES users(id),

    created_by UUID REFERENCES users(id),

    submitted_at TIMESTAMPTZ,

    approved_at TIMESTAMPTZ,

    published_at TIMESTAMPTZ,

    rejected_at TIMESTAMPTZ,

    rejection_reason TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 66. CMS WORKFLOW ACTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS workflow_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    workflow_id UUID NOT NULL
        REFERENCES content_workflows(id)
        ON DELETE CASCADE,

    actor_id UUID REFERENCES users(id),

    action workflow_action_type NOT NULL,

    from_status cms_content_status,

    to_status cms_content_status,

    comment TEXT,

    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 67. CMS CONTENT REVISIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_content_revisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_content_id UUID NOT NULL
        REFERENCES dataset_content(id)
        ON DELETE CASCADE,

    revision_number INTEGER NOT NULL,

    title TEXT,

    content_snapshot JSONB NOT NULL,

    change_summary TEXT,

    created_by UUID REFERENCES users(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_dataset_content_revision
        UNIQUE(dataset_content_id, revision_number)
);


-- ============================================================
-- 68. CMS DATASET INGESTION JOBS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_ingestion_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_id UUID NOT NULL
        REFERENCES datasets(id)
        ON DELETE CASCADE,

    dataset_version_id UUID
        REFERENCES dataset_versions(id)
        ON DELETE SET NULL,

    uploaded_by UUID REFERENCES users(id),

    original_filename TEXT NOT NULL,

    storage_bucket TEXT,

    storage_key TEXT,

    file_size_bytes BIGINT,

    checksum_sha256 TEXT,

    file_type TEXT,

    status ingestion_status NOT NULL DEFAULT 'UPLOADED',

    validation_results JSONB NOT NULL DEFAULT '{}'::JSONB,

    processing_results JSONB NOT NULL DEFAULT '{}'::JSONB,

    error_message TEXT,

    started_at TIMESTAMPTZ,

    completed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 69. CMS DATASET SCHEMAS
-- ============================================================

CREATE TABLE IF NOT EXISTS dataset_schemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dataset_version_id UUID NOT NULL
        REFERENCES dataset_versions(id)
        ON DELETE CASCADE,

    schema_version INTEGER NOT NULL DEFAULT 1,

    schema_definition JSONB NOT NULL,

    schema_hash TEXT NOT NULL,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_dataset_schema_version
        UNIQUE(dataset_version_id, schema_version)
);


-- ============================================================
-- 70. CMS SHARED PRODUCT CONTENT
-- ============================================================

CREATE TABLE IF NOT EXISTS product_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_type product_type NOT NULL,

    product_id UUID NOT NULL,

    title TEXT NOT NULL,

    subtitle TEXT,

    short_description TEXT,

    description TEXT,

    narration TEXT,

    purpose TEXT,

    background TEXT,

    methodology TEXT,

    use_cases TEXT,

    limitations TEXT,

    assumptions TEXT,

    ethical_considerations TEXT,

    intended_use TEXT,

    prohibited_use TEXT,

    documentation JSONB NOT NULL DEFAULT '{}'::JSONB,

    seo JSONB NOT NULL DEFAULT '{}'::JSONB,

    status cms_content_status NOT NULL DEFAULT 'DRAFT',

    version INTEGER NOT NULL DEFAULT 1,

    created_by UUID REFERENCES users(id),

    updated_by UUID REFERENCES users(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_product_content_version
        UNIQUE(product_type, product_id, version)
);


-- ============================================================
-- 71. CMS PRODUCT RELATIONSHIPS
-- ============================================================

CREATE TABLE IF NOT EXISTS product_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    source_type product_type NOT NULL,

    source_id UUID NOT NULL,

    target_type product_type NOT NULL,

    target_id UUID NOT NULL,

    relationship_type TEXT NOT NULL,

    description TEXT,

    created_by UUID REFERENCES users(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_product_relationship
        UNIQUE(
            source_type,
            source_id,
            target_type,
            target_id,
            relationship_type
        ),

    CONSTRAINT product_relationship_self_check
        CHECK (
            NOT (
                source_type = target_type
                AND source_id = target_id
            )
        )
);


-- ============================================================
-- 72. CMS API DOCUMENTATION
-- ============================================================

CREATE TABLE IF NOT EXISTS api_documentation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    api_version_id UUID NOT NULL
        REFERENCES api_versions(id)
        ON DELETE CASCADE,

    overview TEXT,

    authentication TEXT,

    request_description TEXT,

    response_description TEXT,

    examples JSONB NOT NULL DEFAULT '{}'::JSONB,

    error_codes JSONB NOT NULL DEFAULT '{}'::JSONB,

    rate_limits JSONB NOT NULL DEFAULT '{}'::JSONB,

    changelog TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_api_documentation
        UNIQUE(api_version_id)
);


-- ============================================================
-- 73. CMS MODEL CARDS
-- ============================================================

CREATE TABLE IF NOT EXISTS model_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    model_version_id UUID NOT NULL
        REFERENCES model_versions(id)
        ON DELETE CASCADE,

    model_summary TEXT,

    intended_use TEXT,

    limitations TEXT,

    training_data_description TEXT,

    evaluation_description TEXT,

    ethical_considerations TEXT,

    bias_considerations TEXT,

    performance_summary JSONB NOT NULL DEFAULT '{}'::JSONB,

    explainability TEXT,

    deployment_information TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_model_card
        UNIQUE(model_version_id)
);


-- ============================================================
-- 74. CMS SECTION DEFINITIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS cms_section_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    section_key TEXT UNIQUE NOT NULL,

    title TEXT NOT NULL,

    description TEXT,

    display_order INTEGER NOT NULL DEFAULT 0,

    required_for_publication BOOLEAN NOT NULL DEFAULT FALSE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 75. CMS INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dataset_content_dataset
    ON dataset_content(dataset_id);

CREATE INDEX IF NOT EXISTS idx_dataset_content_status
    ON dataset_content(content_status);

CREATE INDEX IF NOT EXISTS idx_dataset_content_updated
    ON dataset_content(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_dataset_content_headline
    ON dataset_content
    USING gin(to_tsvector('english', headline));

CREATE INDEX IF NOT EXISTS idx_dataset_content_description
    ON dataset_content
    USING gin(to_tsvector('english', COALESCE(short_description, '')));

CREATE INDEX IF NOT EXISTS idx_content_sections_content
    ON dataset_content_sections(dataset_content_id);

CREATE INDEX IF NOT EXISTS idx_content_blocks_content
    ON content_blocks(dataset_content_id);

CREATE INDEX IF NOT EXISTS idx_content_blocks_type
    ON content_blocks(block_type);

CREATE INDEX IF NOT EXISTS idx_dataset_media_dataset
    ON dataset_media(dataset_id);

CREATE INDEX IF NOT EXISTS idx_dataset_media_content
    ON dataset_media(dataset_content_id);

CREATE INDEX IF NOT EXISTS idx_content_workflows_dataset
    ON content_workflows(dataset_id);

CREATE INDEX IF NOT EXISTS idx_content_workflows_status
    ON content_workflows(current_status);

CREATE INDEX IF NOT EXISTS idx_content_workflows_assigned
    ON content_workflows(assigned_to);

CREATE INDEX IF NOT EXISTS idx_workflow_actions_workflow
    ON workflow_actions(workflow_id);

CREATE INDEX IF NOT EXISTS idx_workflow_actions_actor
    ON workflow_actions(actor_id);

CREATE INDEX IF NOT EXISTS idx_content_revisions_content
    ON dataset_content_revisions(dataset_content_id);

CREATE INDEX IF NOT EXISTS idx_ingestion_dataset
    ON dataset_ingestion_jobs(dataset_id);

CREATE INDEX IF NOT EXISTS idx_ingestion_status
    ON dataset_ingestion_jobs(status);

CREATE INDEX IF NOT EXISTS idx_product_content_product
    ON product_content(product_type, product_id);

CREATE INDEX IF NOT EXISTS idx_product_content_status
    ON product_content(status);

CREATE INDEX IF NOT EXISTS idx_product_relationship_source
    ON product_relationships(source_type, source_id);

CREATE INDEX IF NOT EXISTS idx_product_relationship_target
    ON product_relationships(target_type, target_id);


-- ============================================================
-- 76. CMS UPDATED_AT TRIGGER FUNCTION & TRIGGERS
-- ============================================================

CREATE OR REPLACE FUNCTION update_cms_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dataset_content_updated ON dataset_content;
CREATE TRIGGER trg_dataset_content_updated
BEFORE UPDATE ON dataset_content
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();

DROP TRIGGER IF EXISTS trg_dataset_content_sections_updated ON dataset_content_sections;
CREATE TRIGGER trg_dataset_content_sections_updated
BEFORE UPDATE ON dataset_content_sections
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();

DROP TRIGGER IF EXISTS trg_content_blocks_updated ON content_blocks;
CREATE TRIGGER trg_content_blocks_updated
BEFORE UPDATE ON content_blocks
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();

DROP TRIGGER IF EXISTS trg_content_workflows_updated ON content_workflows;
CREATE TRIGGER trg_content_workflows_updated
BEFORE UPDATE ON content_workflows
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();

DROP TRIGGER IF EXISTS trg_product_content_updated ON product_content;
CREATE TRIGGER trg_product_content_updated
BEFORE UPDATE ON product_content
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();

DROP TRIGGER IF EXISTS trg_api_documentation_updated ON api_documentation;
CREATE TRIGGER trg_api_documentation_updated
BEFORE UPDATE ON api_documentation
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();

DROP TRIGGER IF EXISTS trg_model_cards_updated ON model_cards;
CREATE TRIGGER trg_model_cards_updated
BEFORE UPDATE ON model_cards
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();


-- ============================================================
-- 77. AUTOMATIC CONTENT REVISION
-- ============================================================

CREATE OR REPLACE FUNCTION create_dataset_content_revision()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    next_revision INTEGER;
BEGIN

    SELECT COALESCE(MAX(revision_number), 0) + 1
    INTO next_revision
    FROM dataset_content_revisions
    WHERE dataset_content_id = OLD.id;

    INSERT INTO dataset_content_revisions (
        dataset_content_id,
        revision_number,
        title,
        content_snapshot,
        change_summary,
        created_by
    )
    VALUES (
        OLD.id,
        next_revision,
        OLD.headline,
        jsonb_build_object(
            'headline', OLD.headline,
            'short_description', OLD.short_description,
            'introduction', OLD.introduction,
            'overview', OLD.overview,
            'narration', OLD.narration,
            'problem_statement', OLD.problem_statement,
            'purpose', OLD.purpose,
            'background', OLD.background,
            'use_cases', OLD.use_cases,
            'business_context', OLD.business_context,
            'research_context', OLD.research_context,
            'methodology_summary', OLD.methodology_summary,
            'interpretation', OLD.interpretation,
            'limitations', OLD.limitations,
            'assumptions', OLD.assumptions,
            'ethical_considerations', OLD.ethical_considerations,
            'privacy_considerations', OLD.privacy_considerations,
            'bias_considerations', OLD.bias_considerations,
            'intended_use', OLD.intended_use,
            'prohibited_use', OLD.prohibited_use,
            'target_audience', OLD.target_audience,
            'getting_started', OLD.getting_started,
            'citation_instructions', OLD.citation_instructions,
            'seo_title', OLD.seo_title,
            'seo_description', OLD.seo_description,
            'seo_keywords', OLD.seo_keywords,
            'canonical_url', OLD.canonical_url,
            'open_graph_title', OLD.open_graph_title,
            'open_graph_description', OLD.open_graph_description,
            'open_graph_image_url', OLD.open_graph_image_url,
            'content_status', OLD.content_status
        ),
        'Automatic revision before update',
        OLD.updated_by
    );

    RETURN NEW;

END;
$$;

DROP TRIGGER IF EXISTS trg_dataset_content_revision ON dataset_content;
CREATE TRIGGER trg_dataset_content_revision
BEFORE UPDATE ON dataset_content
FOR EACH ROW
WHEN (
    OLD.* IS DISTINCT FROM NEW.*
)
EXECUTE FUNCTION create_dataset_content_revision();


-- ============================================================
-- 78. CMS WORKFLOW ACTION LOGGING FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION record_workflow_action(
    p_workflow_id UUID,
    p_actor_id UUID,
    p_action workflow_action_type,
    p_from_status cms_content_status,
    p_to_status cms_content_status,
    p_comment TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_id UUID;
BEGIN

    INSERT INTO workflow_actions (
        workflow_id,
        actor_id,
        action,
        from_status,
        to_status,
        comment,
        metadata
    )
    VALUES (
        p_workflow_id,
        p_actor_id,
        p_action,
        p_from_status,
        p_to_status,
        p_comment,
        p_metadata
    )
    RETURNING id INTO new_id;

    RETURN new_id;

END;
$$;


-- ============================================================
-- 79. CONTENT WORKFLOW VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION validate_dataset_content_publication()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_synthetic BOOLEAN;
BEGIN

    IF NEW.content_status = 'PUBLISHED' THEN

        SELECT synthetic
        INTO v_synthetic
        FROM datasets
        WHERE id = NEW.dataset_id;

        IF v_synthetic IS DISTINCT FROM TRUE THEN
            RAISE EXCEPTION
                'IYEOB Stage 1 only permits synthetic datasets.';
        END IF;

        IF NEW.headline IS NULL OR length(trim(NEW.headline)) = 0 THEN
            RAISE EXCEPTION
                'Dataset headline is required before publication.';
        END IF;

        IF NEW.short_description IS NULL
           OR length(trim(NEW.short_description)) = 0 THEN
            RAISE EXCEPTION
                'Dataset short description is required before publication.';
        END IF;

        IF NEW.introduction IS NULL
           OR length(trim(NEW.introduction)) = 0 THEN
            RAISE EXCEPTION
                'Dataset introduction is required before publication.';
        END IF;

        IF NEW.methodology_summary IS NULL
           OR length(trim(NEW.methodology_summary)) = 0 THEN
            RAISE EXCEPTION
                'Dataset methodology is required before publication.';
        END IF;

        IF NEW.limitations IS NULL
           OR length(trim(NEW.limitations)) = 0 THEN
            RAISE EXCEPTION
                'Dataset limitations are required before publication.';
        END IF;

        IF NEW.intended_use IS NULL
           OR length(trim(NEW.intended_use)) = 0 THEN
            RAISE EXCEPTION
                'Dataset intended use is required before publication.';
        END IF;

        IF NEW.published_at IS NULL THEN
            NEW.published_at = NOW();
        END IF;

        IF NEW.published_by IS NULL THEN
            NEW.published_by = COALESCE(NEW.updated_by, NEW.created_by, auth.uid());
        END IF;

    END IF;

    RETURN NEW;

END;
$$;

DROP TRIGGER IF EXISTS trg_validate_dataset_content_publication ON dataset_content;
CREATE TRIGGER trg_validate_dataset_content_publication
BEFORE INSERT OR UPDATE ON dataset_content
FOR EACH ROW
EXECUTE FUNCTION validate_dataset_content_publication();


-- ============================================================
-- 80. CMS RLS SETUP
-- ============================================================

ALTER TABLE dataset_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_content_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_content_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_ingestion_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dataset_schemas ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_documentation ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE cms_section_definitions ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- 81. CMS HELPER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION is_cms_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        LEFT JOIN roles r
            ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid()
        AND (
            r.name IN (
                'ADMIN',
                'DATA_EDITOR',
                'REVIEWER',
                'PUBLISHER'
            )
            OR upper(COALESCE(ur.role, '')) IN (
                'ADMIN',
                'DATA_EDITOR',
                'REVIEWER',
                'PUBLISHER'
            )
        )
    );
$$;

CREATE OR REPLACE FUNCTION is_cms_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        LEFT JOIN roles r
            ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid()
        AND (
            r.name = 'ADMIN'
            OR upper(COALESCE(ur.role, '')) = 'ADMIN'
        )
    );
$$;


-- ============================================================
-- 82. CMS POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_published_dataset_content ON dataset_content;
CREATE POLICY cms_read_published_dataset_content
ON dataset_content FOR SELECT
USING (content_status = 'PUBLISHED' OR is_cms_user());

DROP POLICY IF EXISTS cms_manage_dataset_content ON dataset_content;
CREATE POLICY cms_manage_dataset_content
ON dataset_content FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_content_sections ON dataset_content_sections;
CREATE POLICY cms_read_content_sections
ON dataset_content_sections FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM dataset_content dc
        WHERE dc.id = dataset_content_sections.dataset_content_id
        AND (dc.content_status = 'PUBLISHED' OR is_cms_user())
    )
);

DROP POLICY IF EXISTS cms_manage_content_sections ON dataset_content_sections;
CREATE POLICY cms_manage_content_sections
ON dataset_content_sections FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_content_blocks ON content_blocks;
CREATE POLICY cms_read_content_blocks
ON content_blocks FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM dataset_content dc
        WHERE dc.id = content_blocks.dataset_content_id
        AND (dc.content_status = 'PUBLISHED' OR is_cms_user())
    )
);

DROP POLICY IF EXISTS cms_manage_content_blocks ON content_blocks;
CREATE POLICY cms_manage_content_blocks
ON content_blocks FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_dataset_media ON dataset_media;
CREATE POLICY cms_read_dataset_media
ON dataset_media FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM dataset_content dc
        WHERE dc.id = dataset_media.dataset_content_id
        AND (dc.content_status = 'PUBLISHED' OR is_cms_user())
    )
    OR is_cms_user()
);

DROP POLICY IF EXISTS cms_manage_dataset_media ON dataset_media;
CREATE POLICY cms_manage_dataset_media
ON dataset_media FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_manage_workflows ON content_workflows;
CREATE POLICY cms_manage_workflows
ON content_workflows FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_workflow_actions ON workflow_actions;
CREATE POLICY cms_read_workflow_actions
ON workflow_actions FOR SELECT
USING (is_cms_user());

DROP POLICY IF EXISTS cms_insert_workflow_actions ON workflow_actions;
CREATE POLICY cms_insert_workflow_actions
ON workflow_actions FOR INSERT
WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_revisions ON dataset_content_revisions;
CREATE POLICY cms_read_revisions
ON dataset_content_revisions FOR SELECT
USING (is_cms_user());

DROP POLICY IF EXISTS cms_insert_revisions ON dataset_content_revisions;
CREATE POLICY cms_insert_revisions
ON dataset_content_revisions FOR INSERT
WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_manage_ingestion ON dataset_ingestion_jobs;
CREATE POLICY cms_manage_ingestion
ON dataset_ingestion_jobs FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_dataset_schemas ON dataset_schemas;
CREATE POLICY cms_read_dataset_schemas
ON dataset_schemas FOR SELECT
USING (
    is_cms_user()
    OR EXISTS (
        SELECT 1 FROM dataset_versions dv
        JOIN datasets d ON d.id = dv.dataset_id
        JOIN dataset_content dc ON dc.dataset_id = d.id
        WHERE dv.id = dataset_schemas.dataset_version_id
        AND dc.content_status = 'PUBLISHED'
    )
);

DROP POLICY IF EXISTS cms_manage_dataset_schemas ON dataset_schemas;
CREATE POLICY cms_manage_dataset_schemas
ON dataset_schemas FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_product_content ON product_content;
CREATE POLICY cms_read_product_content
ON product_content FOR SELECT
USING (status = 'PUBLISHED' OR is_cms_user());

DROP POLICY IF EXISTS cms_manage_product_content ON product_content;
CREATE POLICY cms_manage_product_content
ON product_content FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_product_relationships ON product_relationships;
CREATE POLICY cms_read_product_relationships
ON product_relationships FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS cms_manage_product_relationships ON product_relationships;
CREATE POLICY cms_manage_product_relationships
ON product_relationships FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_api_documentation ON api_documentation;
CREATE POLICY cms_read_api_documentation
ON api_documentation FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS cms_manage_api_documentation ON api_documentation;
CREATE POLICY cms_manage_api_documentation
ON api_documentation FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_model_cards ON model_cards;
CREATE POLICY cms_read_model_cards
ON model_cards FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS cms_manage_model_cards ON model_cards;
CREATE POLICY cms_manage_model_cards
ON model_cards FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());

DROP POLICY IF EXISTS cms_read_section_definitions ON cms_section_definitions;
CREATE POLICY cms_read_section_definitions
ON cms_section_definitions FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS cms_manage_section_definitions ON cms_section_definitions;
CREATE POLICY cms_manage_section_definitions
ON cms_section_definitions FOR ALL
USING (is_cms_user()) WITH CHECK (is_cms_user());


-- ============================================================
-- 83. SEED CMS ROLES
-- ============================================================

INSERT INTO roles (name, description)
SELECT 'DATA_EDITOR', 'Can create and edit datasets and CMS content.'
WHERE NOT EXISTS (
    SELECT 1 FROM roles WHERE name = 'DATA_EDITOR'
);

INSERT INTO roles (name, description)
SELECT 'REVIEWER', 'Can review datasets, content and quality checks.'
WHERE NOT EXISTS (
    SELECT 1 FROM roles WHERE name = 'REVIEWER'
);

INSERT INTO roles (name, description)
SELECT 'PUBLISHER', 'Can approve and publish datasets and CMS content.'
WHERE NOT EXISTS (
    SELECT 1 FROM roles WHERE name = 'PUBLISHER'
);


-- ============================================================
-- 84. SEED CMS SECTION DEFINITIONS
-- ============================================================

INSERT INTO cms_section_definitions
    (section_key, title, description, display_order, required_for_publication)
VALUES
    ('INTRODUCTION', 'Introduction', 'High-level introduction to the dataset.', 10, TRUE),
    ('BACKGROUND', 'Background', 'Context and motivation for creating the dataset.', 20, FALSE),
    ('WHY_THIS_DATASET', 'Why This Dataset', 'Problem the dataset is designed to address.', 30, FALSE),
    ('WHAT_IS_INCLUDED', 'What Is Included', 'Description of dataset contents.', 40, FALSE),
    ('METHODOLOGY', 'Methodology', 'Synthetic data generation methodology.', 50, TRUE),
    ('DATA_GENERATION', 'Data Generation', 'How synthetic records were generated.', 60, TRUE),
    ('VARIABLES', 'Variables', 'Dataset variables and data dictionary.', 70, TRUE),
    ('QUALITY', 'Quality', 'Data quality and validation information.', 80, TRUE),
    ('RESEARCH_QUESTIONS', 'Research Questions', 'Potential research and analytical questions.', 90, FALSE),
    ('USE_CASES', 'Use Cases', 'Potential practical applications.', 100, FALSE),
    ('LIMITATIONS', 'Limitations', 'Known limitations and caveats.', 110, TRUE),
    ('ETHICAL_CONSIDERATIONS', 'Ethical Considerations', 'Ethical, privacy and bias considerations.', 120, FALSE),
    ('HOW_TO_USE', 'How to Use', 'Instructions for using the dataset.', 130, FALSE),
    ('CITATION', 'Citation', 'Recommended dataset citation.', 140, TRUE),
    ('FAQ', 'Frequently Asked Questions', 'Common questions about the dataset.', 150, FALSE)
ON CONFLICT (section_key) DO NOTHING;


-- ============================================================
-- 85. CMS VIEWS
-- ============================================================

CREATE OR REPLACE VIEW cms_dataset_catalogue AS
SELECT
    d.id AS dataset_id,
    d.slug,
    d.title AS name,
    d.title,
    d.status AS dataset_status,
    d.synthetic,

    dc.id AS content_id,
    dc.version AS content_version,
    dc.headline,
    dc.short_description,
    dc.narration,
    dc.target_audience,
    dc.intended_use,
    dc.content_status,

    dc.seo_title,
    dc.seo_description,
    dc.canonical_url,

    dc.created_at AS content_created_at,
    dc.updated_at AS content_updated_at,
    dc.published_at

FROM datasets d

LEFT JOIN dataset_content dc
    ON dc.dataset_id = d.id

WHERE
    dc.content_status = 'PUBLISHED'
    OR dc.content_status IS NULL;


CREATE OR REPLACE VIEW cms_dataset_dashboard AS
SELECT
    d.id AS dataset_id,
    d.slug,
    d.title AS name,
    d.title,
    d.synthetic,
    d.status AS dataset_status,

    dc.id AS content_id,
    dc.content_status,

    cw.current_status AS workflow_status,
    cw.assigned_to,

    (
        SELECT COUNT(*)
        FROM dataset_content_revisions dcr
        WHERE dcr.dataset_content_id = dc.id
    ) AS revision_count,

    (
        SELECT COUNT(*)
        FROM dataset_media dm
        WHERE dm.dataset_id = d.id
    ) AS media_count,

    (
        SELECT COUNT(*)
        FROM dataset_ingestion_jobs dij
        WHERE dij.dataset_id = d.id
    ) AS ingestion_job_count,

    dc.created_at,
    dc.updated_at,
    dc.published_at

FROM datasets d

LEFT JOIN dataset_content dc
    ON dc.dataset_id = d.id

LEFT JOIN LATERAL (
    SELECT *
    FROM content_workflows cw2
    WHERE cw2.content_id = dc.id
    ORDER BY cw2.created_at DESC
    LIMIT 1
) cw
ON TRUE;


-- ============================================================
-- 86. CMS GRANTS
-- ============================================================

GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT INSERT, UPDATE, DELETE ON
    dataset_content,
    dataset_content_sections,
    content_blocks,
    dataset_media,
    content_workflows,
    workflow_actions,
    dataset_content_revisions,
    dataset_ingestion_jobs,
    dataset_schemas,
    product_content,
    product_relationships,
    api_documentation,
    model_cards,
    cms_section_definitions
TO authenticated;

GRANT SELECT ON cms_dataset_catalogue TO anon, authenticated;
GRANT SELECT ON cms_dataset_dashboard TO authenticated;


-- ============================================================
-- 87. CMS COMMENTS / DOCUMENTATION
-- ============================================================

COMMENT ON TABLE dataset_content IS
'Canonical CMS editorial content for IYEOB datasets.';

COMMENT ON TABLE dataset_content_sections IS
'Structured editorial sections displayed on dataset pages.';

COMMENT ON TABLE content_blocks IS
'Reusable structured CMS content blocks for dataset pages.';

COMMENT ON TABLE dataset_media IS
'Metadata for media stored in Supabase Storage.';

COMMENT ON TABLE content_workflows IS
'Editorial and publication workflow for datasets.';

COMMENT ON TABLE workflow_actions IS
'Audit trail of CMS workflow actions.';

COMMENT ON TABLE dataset_content_revisions IS
'Historical snapshots of dataset CMS content.';

COMMENT ON TABLE dataset_ingestion_jobs IS
'Tracks dataset uploads, validation and ingestion processing.';

COMMENT ON TABLE dataset_schemas IS
'Immutable schema snapshots for dataset versions.';

COMMENT ON TABLE product_content IS
'Shared editorial content layer for datasets, APIs, models and AI control products.';

COMMENT ON TABLE product_relationships IS
'Relationship graph linking datasets, APIs, models, evaluations and controls.';

COMMENT ON TABLE api_documentation IS
'Documentation associated with API versions.';

COMMENT ON TABLE model_cards IS
'Responsible AI documentation associated with model versions.';


-- ============================================================
-- 88. FINAL SYSTEM SETTINGS VERSION & COMMIT
-- ============================================================

INSERT INTO system_settings (key, value, description)
VALUES ('cms_schema_version', to_jsonb('1.0.0'::text), 'IYEOB CMS database extension version.')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

COMMIT;


