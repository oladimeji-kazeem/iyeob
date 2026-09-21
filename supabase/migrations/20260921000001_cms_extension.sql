-- ============================================================
-- IYEOB CMS EXTENSION
-- Incremental migration for existing IYEOB Supabase database
-- ============================================================
-- Purpose:
--   Extend the existing IYEOB database with a production-ready
--   Content Management System for privileged dataset management.
--
-- Stage 1:
--   Synthetic datasets only.
--
-- Architecture:
--   CMS Content -> Dataset -> Dataset Version -> Files
--             -> APIs (future) -> Models (future)
--
-- IMPORTANT:
--   This script assumes the core IYEOB schema already exists.
--   It does NOT recreate the existing core tables.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- ============================================================
-- 2. ENUMS
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
-- 3. DATASET CONTENT
-- ============================================================
-- Canonical editorial record for a dataset.
--
-- The website, API catalogue and future model documentation
-- should reference this canonical content rather than creating
-- separate copies of the same description.
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
-- 4. DATASET CONTENT SECTIONS
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
-- 5. CONTENT BLOCKS
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
-- 6. DATASET MEDIA
-- ============================================================
-- Metadata only.
--
-- Actual files belong in Supabase Storage.
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
-- 7. CONTENT WORKFLOW
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
-- 8. WORKFLOW ACTIONS
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
-- 9. CONTENT REVISIONS
-- ============================================================
-- Every meaningful editorial change can be reconstructed.
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
-- 10. DATASET INGESTION JOBS
-- ============================================================
-- Tracks dataset upload and validation.
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
-- 11. DATASET SCHEMAS
-- ============================================================
-- Immutable snapshots of the dataset structure.
-- Useful for future API and ML model compatibility.
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
-- 12. SHARED PRODUCT CONTENT
-- ============================================================
-- Generic editorial layer for future:
--
-- Dataset
-- API
-- Model
-- Evaluation
-- AI Control
--
-- Technical metadata remains in specialised tables.
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
-- 13. PRODUCT RELATIONSHIPS
-- ============================================================
-- Flexible relationship graph between IYEOB products.
--
-- Examples:
-- Dataset -> USED_BY -> API
-- Dataset -> TRAINED -> Model
-- Dataset -> BENCHMARKS -> Model
-- Model -> EVALUATED_ON -> Dataset
-- API -> SERVES -> Model
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
-- 14. API DOCUMENTATION
-- ============================================================
-- Future API catalogue.
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
-- 15. MODEL CARDS
-- ============================================================
-- Future model documentation.
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
-- 16. INDEXES
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
-- 17. UPDATED_AT TRIGGER FUNCTION
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


-- ============================================================
-- 18. UPDATED_AT TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS trg_dataset_content_updated
ON dataset_content;

CREATE TRIGGER trg_dataset_content_updated
BEFORE UPDATE ON dataset_content
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();


DROP TRIGGER IF EXISTS trg_dataset_content_sections_updated
ON dataset_content_sections;

CREATE TRIGGER trg_dataset_content_sections_updated
BEFORE UPDATE ON dataset_content_sections
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();


DROP TRIGGER IF EXISTS trg_content_blocks_updated
ON content_blocks;

CREATE TRIGGER trg_content_blocks_updated
BEFORE UPDATE ON content_blocks
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();


DROP TRIGGER IF EXISTS trg_content_workflows_updated
ON content_workflows;

CREATE TRIGGER trg_content_workflows_updated
BEFORE UPDATE ON content_workflows
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();


DROP TRIGGER IF EXISTS trg_product_content_updated
ON product_content;

CREATE TRIGGER trg_product_content_updated
BEFORE UPDATE ON product_content
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();


DROP TRIGGER IF EXISTS trg_api_documentation_updated
ON api_documentation;

CREATE TRIGGER trg_api_documentation_updated
BEFORE UPDATE ON api_documentation
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();


DROP TRIGGER IF EXISTS trg_model_cards_updated
ON model_cards;

CREATE TRIGGER trg_model_cards_updated
BEFORE UPDATE ON model_cards
FOR EACH ROW
EXECUTE FUNCTION update_cms_updated_at();


-- ============================================================
-- 19. AUTOMATIC CONTENT REVISION
-- ============================================================
-- Creates a revision before an existing content record is changed.
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


DROP TRIGGER IF EXISTS trg_dataset_content_revision
ON dataset_content;

CREATE TRIGGER trg_dataset_content_revision
BEFORE UPDATE ON dataset_content
FOR EACH ROW
WHEN (
    OLD.* IS DISTINCT FROM NEW.*
)
EXECUTE FUNCTION create_dataset_content_revision();


-- ============================================================
-- 20. WORKFLOW ACTION LOGGING
-- ============================================================
-- Application can explicitly call this function whenever a
-- workflow transition occurs.
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
-- 21. CONTENT WORKFLOW VALIDATION
-- ============================================================
-- Prevents invalid publication of incomplete content.
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


DROP TRIGGER IF EXISTS trg_validate_dataset_content_publication
ON dataset_content;

CREATE TRIGGER trg_validate_dataset_content_publication
BEFORE INSERT OR UPDATE ON dataset_content
FOR EACH ROW
EXECUTE FUNCTION validate_dataset_content_publication();


-- ============================================================
-- 22. RLS SETUP
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


-- ============================================================
-- 23. HELPER: CMS PRIVILEGE CHECK
-- ============================================================
-- Supports both role_id join and legacy role column string
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
-- 24. DATASET CONTENT POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_published_dataset_content
ON dataset_content;

CREATE POLICY cms_read_published_dataset_content
ON dataset_content
FOR SELECT
USING (
    content_status = 'PUBLISHED'
    OR is_cms_user()
);


DROP POLICY IF EXISTS cms_manage_dataset_content
ON dataset_content;

CREATE POLICY cms_manage_dataset_content
ON dataset_content
FOR ALL
USING (
    is_cms_user()
)
WITH CHECK (
    is_cms_user()
);


-- ============================================================
-- 25. CONTENT SECTION POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_content_sections
ON dataset_content_sections;

CREATE POLICY cms_read_content_sections
ON dataset_content_sections
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM dataset_content dc
        WHERE dc.id = dataset_content_sections.dataset_content_id
        AND (
            dc.content_status = 'PUBLISHED'
            OR is_cms_user()
        )
    )
);


DROP POLICY IF EXISTS cms_manage_content_sections
ON dataset_content_sections;

CREATE POLICY cms_manage_content_sections
ON dataset_content_sections
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 26. CONTENT BLOCK POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_content_blocks
ON content_blocks;

CREATE POLICY cms_read_content_blocks
ON content_blocks
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM dataset_content dc
        WHERE dc.id = content_blocks.dataset_content_id
        AND (
            dc.content_status = 'PUBLISHED'
            OR is_cms_user()
        )
    )
);


DROP POLICY IF EXISTS cms_manage_content_blocks
ON content_blocks;

CREATE POLICY cms_manage_content_blocks
ON content_blocks
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 27. MEDIA POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_dataset_media
ON dataset_media;

CREATE POLICY cms_read_dataset_media
ON dataset_media
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM dataset_content dc
        WHERE dc.id = dataset_media.dataset_content_id
        AND (
            dc.content_status = 'PUBLISHED'
            OR is_cms_user()
        )
    )
    OR is_cms_user()
);


DROP POLICY IF EXISTS cms_manage_dataset_media
ON dataset_media;

CREATE POLICY cms_manage_dataset_media
ON dataset_media
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 28. WORKFLOW POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_manage_workflows
ON content_workflows;

CREATE POLICY cms_manage_workflows
ON content_workflows
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


DROP POLICY IF EXISTS cms_read_workflow_actions
ON workflow_actions;

CREATE POLICY cms_read_workflow_actions
ON workflow_actions
FOR SELECT
USING (is_cms_user());


DROP POLICY IF EXISTS cms_insert_workflow_actions
ON workflow_actions;

CREATE POLICY cms_insert_workflow_actions
ON workflow_actions
FOR INSERT
WITH CHECK (is_cms_user());


-- ============================================================
-- 29. REVISION POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_revisions
ON dataset_content_revisions;

CREATE POLICY cms_read_revisions
ON dataset_content_revisions
FOR SELECT
USING (is_cms_user());


DROP POLICY IF EXISTS cms_insert_revisions
ON dataset_content_revisions;

CREATE POLICY cms_insert_revisions
ON dataset_content_revisions
FOR INSERT
WITH CHECK (is_cms_user());


-- ============================================================
-- 30. INGESTION POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_manage_ingestion
ON dataset_ingestion_jobs;

CREATE POLICY cms_manage_ingestion
ON dataset_ingestion_jobs
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 31. SCHEMA POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_dataset_schemas
ON dataset_schemas;

CREATE POLICY cms_read_dataset_schemas
ON dataset_schemas
FOR SELECT
USING (
    is_cms_user()
    OR EXISTS (
        SELECT 1
        FROM dataset_versions dv
        JOIN datasets d
            ON d.id = dv.dataset_id
        JOIN dataset_content dc
            ON dc.dataset_id = d.id
        WHERE dv.id = dataset_schemas.dataset_version_id
        AND dc.content_status = 'PUBLISHED'
    )
);


DROP POLICY IF EXISTS cms_manage_dataset_schemas
ON dataset_schemas;

CREATE POLICY cms_manage_dataset_schemas
ON dataset_schemas
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 32. PRODUCT CONTENT POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_product_content
ON product_content;

CREATE POLICY cms_read_product_content
ON product_content
FOR SELECT
USING (
    status = 'PUBLISHED'
    OR is_cms_user()
);


DROP POLICY IF EXISTS cms_manage_product_content
ON product_content;

CREATE POLICY cms_manage_product_content
ON product_content
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 33. PRODUCT RELATIONSHIP POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_product_relationships
ON product_relationships;

CREATE POLICY cms_read_product_relationships
ON product_relationships
FOR SELECT
USING (TRUE);


DROP POLICY IF EXISTS cms_manage_product_relationships
ON product_relationships;

CREATE POLICY cms_manage_product_relationships
ON product_relationships
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 34. API DOCUMENTATION POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_api_documentation
ON api_documentation;

CREATE POLICY cms_read_api_documentation
ON api_documentation
FOR SELECT
USING (TRUE);


DROP POLICY IF EXISTS cms_manage_api_documentation
ON api_documentation;

CREATE POLICY cms_manage_api_documentation
ON api_documentation
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 35. MODEL CARD POLICIES
-- ============================================================

DROP POLICY IF EXISTS cms_read_model_cards
ON model_cards;

CREATE POLICY cms_read_model_cards
ON model_cards
FOR SELECT
USING (TRUE);


DROP POLICY IF EXISTS cms_manage_model_cards
ON model_cards;

CREATE POLICY cms_manage_model_cards
ON model_cards
FOR ALL
USING (is_cms_user())
WITH CHECK (is_cms_user());


-- ============================================================
-- 36. SEED CMS ROLES
-- ============================================================
-- Only inserts if roles already exist with matching names.
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
-- 37. CMS SECTION SEED DEFINITIONS
-- ============================================================
-- These are not dataset-specific records.
-- They provide the standard CMS structure expected by IYEOB.
--
-- Application code can use these keys when creating content.
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

ALTER TABLE cms_section_definitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cms_read_section_definitions ON cms_section_definitions;
CREATE POLICY cms_read_section_definitions ON cms_section_definitions FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS cms_manage_section_definitions ON cms_section_definitions;
CREATE POLICY cms_manage_section_definitions ON cms_section_definitions FOR ALL USING (is_cms_user()) WITH CHECK (is_cms_user());


INSERT INTO cms_section_definitions
    (section_key, title, description, display_order, required_for_publication)
VALUES
    (
        'INTRODUCTION',
        'Introduction',
        'High-level introduction to the dataset.',
        10,
        TRUE
    ),
    (
        'BACKGROUND',
        'Background',
        'Context and motivation for creating the dataset.',
        20,
        FALSE
    ),
    (
        'WHY_THIS_DATASET',
        'Why This Dataset',
        'Problem the dataset is designed to address.',
        30,
        FALSE
    ),
    (
        'WHAT_IS_INCLUDED',
        'What Is Included',
        'Description of dataset contents.',
        40,
        FALSE
    ),
    (
        'METHODOLOGY',
        'Methodology',
        'Synthetic data generation methodology.',
        50,
        TRUE
    ),
    (
        'DATA_GENERATION',
        'Data Generation',
        'How synthetic records were generated.',
        60,
        TRUE
    ),
    (
        'VARIABLES',
        'Variables',
        'Dataset variables and data dictionary.',
        70,
        TRUE
    ),
    (
        'QUALITY',
        'Quality',
        'Data quality and validation information.',
        80,
        TRUE
    ),
    (
        'RESEARCH_QUESTIONS',
        'Research Questions',
        'Potential research and analytical questions.',
        90,
        FALSE
    ),
    (
        'USE_CASES',
        'Use Cases',
        'Potential practical applications.',
        100,
        FALSE
    ),
    (
        'LIMITATIONS',
        'Limitations',
        'Known limitations and caveats.',
        110,
        TRUE
    ),
    (
        'ETHICAL_CONSIDERATIONS',
        'Ethical Considerations',
        'Ethical, privacy and bias considerations.',
        120,
        FALSE
    ),
    (
        'HOW_TO_USE',
        'How to Use',
        'Instructions for using the dataset.',
        130,
        FALSE
    ),
    (
        'CITATION',
        'Citation',
        'Recommended dataset citation.',
        140,
        TRUE
    ),
    (
        'FAQ',
        'Frequently Asked Questions',
        'Common questions about the dataset.',
        150,
        FALSE
    )
ON CONFLICT (section_key) DO NOTHING;


-- ============================================================
-- 38. CMS VIEW
-- ============================================================
-- Convenient view for frontend/API catalogue.
-- Note: 'd.title AS name, d.title' supports both schema naming conventions.
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


-- ============================================================
-- 39. CMS DASHBOARD VIEW
-- ============================================================

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
-- 40. GRANTS
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
-- 41. COMMENTS / DOCUMENTATION
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
-- 42. FINAL MIGRATION MARKER
-- ============================================================

INSERT INTO system_settings (
    key,
    value,
    description
)
VALUES (
    'cms_schema_version',
    to_jsonb('1.0.0'::text),
    'IYEOB CMS database extension version.'
)
ON CONFLICT (key)
DO UPDATE SET
    value = EXCLUDED.value;


COMMIT;
