# AI Job Application Engine

An AI-powered platform that generates tailored CVs and cover letters from a user's profile in under 60 seconds. Users buy credits and spend them per action — no subscriptions.

Built with Next.js 15, Supabase, Stripe, and the Vercel AI SDK.

---

## Table of Contents

1. [Local Development](#1-local-development)
2. [Deploy on Vercel](#2-deploy-on-vercel)
3. [Deploy on Any Other Infrastructure](#3-deploy-on-any-other-infrastructure)
4. [Database Setup](#4-database-setup)
5. [Stripe Setup](#5-stripe-setup)
6. [Environment Variables Reference](#6-environment-variables-reference)
7. [Testing](#7-testing)

---

## 1. Local Development

### Prerequisites

- Node.js 18+
- pnpm (`npm install -g pnpm`)
- A Supabase project (cloud or local Docker)
- At least one AI provider API key

### Steps

**1. Clone and install**
```bash
git clone https://github.com/TheKnownGunman/skill-portal.git
cd skill-portal
pnpm install
```

**2. Set up environment variables**
```bash
cp .env.example .env.local
```
Fill in `.env.local` — see [Environment Variables Reference](#6-environment-variables-reference).

**3. Set up the database**

Run `scripts/setup.sql` in your Supabase SQL editor (see [Database Setup](#4-database-setup)).

**4. Start the dev server**
```bash
pnpm dev
```

App runs at `http://localhost:3000`.

---

### Option B — Full local stack with Docker

Runs Supabase, PostgreSQL, and Redis locally. No cloud accounts needed for development.

```bash
# 1. Copy env file and add at least one AI key
cp .env.example .env.local

# 2. Start all services
cd docker
docker compose --env-file ../.env.local up -d

# 3. Wait ~60 seconds for services to be healthy, then verify
docker compose --env-file ../.env.local ps

# 4. Start the Next.js app from the project root
cd ..
pnpm dev
```

**Default admin login:** `admin@admin.com` / `Admin123` (Pro auto-granted in Docker mode)

| Service | URL |
|---|---|
| App | http://localhost:3000 |
| Supabase Studio | http://localhost:54323 |
| Supabase API | http://localhost:54321 |
| Redis UI | http://localhost:8081 |

**To test Stripe webhooks locally:**
```bash
# Install the Stripe CLI, then:
stripe login
stripe listen --forward-to localhost:3000/api/webhooks/stripe
# Copy the whsec_... it prints and add it to .env.local as STRIPE_WEBHOOK_SECRET
```

---

## 2. Deploy on Vercel

### Step 1 — Connect repository

1. Go to [vercel.com](https://vercel.com) → **Add New Project**
2. Import your GitHub repository
3. Framework preset: **Next.js** (auto-detected)
4. Leave build settings as default — do not change them

### Step 2 — Set environment variables

In Vercel → **Settings** → **Environment Variables**, add every variable from the [reference table](#6-environment-variables-reference) below. Set each one for **Production**, **Preview**, and **Development**.

Critical ones that must be correct before the first deploy:

| Variable | Where to get it |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Project Settings → Data API → **Project URL** (no trailing slash, no `/rest/v1`) |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase → Project Settings → API Keys → **anon / public** |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API Keys → **service_role** (click reveal) |
| `NEXT_PUBLIC_SITE_URL` | Your Vercel domain e.g. `https://your-app.vercel.app` |

### Step 3 — Set up the database

Run `scripts/setup.sql` in the Supabase SQL editor **before** the first deploy. See [Database Setup](#4-database-setup).

### Step 4 — Deploy

Click **Deploy**. Vercel builds and deploys automatically.

Every future push to `main` triggers a new production deployment automatically.

### Step 5 — Register the Stripe webhook

After the first deploy, go to the Stripe dashboard → **Developers** → **Webhooks** → **Add endpoint**:
- URL: `https://your-app.vercel.app/api/webhooks/stripe`
- Events: `checkout.session.completed`, `payment_intent.payment_failed`, `customer.subscription.deleted`, `customer.deleted`, `invoice.paid`

Copy the **Signing secret** (`whsec_...`) and add it to Vercel as `STRIPE_WEBHOOK_SECRET`, then redeploy.

### Vercel plan recommendation

| Traffic | Plan needed |
|---|---|
| 0–100 users | Hobby (free) — fine for early testing |
| 100+ users | **Pro ($20/month)** — required for 60s function timeout (AI calls can take 15–30s) |

---

## 3. Deploy on Any Other Infrastructure

The app is a standard Next.js application. It runs anywhere Node.js runs. The only Vercel-specific thing is the serverless function timeout — set it manually on other platforms.

### Railway

```bash
# Install Railway CLI
npm install -g @railway/cli
railway login

# Create project and link
railway init
railway link

# Set environment variables (one at a time or via dashboard)
railway variables set NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
# ... repeat for all variables

# Deploy
railway up
```

Set the **start command** to `pnpm start` and the **build command** to `pnpm build`.

### Render

1. New Web Service → connect GitHub repo
2. Build command: `pnpm install && pnpm build`
3. Start command: `pnpm start`
4. Add all environment variables in the **Environment** tab
5. Set instance type to at least **Standard** (512 MB RAM minimum for Next.js build)

### Self-hosted VPS (Ubuntu/Debian)

```bash
# 1. Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g pnpm pm2

# 2. Clone and build
git clone https://github.com/TheKnownGunman/skill-portal.git
cd skill-portal
pnpm install
cp .env.example .env.local
# Fill in .env.local with all variables

pnpm build

# 3. Start with PM2 (keeps the process alive)
pm2 start "pnpm start" --name skill-portal
pm2 save
pm2 startup

# 4. Set up Nginx reverse proxy (port 3000 → 80/443)
# 5. Add SSL via Certbot: sudo certbot --nginx
```

### Moving between platforms

The app has no platform lock-in. To move:
1. Export env vars from old platform
2. Import env vars to new platform
3. Run `scripts/setup.sql` on the new database if switching databases
4. Point your domain DNS to the new platform
5. Update `NEXT_PUBLIC_SITE_URL` to the new domain
6. Update the Stripe webhook URL to the new domain

The database (Supabase) is independent of the hosting platform — you can switch hosting without touching the database.

---

## 4. Database Setup

### Fresh install (any platform)

Run `scripts/setup.sql` in your database SQL console. This single script creates all tables, indexes, RLS policies, and the credit system.

**Supabase cloud:**
1. Go to your Supabase project → **SQL Editor** → **New query**
2. Paste the entire contents of `scripts/setup.sql`
3. Click **Run**

**Any PostgreSQL (psql):**
```bash
psql -h <host> -U <user> -d <database> -f scripts/setup.sql
```

**Railway / Neon / Render PostgreSQL:**
Paste `scripts/setup.sql` into their SQL console.

### What the setup script creates

| Object | Purpose |
|---|---|
| `profiles` | User career data — source of truth for CV generation |
| `resumes` | Generated CVs (base and tailored) |
| `jobs` | Job descriptions users paste in |
| `subscriptions` | Legacy billing table (kept for backward compat) |
| `stripe_webhook_events` | Idempotency — prevents duplicate webhook processing |
| `ai_usage_events` | Every AI request: provider, model, tokens, status |
| `credit_ledger` | Every credit transaction (purchases, spends, refunds) |
| `credit_balance` view | `SELECT balance FROM credit_balance WHERE user_id = ?` |
| `grant_welcome_credits()` | Trigger function: awards 50 credits on profile creation |

### Migrations (for existing installs)

If the base schema already exists and you only need to add the credit system:

```bash
# Run just the credit ledger migration
psql -h <host> -U <user> -d <database> -f supabase/migrations/20260520000001_create_credit_ledger.sql
```

Migrations are stored in `supabase/migrations/` in chronological order. Run them in filename order on any fresh instance.

---

## 5. Stripe Setup

### Create credit bundle products

In the Stripe dashboard → **Products** → **Add product**:

Create one product called **"Credits"** with three prices:

| Price | Amount | Type | Env var |
|---|---|---|---|
| Starter | $9.00 | One time | `NEXT_PUBLIC_STRIPE_CREDITS_STARTER` |
| Standard | $19.00 | One time | `NEXT_PUBLIC_STRIPE_CREDITS_STANDARD` |
| Pro | $49.00 | One time | `NEXT_PUBLIC_STRIPE_CREDITS_PRO` |

Copy each **Price ID** (`price_xxx`) into the corresponding env var.

### Register the webhook

Stripe dashboard → **Developers** → **Webhooks** → **Add endpoint**:

- **Endpoint URL:** `https://your-domain.com/api/webhooks/stripe`
- **Events to listen for:**
  - `checkout.session.completed` ← critical for crediting users after purchase
  - `payment_intent.payment_failed`
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
  - `invoice.paid`
  - `customer.deleted`

Copy the **Signing secret** (`whsec_...`) → add as `STRIPE_WEBHOOK_SECRET`.

### Test mode vs live mode

Use `sk_test_` and `pk_test_` keys during development. Switch to `sk_live_` and `pk_live_` only when going to production. Create a separate webhook endpoint for each environment.

---

## 6. Environment Variables Reference

Copy `.env.example` to `.env.local` for local development. Add these to Vercel (or your platform) for production.

### Required — app will not start without these

```env
NEXT_PUBLIC_SITE_URL=https://your-domain.com

NEXT_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

### Required — at least one AI provider

```env
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
OPENROUTER_API_KEY=sk-or-...
```

### Required — Stripe (credit purchases)

```env
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_...

NEXT_PUBLIC_STRIPE_CREDITS_STARTER=price_...
NEXT_PUBLIC_STRIPE_CREDITS_STANDARD=price_...
NEXT_PUBLIC_STRIPE_CREDITS_PRO=price_...

NEXT_PUBLIC_CREDITS_STARTER_AMOUNT=50
NEXT_PUBLIC_CREDITS_STANDARD_AMOUNT=150
NEXT_PUBLIC_CREDITS_PRO_AMOUNT=500
```

### Required — rate limiting

```env
UPSTASH_REDIS_REST_URL=https://your-redis.upstash.io
UPSTASH_REDIS_REST_TOKEN=...
```

### Optional — analytics

```env
NEXT_PUBLIC_POSTHOG_KEY=phc_...
NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com
POSTHOG_PROJECT_API_KEY=phc_...
```

### Local Docker only

```env
USE_LOCAL_REDIS=true
REDIS_URL=redis://localhost:6379
AUTO_PRO_SUBSCRIPTION=true
```

---

## 7. Testing

### Run the test suite

```bash
pnpm test
```

Runs all `*.test.ts` files under `src/` using Node.js's built-in test runner via `tsx`. No Jest or Vitest — no additional setup needed.

### Run type checking

```bash
pnpm typecheck
```

### What is tested

All current tests are **pure unit tests** — no database or network calls. They run instantly.

| File | What it covers |
|---|---|
| `src/lib/stripe/checkout-guard.test.ts` | Idempotency key generation, session metadata matching |
| `src/lib/stripe/subscription-sync.test.ts` | Stripe status → app subscription state mapping |
| `src/utils/actions/stripe/actions.safety.test.ts` | Security: asserts dangerous self-service plan toggle functions do not exist |
| `src/lib/subscription-access.test.ts` | Trial windows, cancellation windows, access expiry logic |
| `src/lib/auth-policy.test.ts` | Auth rules |
| `src/lib/ai/access-control.test.ts` | Model access by user plan |
| `src/lib/ai/usage-ledger.test.ts` | AI usage event recording |
| `src/lib/ai/posthog-telemetry.test.ts` | Analytics event properties |
| `src/lib/ai/task-models.test.ts` | AI model selection |
| `src/lib/analytics/events.test.ts` | Analytics event name constants |

### Writing a new test

Tests use only Node.js built-ins — no imports from external test libraries needed.

```typescript
// src/lib/stripe/credit-bundles.test.ts
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { CREDIT_COSTS } from './credit-bundles'

describe('CREDIT_COSTS', () => {
  it('charges more for a tailored resume than a chat message', () => {
    assert.ok(CREDIT_COSTS.TAILORED_RESUME > CREDIT_COSTS.AI_CHAT_MESSAGE)
  })
})
```

Run a single file:
```bash
node --import tsx/esm --test src/lib/stripe/credit-bundles.test.ts
```

### Testing the credit system

The credit actions (`src/utils/actions/credits/actions.ts`) require a database connection to test fully. For unit testing the logic in isolation, mock the Supabase client:

```typescript
import assert from 'node:assert/strict'
import { describe, it, mock } from 'node:test'

describe('deductCredits', () => {
  it('returns insufficient_credits when balance is too low', async () => {
    // Mock the supabase client to return a known balance
    // then assert deductCredits returns { success: false }
  })
})
```

For integration tests against a real database, use the local Docker stack and a dedicated test user.

### Security tests

Follow the pattern in `actions.safety.test.ts` — read the source file as a string and assert that dangerous patterns do not exist:

```typescript
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { describe, it } from 'node:test'

const source = readFileSync('src/utils/actions/credits/actions.ts', 'utf8')

describe('credit actions safety', () => {
  it('does not allow direct balance override', () => {
    assert.equal(source.includes('setBalance'), false)
    assert.equal(source.includes('amount: userInput'), false)
  })
})
```

### CI (GitHub Actions)

To run tests automatically on every push, create `.github/workflows/test.yml`:

```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 18
          cache: pnpm
      - run: pnpm install
      - run: pnpm test
      - run: pnpm typecheck
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 15 (App Router) |
| Language | TypeScript (strict mode) |
| Database | PostgreSQL via Supabase |
| Auth | Supabase Auth |
| AI | Vercel AI SDK (OpenAI, Anthropic, Google, DeepSeek, Groq) |
| Payments | Stripe (one-time credit purchases) |
| Rate limiting | Upstash Redis |
| PDF generation | React PDF |
| Rich text | TipTap |
| UI | Shadcn UI + Tailwind CSS |
| Analytics | PostHog |

## Project Documentation

Detailed system documentation lives in the `docs/` folder:

| File | Contents |
|---|---|
| `docs/01-monetisation.md` | Credits system design, Stripe integration |
| `docs/02-resume-creation.md` | CV generation flow, data structure |
| `docs/03-profiles.md` | Profile model, onboarding |
| `docs/04-token-usage-monitoring.md` | AI cost tracking |
| `docs/05-ui-redesign.md` | How to rebrand or redesign |
| `docs/06-scalability.md` | Infrastructure limits, scaling checklist |
| `docs/07-product-plan.md` | User stories, feature priorities |

Implementation change logs are in `ai_implementations/`.
