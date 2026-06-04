# Scalability — Numbers & Tracking

## Current Infrastructure

| Layer | Technology | Hosted by |
|---|---|---|
| Frontend + API routes | Next.js 15 | Vercel |
| Database | PostgreSQL | Supabase |
| Authentication | Supabase Auth | Supabase |
| File storage | Supabase Storage | Supabase |
| Rate limiting | Redis | Upstash |
| AI providers | OpenAI / Anthropic / etc. | Third-party APIs |
| Payments | Stripe | Stripe |
| Analytics | PostHog | PostHog |

All layers are managed services — you do not operate servers. Scaling is handled by the platform up to certain limits.

---

## Where the Limits Are

### Vercel (Next.js)

- **Serverless functions**: Scale to thousands of concurrent requests automatically
- **Function timeout**: 10 seconds on Hobby, 60 seconds on Pro, 300 seconds on Enterprise
- **Risk**: AI requests (resume tailoring) can take 15-30 seconds — you need Vercel Pro or use streaming responses to avoid timeouts
- **Bandwidth**: 100 GB/month on Hobby, then pay-per-GB

**Action**: Move to Vercel Pro before launch. Cost: ~$20/month. Timeout limit increase is critical.

### Supabase

Free tier limits:

| Resource | Free limit | Pro limit |
|---|---|---|
| Database size | 500 MB | 8 GB (then $0.125/GB) |
| Bandwidth | 5 GB/month | 250 GB/month |
| API requests | Unlimited | Unlimited |
| Concurrent connections | 60 | 200+ |
| Edge Function invocations | 500K/month | 2M/month |

**Action**: Move to Supabase Pro ($25/month) before launch. The free tier connection limit (60) will become a bottleneck with real traffic.

### Upstash Redis

- Free tier: 10,000 requests/day — fine for rate limiting at small scale
- Pay-per-use above that: ~$0.2 per 100K requests
- No action needed until you have thousands of daily users

### AI API costs

This is your largest variable cost. At scale:

| Users/day | Tailored CVs/day | Estimated AI cost/day |
|---|---|---|
| 100 | 300 | ~$7 |
| 1,000 | 3,000 | ~$70 |
| 10,000 | 30,000 | ~$700 |

These numbers assume ~$0.023 per tailored CV (GPT-4o). Switch to GPT-4o-mini or Claude Haiku for non-critical operations to reduce cost by ~10x.

---

## Key Metrics to Track

### Business metrics (PostHog)

| Metric | How to measure |
|---|---|
| Signups | `SignupCompleted` event |
| Activation rate | Users who fire `ProfileCreated` / total signups |
| First application | Users who tailor their first CV |
| Credit purchase rate | `CheckoutCompleted` / signups |
| Revenue per user | Credits purchased × price per bundle |
| Churn | Users who bought credits but have not returned in 30 days |

**Target activation rate**: >40% of signups should complete their profile. If it is lower, the onboarding is broken.

### Infrastructure metrics

| Metric | Where to see it |
|---|---|
| Database size | Supabase dashboard → Settings → Billing |
| API latency | Vercel dashboard → Analytics |
| Function errors | Vercel dashboard → Logs |
| Redis hit rate | Upstash console |
| AI request duration | `ai_usage_events.duration_ms` (once added) |

### Cost per acquired user

```
CAC = marketing spend / new signups
AI cost per active user = total AI spend / active users (last 30 days)
```

You need AI cost per active user to be well below the revenue per active user. With the credit model:

- Revenue per credit purchase: $9–$49
- AI cost per credit bundle spent: ~$2–$3
- Target gross margin: >70%

---

## Database Performance at Scale

### Indexes already in place

`ai_usage_events` has indexes on `user_id` and `route`. The main tables (`resumes`, `jobs`, `profiles`) use `user_id` as the primary lookup key, which is covered by the RLS policy scan.

### Indexes to add as you grow

```sql
-- Faster credit balance queries
CREATE INDEX credit_ledger_user_id_idx ON public.credit_ledger (user_id);

-- Faster application history queries
CREATE INDEX resumes_user_id_created_at_idx ON public.resumes (user_id, created_at DESC);

-- Faster job lookup
CREATE INDEX jobs_user_id_created_at_idx ON public.jobs (user_id, created_at DESC);
```

Add these when query times on those tables exceed 100ms (visible in Supabase's query performance dashboard).

### Connection pooling

Supabase uses PgBouncer for connection pooling. Ensure your Supabase client uses the **pooled connection string** (port 6543), not the direct connection (port 5432), for all server-side queries. This is the default when using `@supabase/ssr` — no action needed unless you add a direct Postgres client.

---

## Scaling the AI Layer

### Prompt caching

Both Anthropic and OpenAI support **prompt caching** for repeated system prompts. The resume tailoring prompt has a large fixed section (instructions + schema). Caching this reduces cost by ~80% for the cached portion.

In `src/utils/actions/resumes/ai.ts`, use Anthropic's cache control:

```typescript
messages: [
  {
    role: 'user',
    content: [
      {
        type: 'text',
        text: SYSTEM_PROMPT,           // large, repeated
        cache_control: { type: 'ephemeral' }
      },
      {
        type: 'text',
        text: jobDescription + profileData  // dynamic per request
      }
    ]
  }
]
```

### Model routing by action

Not every action needs the most capable model. Use a tiered approach:

| Action | Model | Reason |
|---|---|---|
| Resume tailoring | GPT-4o / Claude Sonnet | Quality matters |
| Cover letter | GPT-4o-mini / Claude Haiku | Good enough, 10x cheaper |
| AI chat | GPT-4o-mini | Speed matters more than quality |
| ATS scoring | GPT-4o-mini | Structured output, cheap |
| Keyword extraction | GPT-4o-mini | Simple task |

This is partially implemented via `src/lib/ai/access-control.ts`. Extend it to route by action type, not just user plan.

---

## Scaling Checklist by Stage

### 0 → 100 users
- [ ] Vercel Hobby plan is fine
- [ ] Supabase free tier is fine
- [ ] No additional infrastructure needed
- [ ] Focus on product, not infrastructure

### 100 → 1,000 users
- [ ] Upgrade to Vercel Pro ($20/month) — timeout limits
- [ ] Upgrade to Supabase Pro ($25/month) — connection limits
- [ ] Add `duration_ms` to `ai_usage_events` — start measuring latency
- [ ] Set up daily cost report (Supabase cron → email)
- [ ] Add database indexes listed above

### 1,000 → 10,000 users
- [ ] Implement prompt caching for resume tailoring
- [ ] Add model routing by action type
- [ ] Set up Helicone or similar for per-prompt cost tracking
- [ ] Add read replicas if dashboard queries slow down (Supabase Pro supports this)
- [ ] Review top 10 most expensive users — consider per-user rate caps

### 10,000+ users
- [ ] Evaluate moving AI calls to a dedicated queue (e.g. Inngest, Trigger.dev) to handle spikes
- [ ] Consider Supabase dedicated compute for database
- [ ] Negotiate API rate limits with OpenAI/Anthropic (Tier 4+ accounts)
- [ ] Add CDN caching for PDF generation if PDFs are re-generated on every view

---

## The Single Most Important Number

**Revenue per active user > AI cost per active user**

Track this weekly. If it inverts — if you are spending more on AI per active user than you earn — you have a pricing or usage problem. The credit system makes this visible and controllable in a way that a flat subscription does not.
