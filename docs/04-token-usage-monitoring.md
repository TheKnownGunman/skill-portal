# Token Usage & Cost Monitoring

## Why This Matters

Every AI call costs money. The two most expensive operations are:

1. **Resume tailoring** — large prompt (full profile + job description + instructions)
2. **AI chat** — per message, potentially many per session

Without monitoring, you cannot know your cost per user, cost per action, or whether a specific model is eating your margin. This doc covers what is already tracked and what gaps remain.

---

## What Is Already Tracked

### `ai_usage_events` table

Every AI request records a row here via `src/lib/ai/usage-ledger.ts`:

```sql
CREATE TABLE public.ai_usage_events (
  id uuid PRIMARY KEY,
  user_id uuid,
  route text,                   -- e.g. '/api/chat', 'tailorResume'
  provider text,                -- 'openai', 'anthropic', 'google', etc.
  model text,                   -- e.g. 'gpt-4o', 'claude-3-5-sonnet'
  is_pro boolean,
  used_server_key boolean,      -- true = your API key, false = user's own key
  status text,                  -- 'started' | 'succeeded' | 'failed' | 'rate_limited'
  input_tokens integer,
  output_tokens integer,
  error_code text,
  created_at timestamptz,
  updated_at timestamptz
);
```

Access is service-role only — users cannot read this table.

### Rate limiting

`src/lib/rateLimiter.ts` uses a leaky bucket algorithm on Upstash Redis:

- Default limit: **80 requests per 5 hours** (applies to both free and pro users)
- Key format: `rate-limit:pro:{userId}`
- Disabled in development

### PostHog telemetry

Every AI request fires PostHog events (`AIRequestStarted`, `AIRequestSucceeded`, `AIRequestFailed`) with provider, model, and user properties. LLM analytics go through OpenTelemetry via `src/instrumentation.node.ts`.

---

## What Is Missing

### 1. Cost calculation

The `ai_usage_events` table records token counts but not **dollar cost**. You need to derive cost from token counts using each provider's pricing.

Add a computed column or a view:

```sql
CREATE VIEW public.ai_usage_costs AS
SELECT
  id,
  user_id,
  provider,
  model,
  input_tokens,
  output_tokens,
  status,
  created_at,
  CASE
    WHEN model = 'gpt-4o' THEN
      (input_tokens * 0.0000025) + (output_tokens * 0.00001)
    WHEN model = 'claude-3-5-sonnet-20241022' THEN
      (input_tokens * 0.000003) + (output_tokens * 0.000015)
    WHEN model = 'gemini-1.5-pro' THEN
      (input_tokens * 0.00000125) + (output_tokens * 0.000005)
    ELSE 0
  END AS estimated_cost_usd
FROM public.ai_usage_events
WHERE status = 'succeeded';
```

Update this view whenever you add new models. Prices change — pin the date when you set them.

### 2. Cost per user

```sql
SELECT
  user_id,
  SUM(estimated_cost_usd) AS total_cost,
  COUNT(*) AS total_requests,
  AVG(estimated_cost_usd) AS avg_cost_per_request
FROM public.ai_usage_costs
WHERE created_at > now() - interval '30 days'
GROUP BY user_id
ORDER BY total_cost DESC;
```

This tells you which users are most expensive to serve. A small number of heavy users often account for most of your AI spend.

### 3. Cost per action type

```sql
SELECT
  route,
  COUNT(*) AS requests,
  SUM(estimated_cost_usd) AS total_cost,
  AVG(input_tokens) AS avg_input_tokens,
  AVG(output_tokens) AS avg_output_tokens
FROM public.ai_usage_costs
GROUP BY route
ORDER BY total_cost DESC;
```

This tells you which features are expensive. Resume tailoring will likely dominate.

### 4. Runtime tracking

Currently there is no request duration recorded. Add `started_at` and `finished_at` timestamps to `ai_usage_events`:

```sql
ALTER TABLE public.ai_usage_events
  ADD COLUMN started_at timestamptz,
  ADD COLUMN finished_at timestamptz,
  ADD COLUMN duration_ms integer GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (finished_at - started_at)) * 1000
  ) STORED;
```

Then in `src/lib/ai/usage-ledger.ts`:

```typescript
// recordAIUsageStarted — set started_at = now()
// recordAIUsageFinished — set finished_at = now()
```

Slow requests (>10s) are a UX problem and often indicate a model or prompt issue.

---

## Connecting Credits to AI Cost

Under the credits system, you want to ensure each credit bundle is **profitable**. The formula is:

```
Profit margin = (credits sold × price per credit) - (AI cost per action × credits used per action)
```

Example with the proposed pricing:
- Tailored CV costs 10 credits
- Standard bundle: 150 credits for $19 → $0.127 per credit
- 10 credits = $1.27 revenue per tailored CV
- Actual AI cost for tailored CV (GPT-4o, ~3000 input + 1500 output tokens) ≈ $0.023
- Margin: ~$1.25 per tailored CV → **~98% gross margin on AI cost**

This margin is healthy. The risk is users finding prompt injection tricks to burn tokens. Rate limiting mitigates this.

---

## Admin Dashboard for Monitoring

The app has an admin section at `src/app/admin/`. Add a cost monitoring panel here that queries the `ai_usage_costs` view and shows:

1. **Daily AI spend** — line chart, last 30 days
2. **Top 10 most expensive users** — table
3. **Cost by route** — bar chart
4. **Average latency by model** — table
5. **Error rate by provider** — table

This does not require a third-party tool — it is a simple Supabase query rendered in the existing admin page.

---

## External Monitoring Options

If you want real-time alerts (e.g. "AI spend exceeded $50 today"), consider:

| Tool | Purpose | Cost |
|---|---|---|
| **PostHog** | Already integrated — add a cost property to AI events | Free tier |
| **Supabase Edge Functions** | Scheduled job to aggregate daily costs and send email | Free |
| **Datadog / Grafana** | Full observability, overkill at early stage | $$ |
| **Helicone** | Purpose-built LLM cost tracker, wraps your API calls | Free tier |

For early stage, PostHog + a daily Supabase cron query is sufficient. Add Helicone when AI spend exceeds $200/month and you need per-prompt breakdowns.

---

## Rate Limiting Strategy

The current rate limit (80 requests / 5 hours) protects against abuse but is not tied to credit balance. Under the credits system:

- **Remove the time-based rate limit** for credit-paying users — they are paying per action
- **Keep a hard cap** of e.g. 200 requests per day as an abuse safeguard regardless of credits
- **Deduct credits atomically** before the AI call — if the AI call fails, refund the credits

```typescript
// Pseudocode for atomic credit deduction + refund
const deduction = await deductCredits(userId, 10, 'tailored_resume');
if (!deduction.success) throw new InsufficientCreditsError();

try {
  const result = await runAITailoring(...);
  return result;
} catch (err) {
  // Refund on failure
  await addCredits(userId, 10, 'refund', deduction.ledgerEntryId);
  throw err;
}
```
