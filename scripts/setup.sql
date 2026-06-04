-- =============================================================================
-- MASTER SETUP SCRIPT
-- =============================================================================
-- Run this once on any fresh PostgreSQL / Supabase instance to set up the
-- complete database schema for the application.
--
-- HOW TO RUN:
--   Supabase cloud:  Paste into SQL Editor and click Run
--   psql (any host): psql -h <host> -U <user> -d <db> -f scripts/setup.sql
--   Railway/Neon:    Paste into their SQL console
--
-- This script is idempotent — safe to run multiple times.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- EXTENSIONS
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------------
-- SHARED TRIGGER FUNCTION
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- TABLE: subscriptions
-- Tracks the user's current plan and Stripe customer/subscription IDs.
-- Under the credits model this table is kept for backward compat but new
-- users are gated via credit_ledger, not this table.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
  user_id                 uuid        NOT NULL,
  stripe_customer_id      text        NULL,
  stripe_subscription_id  text        NULL,
  subscription_plan       text        NULL DEFAULT 'free',
  subscription_status     text        NULL,
  current_period_end      timestamptz NULL,
  trial_end               timestamptz NULL,
  created_at              timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at              timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT subscriptions_pkey                       PRIMARY KEY (user_id),
  CONSTRAINT subscriptions_user_id_key                UNIQUE (user_id),
  CONSTRAINT subscriptions_stripe_subscription_id_key UNIQUE (stripe_subscription_id),
  CONSTRAINT subscriptions_stripe_customer_id_key     UNIQUE (stripe_customer_id),
  CONSTRAINT subscriptions_subscription_plan_check    CHECK (subscription_plan = ANY (ARRAY['free','pro'])),
  CONSTRAINT subscriptions_subscription_status_check  CHECK (
    subscription_status IS NULL OR
    subscription_status = ANY (ARRAY['active','canceled'])
  )
);

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS subscriptions_policy ON public.subscriptions;
CREATE POLICY subscriptions_policy ON public.subscriptions
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT ALL    ON public.subscriptions TO authenticated;
GRANT SELECT ON public.subscriptions TO anon;
GRANT ALL    ON public.subscriptions TO service_role;

-- =============================================================================
-- TABLE: stripe_webhook_events
-- Idempotency table — prevents processing the same Stripe event twice.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.stripe_webhook_events (
  event_id    text        NOT NULL,
  event_type  text        NOT NULL,
  processed_at timestamptz NULL,
  created_at  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at  timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT stripe_webhook_events_pkey PRIMARY KEY (event_id)
);

DROP TRIGGER IF EXISTS update_stripe_webhook_events_updated_at ON public.stripe_webhook_events;
CREATE TRIGGER update_stripe_webhook_events_updated_at
  BEFORE UPDATE ON public.stripe_webhook_events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.stripe_webhook_events FROM anon, authenticated;
GRANT  ALL ON TABLE public.stripe_webhook_events TO service_role;

-- =============================================================================
-- TABLE: jobs
-- Job descriptions users paste in when applying.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.jobs (
  id               uuid        NOT NULL DEFAULT uuid_generate_v4(),
  user_id          uuid        NOT NULL,
  company_name     text        NULL,
  position_title   text        NOT NULL,
  job_url          text        NULL,
  description      text        NULL,
  location         text        NULL,
  salary_range     text        NULL,
  keywords         jsonb       NULL DEFAULT '[]',
  work_location    text        NULL DEFAULT 'in_person',
  employment_type  text        NULL DEFAULT 'full_time',
  is_active        boolean     NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at       timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT jobs_pkey PRIMARY KEY (id)
);

DROP TRIGGER IF EXISTS update_jobs_updated_at ON public.jobs;
CREATE TRIGGER update_jobs_updated_at
  BEFORE UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS jobs_user_id_created_at_idx ON public.jobs (user_id, created_at DESC);

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS jobs_policy ON public.jobs;
CREATE POLICY jobs_policy ON public.jobs
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT ALL    ON public.jobs TO authenticated;
GRANT SELECT ON public.jobs TO anon;
GRANT ALL    ON public.jobs TO service_role;

-- =============================================================================
-- TABLE: resumes
-- Both base resumes and job-tailored resumes.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.resumes (
  id                  uuid    NOT NULL DEFAULT uuid_generate_v4(),
  user_id             uuid    NOT NULL,
  job_id              uuid    NULL,
  is_base_resume      boolean NULL DEFAULT false,
  name                text    NOT NULL,
  first_name          text    NULL,
  last_name           text    NULL,
  email               text    NULL,
  phone_number        text    NULL,
  location            text    NULL,
  website             text    NULL,
  linkedin_url        text    NULL,
  github_url          text    NULL,
  professional_summary text   NULL,
  work_experience     jsonb   NULL DEFAULT '[]',
  education           jsonb   NULL DEFAULT '[]',
  skills              jsonb   NULL DEFAULT '[]',
  projects            jsonb   NULL DEFAULT '[]',
  certifications      jsonb   NULL DEFAULT '[]',
  section_order       jsonb   NULL DEFAULT '["professional_summary","work_experience","skills","projects","education","certifications"]',
  section_configs     jsonb   NULL DEFAULT '{"skills":{"style":"grouped","visible":true},"projects":{"visible":true,"max_items":3},"education":{"visible":true,"max_items":null},"certifications":{"visible":true},"work_experience":{"visible":true,"max_items":null}}',
  document_settings   jsonb   NULL DEFAULT '{"header_name_size":24,"skills_margin_top":2,"document_font_size":10,"projects_margin_top":2,"skills_item_spacing":2,"document_line_height":1.5,"education_margin_top":2,"skills_margin_bottom":2,"experience_margin_top":2,"projects_item_spacing":4,"education_item_spacing":4,"projects_margin_bottom":2,"education_margin_bottom":2,"experience_item_spacing":4,"document_margin_vertical":36,"experience_margin_bottom":2,"skills_margin_horizontal":0,"document_margin_horizontal":36,"header_name_bottom_spacing":24,"projects_margin_horizontal":0,"education_margin_horizontal":0,"experience_margin_horizontal":0}',
  resume_title        text    NULL,
  target_role         text    NULL,
  has_cover_letter    boolean NOT NULL DEFAULT false,
  cover_letter        jsonb   NULL,
  created_at          timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at          timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT resumes_pkey       PRIMARY KEY (id),
  CONSTRAINT resumes_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TRIGGER IF EXISTS update_resumes_updated_at ON public.resumes;
CREATE TRIGGER update_resumes_updated_at
  BEFORE UPDATE ON public.resumes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS resumes_user_id_created_at_idx ON public.resumes (user_id, created_at DESC);

ALTER TABLE public.resumes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS resumes_policy ON public.resumes;
CREATE POLICY resumes_policy ON public.resumes
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT ALL    ON public.resumes TO authenticated;
GRANT SELECT ON public.resumes TO anon;
GRANT ALL    ON public.resumes TO service_role;

-- =============================================================================
-- TABLE: profiles
-- Master career data store for each user. Source of truth for all CV generation.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  user_id          uuid    NOT NULL,
  first_name       text    NULL,
  last_name        text    NULL,
  email            text    NULL,
  phone_number     text    NULL,
  location         text    NULL,
  website          text    NULL,
  linkedin_url     text    NULL,
  github_url       text    NULL,
  is_admin         boolean NOT NULL DEFAULT false,
  work_experience  jsonb   NULL DEFAULT '[]',
  education        jsonb   NULL DEFAULT '[]',
  skills           jsonb   NULL DEFAULT '[]',
  projects         jsonb   NULL DEFAULT '[]',
  certifications   jsonb   NULL DEFAULT '[]',
  created_at       timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at       timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT profiles_pkey         PRIMARY KEY (user_id),
  CONSTRAINT profiles_user_id_key  UNIQUE (user_id)
);

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profiles_policy ON public.profiles;
CREATE POLICY profiles_policy ON public.profiles
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT ALL    ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO anon;
GRANT ALL    ON public.profiles TO service_role;

-- =============================================================================
-- TABLE: ai_usage_events
-- Tracks every AI request: provider, model, token counts, status.
-- Service role only — users cannot read this.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.ai_usage_events (
  id              uuid    NOT NULL DEFAULT uuid_generate_v4(),
  user_id         uuid    NOT NULL,
  route           text    NOT NULL,
  provider        text    NOT NULL,
  model           text    NOT NULL,
  is_pro          boolean NOT NULL DEFAULT false,
  used_server_key boolean NOT NULL DEFAULT false,
  status          text    NOT NULL CHECK (status IN ('started','succeeded','failed','rate_limited','blocked')),
  error_code      text    NULL,
  input_tokens    integer NULL,
  output_tokens   integer NULL,
  total_tokens    integer NULL,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT ai_usage_events_pkey        PRIMARY KEY (id),
  CONSTRAINT ai_usage_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ai_usage_events_user_created_idx  ON public.ai_usage_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ai_usage_events_route_created_idx ON public.ai_usage_events (route,   created_at DESC);

ALTER TABLE public.ai_usage_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.ai_usage_events FROM anon, authenticated;
GRANT  ALL ON TABLE public.ai_usage_events TO service_role;

-- =============================================================================
-- TABLE: credit_ledger
-- Every credit transaction (purchase, spend, refund, welcome bonus).
-- The user's balance = SUM(amount) WHERE user_id = $1.
-- Never store a balance field — the ledger is the source of truth.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.credit_ledger (
  id           uuid    NOT NULL DEFAULT uuid_generate_v4(),
  user_id      uuid    NOT NULL,
  amount       integer NOT NULL, -- positive = credit added, negative = credit spent
  action       text    NOT NULL CHECK (action IN (
    'purchase',
    'welcome_bonus',
    'tailored_resume',
    'cover_letter',
    'ai_chat',
    'ats_score',
    'interview_prep',
    'admin_adjustment',
    'refund'
  )),
  reference_id text    NULL, -- stripe payment_intent id, resume id, etc.
  description  text    NULL, -- human-readable note
  created_at   timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT credit_ledger_pkey         PRIMARY KEY (id),
  CONSTRAINT credit_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS credit_ledger_user_id_created_idx ON public.credit_ledger (user_id, created_at DESC);

ALTER TABLE public.credit_ledger ENABLE ROW LEVEL SECURITY;

-- Users can read their own ledger; only service_role can write
DROP POLICY IF EXISTS credit_ledger_read_policy ON public.credit_ledger;
CREATE POLICY credit_ledger_read_policy ON public.credit_ledger
  FOR SELECT USING (user_id = auth.uid());

GRANT SELECT ON public.credit_ledger TO authenticated;
GRANT ALL    ON public.credit_ledger TO service_role;

-- =============================================================================
-- TRIGGER: welcome_bonus_on_profile_create
-- Awards 50 free credits automatically when a user's profile is first created.
-- Change the credit amount here to adjust the welcome bonus.
-- =============================================================================
CREATE OR REPLACE FUNCTION grant_welcome_credits()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.credit_ledger (user_id, amount, action, description)
  VALUES (NEW.user_id, 50, 'welcome_bonus', 'Welcome bonus — thanks for joining!');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS welcome_bonus_on_profile_create ON public.profiles;
CREATE TRIGGER welcome_bonus_on_profile_create
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION grant_welcome_credits();

-- =============================================================================
-- VIEW: credit_balance
-- Convenience view so the app can query balance with a single SELECT.
-- Usage: SELECT balance FROM credit_balance WHERE user_id = auth.uid()
-- =============================================================================
CREATE OR REPLACE VIEW public.credit_balance AS
SELECT
  user_id,
  COALESCE(SUM(amount), 0)::integer AS balance
FROM public.credit_ledger
GROUP BY user_id;

GRANT SELECT ON public.credit_balance TO authenticated;
GRANT SELECT ON public.credit_balance TO service_role;

-- =============================================================================
-- END OF SETUP SCRIPT
-- =============================================================================
