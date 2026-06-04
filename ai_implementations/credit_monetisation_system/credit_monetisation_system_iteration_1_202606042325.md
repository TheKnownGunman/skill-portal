# Credit Monetisation System — Iteration 1
**Timestamp:** 2026-06-04 23:25  
**Branch:** `claude/distracted-agnesi-cf4f94`  
**Commit:** `5f65a4e`

---

## Summary

Replaced the existing free/pro subscription model with a credits-only pay-as-you-go system. Users buy credit bundles via Stripe one-time payments and spend credits per AI action. 50 welcome credits are automatically awarded on signup via a database trigger.

---

## Decisions Made

| Decision | Choice | Reason |
|---|---|---|
| Billing model | Credits only (no subscription) | Matches the discrete value proposition — users pay per application, not per month |
| Welcome credits | 50 | Enough for 5 tailored CVs; generous enough to demonstrate value before a purchase |
| Bundle pricing | $9 / $19 / $49 | Standard SaaS micro-transaction pricing; ~95%+ gross margin on AI cost |
| Credit amounts | 50 / 150 / 500 | Configurable via env vars — no code change needed to reprice |
| Welcome bonus mechanism | Database trigger on `profiles` insert | Reliable, automatic, works regardless of how the profile is created |
| Stripe mode | `payment` (one-time) not `subscription` | Credits are consumed discretely; recurring billing adds unnecessary complexity |

---

## Files Created

### `scripts/setup.sql`
**Purpose:** Single portable SQL script that bootstraps the entire database on any PostgreSQL instance (Supabase, Railway, Neon, Render, etc.).  
**Contents:** All tables, indexes, RLS policies, triggers, and the `credit_balance` view. Idempotent — safe to run multiple times.  
**How to run:**
- Supabase: SQL Editor → paste → Run
- Any PostgreSQL: `psql -h <host> -U <user> -d <db> -f scripts/setup.sql`

---

### `supabase/migrations/20260520000001_create_credit_ledger.sql`
**Purpose:** Supabase CLI migration for the credit system specifically (does not duplicate the full schema).  
**Creates:**
- `public.credit_ledger` table
- Index on `(user_id, created_at DESC)`
- RLS: users can `SELECT` their own rows; `service_role` has full access
- `grant_welcome_credits()` trigger function
- `welcome_bonus_on_profile_create` trigger on `public.profiles`
- `credit_balance` view

---

### `src/lib/stripe/credit-bundles.ts`
**Purpose:** Single source of truth for credit bundle configuration and per-action credit costs.  
**Key exports:**
- `CREDIT_BUNDLES: CreditBundle[]` — the three purchasable bundles (Starter/Standard/Pro)
- `PRICE_ID_TO_CREDITS: Record<string, number>` — maps Stripe Price IDs to credit amounts, used in the webhook
- `CREDIT_COSTS` — how many credits each action costs:
  ```
  TAILORED_RESUME:  10 credits
  COVER_LETTER:      5 credits
  AI_CHAT_MESSAGE:   1 credit
  ATS_SCORE:         3 credits
  INTERVIEW_PREP:    5 credits
  ```
**Configurability:** Credit amounts per bundle are read from `NEXT_PUBLIC_CREDITS_*_AMOUNT` env vars — change the amount without a code deployment.

---

### `src/utils/actions/credits/actions.ts`
**Purpose:** All server-side credit operations.  
**Exports:**

| Function | Description |
|---|---|
| `getUserCreditBalance()` | Returns balance for the authenticated user |
| `getUserCreditBalanceById(userId)` | Returns balance for any user (service role) |
| `deductCredits(userId, action, referenceId?)` | Checks balance → inserts negative ledger entry. Returns `{ success, balance }` |
| `addCredits(userId, amount, action, referenceId?, description?)` | Inserts positive ledger entry (purchase, admin, refund) |
| `refundCredits(userId, action, referenceId?)` | Refunds credits for a failed AI action |
| `getCreditHistory(page, pageSize)` | Paginated ledger for the user-facing history page |
| `canAffordAction(action)` | Guard helper — returns `{ canAfford, balance, cost }` without deducting |

**Usage pattern for AI actions:**
```typescript
// 1. Check before showing UI
const { canAfford } = await canAffordAction('TAILORED_RESUME')
if (!canAfford) redirect('/credits')

// 2. Deduct before AI call
const deduction = await deductCredits(userId, 'TAILORED_RESUME', resumeId)
if (!deduction.success) throw new InsufficientCreditsError()

// 3. Refund if AI fails
try {
  await runAI(...)
} catch {
  await refundCredits(userId, 'TAILORED_RESUME', resumeId)
  throw err
}
```

---

## Files Modified

### `src/app/(dashboard)/subscription/stripe-session.tsx`
**Changes:**
1. **Bug fix:** Removed module-level `new Stripe(apiKey)` — was causing `Error: Neither apiKey nor config.authenticator provided` during `next build` on Vercel. Moved to a lazy `getStripe()` helper called at request time.
2. **Replaced** `postStripeSession()` (subscription checkout) with `createCreditPurchaseSession(priceId)` (one-time payment checkout).
3. **Kept** `createPortalSession()` — users can still manage payment methods and download invoices.
4. **Return URL** updated to `/credits/success` (page to be built in next iteration).

---

### `src/app/api/webhooks/stripe/route.ts`
**Changes:**
1. **Added imports:** `addCredits` from credits actions, `PRICE_ID_TO_CREDITS` from credit-bundles.
2. **Added `payment_intent.payment_failed`** to `relevantEvents` set.
3. **Updated `checkout.session.completed` handler:**
   - If `session.mode === 'payment'` → retrieve line items, look up credit amount from `PRICE_ID_TO_CREDITS`, call `addCredits()`, fire PostHog `CheckoutCompleted` event.
   - If `session.mode === 'subscription'` → falls through to legacy subscription handler (kept for backward compat).

---

### `src/lib/types.ts`
**Added types:**
- `CreditLedgerAction` — union type of all valid action strings
- `CreditLedgerEntry` — interface matching the `credit_ledger` table row

---

### `.env.example`
**Added variables:**
```
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY
NEXT_PUBLIC_STRIPE_CREDITS_STARTER
NEXT_PUBLIC_STRIPE_CREDITS_STANDARD
NEXT_PUBLIC_STRIPE_CREDITS_PRO
NEXT_PUBLIC_CREDITS_STARTER_AMOUNT
NEXT_PUBLIC_CREDITS_STANDARD_AMOUNT
NEXT_PUBLIC_CREDITS_PRO_AMOUNT
```

---

## Database Schema Added

```sql
CREATE TABLE public.credit_ledger (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount       integer NOT NULL,  -- positive = credit, negative = debit
  action       text NOT NULL CHECK (action IN (
    'purchase', 'welcome_bonus', 'tailored_resume', 'cover_letter',
    'ai_chat', 'ats_score', 'interview_prep', 'admin_adjustment', 'refund'
  )),
  reference_id text,
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
```

**RLS:** Users can only `SELECT` their own rows. All writes go through `service_role` (server actions and webhook only).

**Trigger:** `welcome_bonus_on_profile_create` — fires `AFTER INSERT ON profiles`, inserts 50 credits into `credit_ledger` automatically.

**View:** `credit_balance` — `SELECT user_id, SUM(amount) AS balance FROM credit_ledger GROUP BY user_id`. Query balance with a single `SELECT`.

---

## What Still Needs to Be Built (Next Iterations)

| Task | Priority |
|---|---|
| `/credits` page — show balance, display bundles, trigger checkout | P0 |
| `/credits/success` page — confirm purchase, show new balance | P0 |
| Credit balance chip in `AppHeader` | P0 |
| Wire `deductCredits` into `tailorResume()` server action | P0 |
| Wire `deductCredits` into AI chat route | P1 |
| Admin credit adjustment UI | P1 |
| Credit history page | P1 |

---

## Environment Variables Required in Vercel

| Variable | Where to get it |
|---|---|
| `STRIPE_SECRET_KEY` | Stripe Dashboard → Developers → API Keys |
| `STRIPE_WEBHOOK_SECRET` | Stripe Dashboard → Webhooks → your endpoint |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Stripe Dashboard → Developers → API Keys |
| `NEXT_PUBLIC_STRIPE_CREDITS_STARTER` | Create a one-time Price in Stripe for $9 |
| `NEXT_PUBLIC_STRIPE_CREDITS_STANDARD` | Create a one-time Price in Stripe for $19 |
| `NEXT_PUBLIC_STRIPE_CREDITS_PRO` | Create a one-time Price in Stripe for $49 |
| `NEXT_PUBLIC_CREDITS_STARTER_AMOUNT` | Set to `50` |
| `NEXT_PUBLIC_CREDITS_STANDARD_AMOUNT` | Set to `150` |
| `NEXT_PUBLIC_CREDITS_PRO_AMOUNT` | Set to `500` |

---

## Stripe Webhook Events to Register

In Stripe Dashboard → Developers → Webhooks → your endpoint, enable:

- `checkout.session.completed` ← **critical for credits**
- `payment_intent.payment_failed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `customer.deleted`
