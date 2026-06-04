-- Migration: create credit_ledger table and welcome bonus trigger
-- Run date: 2026-05-20
-- Purpose: Replace subscription gating with a per-action credit system.

CREATE TABLE IF NOT EXISTS public.credit_ledger (
  id           uuid    NOT NULL DEFAULT uuid_generate_v4(),
  user_id      uuid    NOT NULL,
  amount       integer NOT NULL,
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
  reference_id text    NULL,
  description  text    NULL,
  created_at   timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT credit_ledger_pkey         PRIMARY KEY (id),
  CONSTRAINT credit_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS credit_ledger_user_id_created_idx ON public.credit_ledger (user_id, created_at DESC);

ALTER TABLE public.credit_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS credit_ledger_read_policy ON public.credit_ledger;
CREATE POLICY credit_ledger_read_policy ON public.credit_ledger
  FOR SELECT USING (user_id = auth.uid());

GRANT SELECT ON public.credit_ledger TO authenticated;
GRANT ALL    ON public.credit_ledger TO service_role;

-- Welcome bonus trigger: fires when a profile row is created for a new user.
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

-- Convenience view for balance queries
CREATE OR REPLACE VIEW public.credit_balance AS
SELECT
  user_id,
  COALESCE(SUM(amount), 0)::integer AS balance
FROM public.credit_ledger
GROUP BY user_id;

GRANT SELECT ON public.credit_balance TO authenticated;
GRANT SELECT ON public.credit_balance TO service_role;
